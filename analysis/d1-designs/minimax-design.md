# System Design: Web Application Platform

## State Inventory
| State | Owner | Storage | Staleness OK? | Regional? |
|-------|-------|---------|---------------|-----------|
| User Sessions | Session Service | Redis (per-region) | No - must be fresh | Yes - regional |
| User Credentials | Auth Service | PostgreSQL (regional) | No - authoritative | Yes - regional |
| Session Metadata | Session Service | PostgreSQL (regional) | Yes - for analytics | Yes - regional |
| Rate Limit Counters | Rate Limiter | Redis (per-region) | No - must be accurate | Yes - regional |
| Audit Logs | Audit Service | PostgreSQL (regional) | Yes - append-only | Yes - regional |
| Recent Activity Cache | Frontend Service | Redis (per-region, 5-min TTL) | Yes - for UI display | Yes - regional |
| API Keys | API Gateway | PostgreSQL (global, replicated) | No - authoritative | No - global |
| User-Region Mapping | User Service | PostgreSQL (global) | No - lookup table | No - global |
| Pending Cross-Region Ops | Sync Service | Redis (global) | Yes - queue | No - global |
| Webhook Subscriptions | Webhook Service | PostgreSQL (regional) | No - authoritative | Yes - regional |
| Webhook Deliveries | Webhook Service | PostgreSQL (webhook_deliveries table) | Yes - history | Yes - regional |
| Webhook Retry Queue | Webhook Service | Redis (per-region) | Yes - pending deliveries | Yes - regional |
| Dead Letter Webhooks | Webhook Service | PostgreSQL (regional) | Yes - failed after retries | Yes - regional |
| Customer Public Keys | Webhook Service | PostgreSQL (webhook_public_keys table) | No - sensitive | Yes - regional |
| Webhook Debug Logs | Webhook Service | PostgreSQL (webhook_debug_logs, opt-in) | Yes - 7-day TTL | Yes - regional |

## Components
1. **Auth Service** - Handles login, logout, credential validation (regional)
2. **Session Service** - Manages session creation, validation, expiration (regional)
3. **Rate Limiter** - Enforces per-user/request limits with multiple identifiers (regional)
4. **API Gateway** - Handles API key authentication and rate limiting (regional)
5. **Audit Service** - Records all authenticated actions (regional)
6. **Frontend Service** - Serves dashboard UI with recent activity (regional)
7. **Webhook Service** - Manages webhook subscriptions, encryption, and deliveries (regional)
8. **Sync Service** - Handles cross-region user data synchronization
9. **User Service** - Manages user creation and region assignment (global coordinator)
10. **Redis Clusters** - One per region (US, EU) for sessions, rate limits, cache, webhook queue
11. **PostgreSQL Clusters** - One per region for users, credentials, session metadata, audit logs, API keys, webhooks

## Hot Paths
1. **Rate Limit Check** - Checked BEFORE processing any request (highest priority)
2. **Session Validation** - Every authenticated request checks session validity in regional Redis
3. **Login Flow** - Verify credentials, create session in regional store
4. **Audit Log Write** - Asynchronous write to regional PostgreSQL
5. **Webhook Trigger** - Synchronous check if webhook should fire, async delivery with encryption

## Failure Modes
| Component | Failure Mode | Strategy (Open/Closed) |
|-----------|--------------|------------------------|
| Regional Redis | Region down | Closed - users can't authenticate in that region |
| Regional PostgreSQL | Region down | Closed - reads fail, writes queue for sync |
| Global Services | Unavailable | Open - regional operations continue; new signups blocked |
| Cross-Region Sync | Lag/delays | Open - eventual consistency for user moves |
| Rate Limiter | Unavailable | Closed - reject requests (fail secure) |
| Audit Database | Unavailable | Closed - queue writes, retry asynchronously |
| Activity Cache | Unavailable | Open - show empty recent activity, fallback to DB |
| API Key DB | Unavailable | Closed - reject API requests |
| Webhook Target | Slow (5+ sec) | Open - timeout after 10s, retry later |
| Webhook Target | Down | Closed - retry with exponential backoff, then dead letter |
| Webhook Encryption | Key unavailable | Closed - fail delivery, alert ops |

## Design Decisions Log

### Turn 1: User Sessions (2026-01-14)
**Decision**: Use Redis for active session storage
**Reasoning**: 
- 10,000 concurrent users requires sub-millisecond session lookups
- Redis provides O(1) lookups with expiration support
- In-memory storage matches the "staleness not OK" requirement
- Trade-off: Redis is volatile, but sessions can be re-created via re-login

**Session Format**:
- Key: `session:{session_id}`
- Value: JSON with `{user_id, created_at, last_accessed, ip, user_agent}`
- TTL: 24 hours from last activity (sliding expiration)

**Architecture Decision**:
- Stateless application servers
- Centralized session store in Redis
- Session ID passed via secure HTTP-only cookie

### Turn 2: Rate Limiting (2026-01-14)
**Decision**: Sliding window counter algorithm using Redis
**Reasoning**:
- Sliding window provides smoother rate limiting than fixed windows
- Prevents burst attacks more effectively than token bucket
- Redis INCR + EXPIRE is atomic and fast

**Rate Limiting Strategy**:
- Limit: 100 requests per minute per user
- Key: `ratelimit:{user_id}:{minute_bucket}`
- Algorithm: Sliding window log with 1-minute granularity
- Storage: Redis sorted sets (timestamp as score, count as members)

**Integration with Session System**:
- Rate limiter runs BEFORE session validation in request pipeline
- If rate limited: return 429 immediately, no session check needed
- Unauthenticated requests: rate limit by IP (fallback to prevent bot abuse)
- Authenticated requests: rate limit by user_id from session

**Trade-offs**:
- Pro: Works seamlessly with existing session infrastructure
- Pro: Redis handles both use cases efficiently
- Con: Slight overhead of additional Redis calls per request

### Turn 3: Audit Logging (2026-01-14)
**Decision**: Asynchronous audit logging via message queue
**Reasoning**:
- Audit logs are append-only and don't affect response time
- Queuing ensures logs are preserved even under load
- Decouples audit from request processing for performance

**Audit Log Schema**:
```sql
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(50),
    resource_id UUID,
    outcome VARCHAR(20) NOT NULL, -- SUCCESS, FAILURE
    ip_address INET,
    user_agent TEXT,
    request_id UUID,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audit_user_time ON audit_logs(user_id, created_at DESC);
```

**Audit Event Payload**:
```json
{
  "user_id": "uuid",
  "action": "user.login",
  "resource_type": "session",
  "resource_id": "uuid",
  "outcome": "SUCCESS",
  "ip_address": "192.168.1.1",
  "user_agent": "Mozilla/5.0...",
  "request_id": "uuid",
  "metadata": {"reason": "invalid_credentials"}
}
```

**Data Flow**:
1. Request completes successfully
2. Middleware emits audit event to internal message queue
3. Audit Service consumes queue and writes to PostgreSQL
4. Queue provides durability guarantee (at-least-once delivery)

**State Ownership**:
- Audit Service OWNS the audit_logs table
- Session Service provides user_id via session lookup
- No component reads audit_logs during normal request processing
- Only for reporting/dashboard queries

**Trade-offs**:
- Pro: Minimal impact on request latency (async)
- Pro: Durable storage in PostgreSQL
- Pro: Indexed for efficient user+time queries
- Con: Small delay between action and log availability (acceptable for audit)

### Turn 4: Performance Issues - Diagnosis (2026-01-14)
**Problem Identified**:
- Average response time: 850ms (target: 200ms)
- Database CPU: 92%
- p99 latency: 4.2 seconds
- Root cause: `SELECT * FROM audit_logs WHERE user_id = ?` on EVERY request

**Diagnosis**:
- Frontend Service making audit DB query on each dashboard load
- No caching layer for recent activity
- Index scan vs covering index
- Table too large for efficient queries without partitioning

**Solution**: Cache recent activity in Redis with 5-minute TTL
**Reasoning**:
- Dashboard activity doesn't need real-time accuracy (staleness OK for UI)
- 5-second staleness vs 850ms latency improvement = good tradeoff
- Reduces DB load significantly

**Implementation**:
```python
def get_recent_activity(user_id):
    # Try cache first
    cached = redis.get(f"activity:{user_id}")
    if cached:
        return json.loads(cached)
    
    # Fallback to DB with LIMIT
    results = db.query("""
        SELECT action, resource_type, outcome, created_at 
        FROM audit_logs 
        WHERE user_id = ? 
        ORDER BY created_at DESC 
        LIMIT 10
    """, user_id)
    
    # Cache for 5 minutes
    redis.setex(f"activity:{user_id}", 300, json.dumps(results))
    return results
```

**Additional Fix**: Covering index for the query
```sql
CREATE INDEX idx_audit_user_time_covering 
ON audit_logs(user_id, created_at DESC) 
INCLUDE (action, resource_type, resource_id, outcome);
```

**Metrics After Fix**:
- Expected response time: <100ms (dashboard endpoint)
- DB CPU reduction: ~40% (cache hit rate estimate)
- p99 improvement: 4.2s → ~300ms

### Turn 5: Rate Limiter Bug - Multi-Agent API Keys (2026-01-14)
**Problem Identified**:
- Customer complaint: 50 build agents using same API key collectively hit 100 req/min limit
- Root cause: Rate limiter keyed by user_id, not by API key or client identifier
- Design assumption: 1 user = 1 client was wrong

**Solution**: Tiered Rate Limiting with configurable limits
**Reasoning**:
- API keys need different limits than user sessions
- Multiple identities per request (API key, user, IP) for defense in depth
- Customer-configurable limits for high-volume use cases

**New Rate Limiting Strategy**:
```python
class TieredRateLimiter:
    def check_limit(self, request):
        # Priority: API Key > User Session > IP Address
        limits = []
        
        if api_key := request.headers.get('X-API-Key'):
            limits.append(self.get_limit_for_api_key(api_key))
            identity = f"apikey:{api_key}"
        elif user_id := request.session.get('user_id'):
            limits.append(self.get_limit_for_user(user_id))
            identity = f"user:{user_id}"
        else:
            limits.append(self.get_limit_for_ip(request.ip))
            identity = f"ip:{request.ip}"
        
        return self.apply_sliding_window(identity, limits[0])
```

**API Key Rate Limit Configuration**:
```sql
CREATE TABLE api_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key_hash VARCHAR(64) NOT NULL UNIQUE,
    customer_id UUID NOT NULL,
    name VARCHAR(100),
    rate_limit INTEGER DEFAULT 1000, -- requests per minute
    rate_limit_window INTEGER DEFAULT 60, -- seconds
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_used_at TIMESTAMPTZ
);

CREATE INDEX idx_api_keys_key_hash ON api_keys(key_hash);
```

**Limit Selection Logic**:
1. If API key present → use API key's configured limit
2. Else if authenticated user → use user limit (100/min)
3. Else → use IP limit (20/min for bot protection)

**Trade-offs**:
- Pro: Supports CI/CD pipelines with shared API keys
- Pro: Customers can configure appropriate limits
- Pro: Maintains bot protection for unauthenticated requests
- Con: More complex rate limit key management
- Con: Need to track API key metadata (DB dependency)
- Trade-off: Default API key limit (1000/min) is 10x user limit, acknowledging automated traffic patterns

### Turn 6: Multi-Region Deployment - GDPR Compliance (2026-01-14)
**Problem**: GDPR requires EU user data stay in EU; need US and EU regions

**Solution**: Regional data storage with global user registry
**Reasoning**:
- GDPR mandates data residency for EU users
- Users may travel between regions
- Need to maintain session continuity while respecting residency

**Data Classification**:
- **Regional (must stay in region)**: 
  - User profiles, credentials, sessions, audit logs
  - Any PII or activity data tied to a specific user
- **Global (replicated)**:
  - API keys (stateless, used for auth only)
  - User-region mapping (lookup index)
  - Product catalog, feature flags

**User Region Assignment**:
```sql
-- Global user registry (single source of truth for region assignment)
CREATE TABLE users (
    id UUID PRIMARY KEY,
    region VARCHAR(10) NOT NULL, -- 'US' or 'EU'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    -- Other region-agnostic fields
    email VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE
) PARTITION BY HASH(id); -- Could partition by region in future

-- Regional user profiles (PostgreSQL in each region)
CREATE TABLE user_profiles (
    user_id UUID PRIMARY KEY,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(20),
    address JSONB,
    preferences JSONB,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Session Handling by Region**:
```
US User traveling to EU:
1. User logs in in US → session created in US Redis
2. User travels to EU, continues using session
3. EU load balancer sees session cookie
4. EU validates session via cross-region Redis replication
5. If session invalid in EU: force re-login (creates EU session)

EU User staying in EU:
1. All sessions created/validated in EU Redis
2. Data never leaves EU region
```

**Cross-Region Session Validation**:
```python
def validate_session(session_id, region):
    # Try local Redis first
    session = redis_local.get(f"session:{session_id}")
    if session:
        return session
    
    # Try cross-region read (EU → US or US → EU)
    if other_region := get_other_region(region):
        session = redis_remote(other_region).get(f"session:{session_id}")
        if session:
            # Copy to local Redis for future requests
            redis_local.setex(f"session:{session_id}", 
                            session['ttl'], 
                            json.dumps(session))
            return session
    
    return None  # Session not found
```

**User Creation Flow**:
```
1. User signs up (detected via GeoIP or explicit selection)
2. User Service (global) creates entry in global users table with region
3. User profile created in regional PostgreSQL
4. Session, rate limit infra initialized in that region only
```

**Trade-offs**:
- Pro: GDPR compliant - EU data never leaves EU
- Pro: Sessions work across regions with cross-region validation
- Pro: Regional failures don't cascade globally
- Con: Cross-region session validation adds latency (~50ms)
- Con: User must re-login if traveling and session not cached locally
- Con: Complexity in tracking which region owns which user
- Mitigation: Global user registry provides single lookup

### Turn 7: Webhooks (2026-01-14)
**Requirement**: Customers want webhooks for key events (user created, subscription changed, etc.)

**Solution**: Async webhook delivery with exponential backoff retry
**Reasoning**:
- Webhook delivery should not block main request processing
- Customer endpoints may be slow or temporarily unavailable
- Need retry strategy for reliability
- Must handle GDPR (EU customer webhooks from EU region)

**Webhook Schema**:
```sql
CREATE TABLE webhook_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    event_type VARCHAR(100) NOT NULL, -- 'user.created', 'subscription.changed', etc.
    url VARCHAR(2048) NOT NULL,
    secret VARCHAR(256), -- For HMAC signature verification
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT unique_customer_event UNIQUE (customer_id, event_type, url)
);

CREATE TABLE webhook_deliveries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id UUID NOT NULL REFERENCES webhook_subscriptions(id),
    event_id UUID NOT NULL, -- Original event that triggered webhook
    event_type VARCHAR(100) NOT NULL,
    payload JSONB NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending, delivering, success, failed
    attempt_count INTEGER DEFAULT 0,
    last_attempt_at TIMESTAMPTZ,
    next_retry_at TIMESTAMPTZ,
    response_status INTEGER,
    response_body TEXT,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_webhook_deliveries_status_next_retry 
ON webhook_deliveries(status, next_retry_at);
```

**Webhook Event Types**:
- `user.created`
- `user.updated`
- `user.deleted`
- `session.created`
- `session.expired`
- `subscription.created`
- `subscription.updated`
- `subscription.cancelled`
- `api_key.created`
- `api_key.revoked`

**Webhook Payload Structure**:
```json
{
  "id": "evt_123456",
  "type": "user.created",
  "created_at": "2026-01-14T21:00:00Z",
  "data": {
    "user_id": "usr_abc123",
    "email": "user@example.com",
    "region": "US"
  }
}
```

**Retry Strategy**:
```
Schedule:
- Attempt 1: Immediately
- Attempt 2: 1 minute after failure
- Attempt 3: 5 minutes after failure
- Attempt 4: 30 minutes after failure
- Attempt 5: 2 hours after failure
- Attempt 6: 6 hours after failure
- Then: Dead letter (manual intervention required)

Total retry window: ~9 hours
Max attempts: 6
```

**Timeout Configuration**:
- Connection timeout: 5 seconds
- Read timeout: 10 seconds
- Total request timeout: 15 seconds

**Delivery Worker**:
```python
class WebhookDeliveryWorker:
    def __init__(self, redis, http_client):
        self.redis = redis
        self.http = http_client
        self.max_attempts = 6
        self.backoff_schedule = [0, 60, 300, 1800, 7200, 21600]  # seconds
    
    async def process_deliveries(self):
        while True:
            # Get next delivery ready for retry
            delivery = await self.get_next_delivery()
            if not delivery:
                await asyncio.sleep(1)
                continue
            
            await self.deliver_webhook(delivery)
    
    async def deliver_webhook(self, delivery):
        subscription = await get_subscription(delivery.subscription_id)
        
        # Sign payload
        signature = hmac_sha256(subscription.secret, delivery.payload)
        
        headers = {
            'Content-Type': 'application/json',
            'X-Webhook-ID': delivery.id,
            'X-Webhook-Signature': f'sha256={signature}',
            'X-Webhook-Timestamp': delivery.created_at.isoformat(),
        }
        
        try:
            response = await self.http.post(
                subscription.url,
                json=delivery.payload,
                headers=headers,
                timeout=15  # 5s connect + 10s read
            )
            
            if 200 <= response.status < 300:
                await self.mark_success(delivery)
            else:
                await self.mark_retry(delivery, f"HTTP {response.status}")
                
        except asyncio.TimeoutError:
            await self.mark_retry(delivery, "timeout")
        except Exception as e:
            await self.mark_retry(delivery, str(e))
```

**Slow Endpoint Handling**:
- Connection timeout (5s) prevents waiting for slow connections
- Read timeout (10s) prevents waiting for slow responses
- Non-2xx responses trigger retry
- 2xx responses are considered success

**Down Endpoint Handling**:
- Exponential backoff spreads retry load
- Prevents thundering herd on recovering endpoints
- Dead letter after 6 attempts for manual investigation

**Security**:
- HMAC-SHA256 signature on all payloads
- Customer-provided secret for verification
- HTTPS required for all webhook URLs
- Idempotency via event_id (deduplication)

**GDPR Consideration**:
- EU customers' webhooks delivered from EU region
- No PII in webhook payload without customer consent
- Webhook payload filtering configurable per subscription

**Trade-offs**:
- Pro: Async delivery doesn't slow down main requests
- Pro: Retry logic handles temporary failures
- Pro: Dead letter queue prevents infinite retry loops
- Con: Webhook delivery can be delayed (up to 9 hours)
- Con: Customer must handle duplicate events (event_id provided)
- Con: Complexity in managing regional webhook delivery

### Turn 8: Conflicting Requirements - Encryption vs Debuggability (2026-01-14)
**Conflict**:
- Security Team: "All webhook payloads must be encrypted with customer-provided public keys"
- Product Team: "Webhooks need to be debuggable - customers should see recent payloads in dashboard"

**Analysis**:
- Encryption prevents dashboard debuggability
- Plaintext enables debugging but violates security requirement
- Both teams have valid concerns

**Resolution**: Dual-Mode Webhooks with Customer-Selectable Security
**Reasoning**:
- Security is non-negotiable for sensitive data
- Debugging is critical for customer onboarding and support
- Let customers choose their security posture
- Provide clear UX about what each mode means

**Solution Design**:

**Option 1: Encrypted Mode (Default Recommended)**
- Payload encrypted with customer's RSA public key
- Only customer can decrypt (we cannot see payload)
- No dashboard debug view available
- Use when handling sensitive/PII data

**Option 2: Signed Mode (Debuggable)**
- Payload sent in cleartext
- HMAC signature for integrity verification
- Dashboard shows recent payloads for debugging
- Use for non-sensitive events, development

**Webhook Subscription Schema**:
```sql
CREATE TABLE webhook_public_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    public_key_pem TEXT NOT NULL, -- PEM format
    algorithm VARCHAR(20) NOT NULL DEFAULT 'RSA-OAEP-256',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    rotated_at TIMESTAMPTZ,
    
    CONSTRAINT one_active_key_per_customer UNIQUE (customer_id, is_active)
    WHERE is_active = TRUE
);

ALTER TABLE webhook_subscriptions ADD COLUMN delivery_mode VARCHAR(20) 
DEFAULT 'encrypted' CHECK (delivery_mode IN ('encrypted', 'signed'));
```

**Encrypted Payload Structure**:
```json
{
  "id": "evt_123456",
  "type": "user.created",
  "created_at": "2026-01-14T21:00:00Z",
  "encrypted_data": "base64-encoded-encrypted-payload",
  "key_id": "key_uuid_abc123",
  "algorithm": "RSA-OAEP-256+AES-256-GCM"
}
```

**Customer Decryption Flow**:
1. Receive webhook with `encrypted_data` and `key_id`
2. Use their corresponding private key to decrypt
3. Standard format: RSA-OAEP encrypted AES key, then AES-GCM encrypted payload

**Signed Payload Structure** (for debuggable mode):
```json
{
  "id": "evt_123456",
  "type": "user.created",
  "created_at": "2026-01-14T21:00:00Z",
  "data": {
    "user_id": "usr_abc123",
    "email": "user@example.com"
  },
  "signature": "sha256=abc123..."
}
```

**Dashboard Debug View** (signed mode only):
```sql
CREATE TABLE webhook_debug_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    delivery_id UUID NOT NULL REFERENCES webhook_deliveries(id),
    payload_preview JSONB, -- Only stored for signed mode
    viewed_by UUID REFERENCES users(id),
    viewed_at TIMESTAMPTZ DEFAULT NOW()
);
```

**UI Presentation**:
```
Webhook Settings:
┌─────────────────────────────────────────────────────────────┐
│  Event: user.created                          [Edit] [Delete]│
│  URL: https://api.customer.com/webhooks                ⚠️    │
│                                                             │
│  Security Mode:                                             │
│  ○ Encrypted (Recommended for sensitive data)              │
│    - Payload encrypted with your public key                │
│    - We cannot see webhook contents                       │
│    - Dashboard debug view: Not available                   │
│                                                             │
│  ○ Signed (Debuggable)                                     │
│    - Payload visible in cleartext                         │
│    - HMAC signature for integrity                         │
│    - Dashboard debug view: Available                      │
│                                                             │
│  Public Key: key_abc123... [Rotate] [Remove]               │
│                                                             │
│  [Save Settings]                                            │
└─────────────────────────────────────────────────────────────┘
```

**Default Recommendation Logic**:
```python
def suggest_delivery_mode(event_type, customer_tier):
    # Sensitive events default to encrypted
    sensitive_events = ['user.created', 'user.updated', 'subscription.paid']
    if event_type in sensitive_events:
        return 'encrypted'
    
    # Enterprise customers default to encrypted
    if customer_tier == 'enterprise':
        return 'encrypted'
    
    # Others default to signed for better DX
    return 'signed'
```

**Migration Path**:
1. Existing subscriptions migrate to 'signed' mode (backward compatible)
2. New subscriptions default based on event type
3. Customers can opt-in to encryption at any time
4. Provide key upload UI and key rotation support

**Security Considerations**:
- RSA keys must be 2048-bit minimum (recommend 4096-bit)
- AES-256-GCM for symmetric encryption within encrypted envelope
- Keys stored encrypted at rest in database
- Key rotation without service interruption (dual-key strategy)
- Audit log of key uploads/rotations

**Trade-offs**:
- Pro: Satisfies both security and product requirements
- Pro: Customers control their security posture
- Pro: Clear UX about what each mode provides
- Con: Complexity in supporting two delivery modes
- Con: Encrypted mode prevents some support scenarios
- Con: Key management burden on customers
- Mitigated by: Good onboarding UX, default recommendations, key rotation support

## Current Architecture
```
                              ┌─────────────────┐
                              │   Global DNS    │
                              │  (GeoDNS)       │
                              └────────┬────────┘
                                       │
                    ┌──────────────────┴──────────────────┐
                    │                                      │
                    ▼                                      ▼
          ┌─────────────────┐                   ┌─────────────────┐
          │   US Region     │◄─────────────────►│   EU Region     │
          │  (us-east-1)    │   Cross-Region   │  (eu-west-1)    │
          └────────┬────────┘   Replication    └────────┬────────┘
                   │                                     │
          ┌────────┴────────┐                ┌─────────┴─────────┐
          │                 │                │                   │
          ▼                 ▼                ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│   US Redis      │ │  US PostgreSQL  │ │   EU Redis      │ │  EU PostgreSQL  │
│ - Sessions      │ │ - US Users      │ │ - Sessions      │ │ - EU Users      │
│ - Rate Limits   │ │ - US Credentials│ │ - Rate Limits   │ │ - EU Credentials│
│ - Activity Cache│ │ - US Audit Logs │ │ - Activity Cache│ │ - EU Audit Logs │
│ - Webhook Queue │ │ - US Webhooks   │ │ - Webhook Queue │ │ - EU Webhooks   │
│                 │ │ - Public Keys   │ │                 │ │ - Public Keys   │
└─────────────────┘ └─────────────────┘ └─────────────────┘ └─────────────────┘

Webhook Delivery Flow:
┌─────────────────────────────────────────────────────────────────────────────┐
│  Event Occurs → Webhook Service                                              │
│       │                                                                      │
│       │     ┌─────────────────────────────────────────────────────────┐     │
│       │     │  Check Subscription Mode:                               │     │
│       │     │  - 'encrypted': Encrypt with customer's public key     │     │
│       │     │  - 'signed': Sign with HMAC, send cleartext            │     │
│       │     └─────────────────────┬───────────────────────────────────┘     │
│       │                           │                                         │
│       │          ┌────────────────┴────────────────┐                        │
│       │          ▼                                 ▼                        │
│       │   ┌─────────────┐                   ┌─────────────┐                 │
│       │   │ Encrypt     │                   │ Sign        │                 │
│       │   │ RSA-OAEP    │                   │ HMAC-SHA256 │                 │
│       │   │ AES-256-GCM │                   │             │                 │
│       │   └──────┬──────┘                   └──────┬──────┘                 │
│       │          │                                 │                        │
│       │          └──────────────┬──────────────────┘                        │
│       │                         │                                           │
│       │                         ▼                                           │
│       │                 ┌──────────────┐                                    │
│       │                 │  Queue       │                                    │
│       │                 │  (async)     │                                    │
│       │                 └──────┬───────┘                                    │
│       │                        │                                            │
│       │             ┌──────────┼──────────┐                                 │
│       │             ▼          ▼          ▼                                 │
│       │     ┌─────────────┐┌─────────────┐┌─────────────┐                   │
│       │     │ Worker US-1 │ │Worker US-2  │ │Worker EU-1  │                   │
│       │     └──────┬──────┘└──────┬──────┘└──────┬──────┘                   │
│       │            │              │              │                           │
│       │            └──────────────┼──────────────┘                           │
│       │                           │                                          │
│       │                           ▼                                          │
│       │                   ┌─────────────────┐                                │
│       │                   │  Customer       │                                │
│       │                   │  Webhook URL    │                                │
│       │                   │  (HTTPS)        │                                │
│       │                   └─────────────────┘                                │
│       │                                                                      │
│       ▼                                                                      ▼
┌───────────────────────────────────────────────┐         ┌────────────────────┐
│  Dashboard Debug View                          │         │  Customer Decrypts │
│  (Signed mode only)                            │         │  - Uses private key│
│  - Shows recent payloads                       │         │  - Verifies RSA-OAEP│
│  - Click to view full payload                 │         │  - Decrypts AES-GCM│
│  - "This is encrypted" for encrypted mode     │         └────────────────────┘
└───────────────────────────────────────────────┘
```
