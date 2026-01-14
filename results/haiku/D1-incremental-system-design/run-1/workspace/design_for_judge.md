# System Design: Web Application Platform

## State Inventory
| State | Owner | Storage | Staleness OK? |
|-------|-------|---------|---------------|
| Session tokens | Auth Service | Redis (distributed cache) | 1-hour TTL acceptable |
| User identity | Auth Service | PostgreSQL | No |
| Rate limit counters | Rate Limiter | Redis (fast, atomic increments) | No (strict) |
| Audit logs | Audit Service | PostgreSQL (durable) | No (immutable) |
| Webhook event queue | Webhook Service | Message Queue (RabbitMQ) | No (must deliver) |
| Webhook payloads (encrypted) | Webhook Service | PostgreSQL | No |
| Customer public keys | Config Service | PostgreSQL with Redis cache | Acceptable (5min TTL) |
| Regional routing | Router | In-memory config | Acceptable (dynamic reload) |

## Components
1. **API Gateway** - Routes requests, validates tokens
2. **Auth Service** - Session management, token issuance
3. **Rate Limiter** - Token bucket algorithm with distributed state
4. **Audit Service** - Logs authenticated actions
5. **Webhook Service** - Enqueues and delivers webhooks
6. **Event Bus** - Message queue for async operations
7. **Regional Router** - Routes requests to correct region based on user/request origin
8. **Database Tier** - PostgreSQL (US primary, EU replica with read-only)

## Hot Paths
1. **Login/Session Validation** - Every request hits this
2. **Rate Limit Check** - Every request (after auth)
3. **Webhook Delivery** - Critical for customers, async but must not lose events
4. **Audit Log Query** - Deferred from hot path

## Failure Modes
| Component | Failure Mode | Strategy |
|-----------|--------------|----------|
| Redis (session cache) | Cache miss | Open - fall back to DB with re-auth |
| Redis (rate limiter) | Inconsistency | Closed - serve cached state until recovered |
| Rate Limiter | Distributed clock skew | Closed - use server time, accept slight over-limiting |
| Audit Log DB | Slow queries | Closed - async batch processing, cache recent |
| Webhook endpoint down | Connection failure | Open - retry with exponential backoff, eventual delivery |
| Regional data flow | Cross-border transfer | Closed - enforce data residency |

## Design Decisions Log

### Turn 1: User Sessions
- **Decision**: Use Redis for session storage with 1-hour TTL
- **Reasoning**: Sub-10K concurrent users, need fast lookups, TTL avoids stale sessions
- **Alternative rejected**: Database-only would be too slow for every request
- **Impact**: Requires cache invalidation on logout

### Turn 2: Rate Limiting
- **Decision**: Implement token bucket algorithm in Redis, 100 reqs/min per user
- **Reasoning**: Atomic operations, distributed state, fair for per-user limiting
- **Interaction with sessions**: Rate limit applies to authenticated user ID
- **Storage**: Redis hash per user: {user_id -> {tokens, last_refill_time}}
- **Interaction note**: Can't use session token ID alone if user has multiple sessions

### Turn 3: Audit Logging
- **Decision**: Write-ahead logging with PostgreSQL as primary store
- **Reasoning**: Enterprise requirement, immutable, queryable, durable
- **Owner**: Dedicated Audit Service (separate from API logic)
- **Log format**: {user_id, action, resource_type, resource_id, outcome, timestamp, ip_address}
- **Storage**: PostgreSQL table with indexes on user_id and timestamp
- **Performance note**: This will be queried frequently - needs careful indexing

### Turn 4: Performance Issues - Diagnosis & Fix
- **Problem identified**: Audit log query on every request (SELECT * FROM audit_logs WHERE user_id = ?)
- **Root cause**: 850ms response time, 92% DB CPU, p99 = 4.2s indicates sequential scan or lock contention
- **Fixes applied**:
  1. Remove audit log query from hot path - move to async "recent activity" dashboard
  2. Create composite index: (user_id, timestamp DESC) for dashboard queries
  3. Implement audit log cache: LRU with 5-min TTL for recent activity endpoint
  4. Archive old logs to separate table (>30 days)
  5. Add database read replica for audit queries (read scaling)
- **New decision**: Audit logging is fire-and-forget async (message queue) to keep hot path clear

### Turn 5: Rate Limiter Bug - CI/CD Pipeline Overload
- **Problem**: 50 build agents with same API key hit 100 req/min limit collectively
- **Root cause**: Rate limiter is per-user/API-key, not per-source
- **Fix options**:
  1. Increase limit for CI/CD keys (too loose)
  2. Rate limit per IP + per key (too restrictive for distributed builds)
  3. **Chosen**: Implement "burst allowance" with separate per-minute and per-second buckets
  4. Add tiered rate limits: Basic 100/min, Enterprise 500/min, CI/CD unlimited (whitelisted)
- **Tradeoff**: Loses simplicity, adds configuration complexity
- **New decision**: Rate limit tiers managed in config, CI/CD keys have bypass or higher limits

### Turn 6: Multi-Region Expansion (GDPR)
- **Requirement**: EU data stays in EU, US data stays in US
- **Architecture decision**:
  - **Global state**: Customer configs, public keys (with GDPR exceptions)
  - **Regional state**: User sessions, audit logs, user data
  - **Router decision point**: Determine user region on login, store in session
  - **Cross-region travel**: US user traveling to EU gets re-routed, may need re-auth
- **Failure mode**: Webhook delivery to customers might span regions → need careful routing
- **New components**: Regional databases, regional caches, geo-aware router
- **Data residency**: Audit logs stay in user's home region

### Turn 7: Webhooks
- **Decision**: Async webhook delivery via message queue
- **Architecture**:
  - Event occurs → enqueued to RabbitMQ
  - Webhook Service consumes from queue
  - Retries with exponential backoff (1s, 2s, 4s, 8s, 16s, then dead letter queue)
  - Max 5 retries, then log failure and alert
- **Failure handling**: 
  - If endpoint is slow: respects HTTP timeouts (30s), doesn't block queue
  - If endpoint is down: queued indefinitely with retries
  - If queue fails: message durability via RabbitMQ persistence
- **Payload**: JSON with event metadata, timestamp, signature for verification
- **Potential issue**: Customer debugging difficult if payloads only exist in queue

### Turn 8: Conflicting Requirements - Encryption vs. Debuggability
- **Conflict**: Encrypt payloads for security vs. allow dashboard view for debugging
- **Chosen resolution**: 
  1. **Primary**: Store encrypted payloads in database (resolved with security team)
  2. **Secondary**: Store decryption keys in secure vault, access via dashboard requires audit log entry
  3. **Compromise**: Show payload metadata unencrypted (event type, timestamp, status), require explicit decrypt action with audit trail
  4. **Ops access**: On-call engineers can decrypt via separate secure channel (documented in runbook)
- **Tradeoff**: Slightly more complex UX, maintains security + debuggability

### Turn 9: 10x Scale Pressure (2-week deadline)
- **Current assumptions failing at 10x**:
  1. Redis session cache size (100K concurrent sessions) - partition/shard
  2. Rate limiter contention on single Redis - already distributed, but watch latency
  3. Audit log writes (will become bottleneck) - batch writes, async queueing
  4. Webhook delivery throughput - current queue can handle if consumers scale
  5. Regional routing (if centralizing) - move routing logic to edge (CDN/LB level)
  
- **Immediate actions for 2-week deadline**:
  1. **Horizontal scaling**: Add 3 instances of Rate Limiter and Webhook Service
  2. **Database**: Upgrade to larger instance, enable auto-scaling storage
  3. **Audit logging**: Move to async-only (no confirmation on hot path), use batch writes
  4. **Webhook concurrency**: Increase consumer pool size
  5. **Caching**: Implement Redis cluster for session storage
  6. **Monitoring**: Add capacity planning dashboards
  
- **Not time for 2 weeks**: Database sharding, full multi-region setup, webhook acceleration

## Current Architecture

```
┌─────────────┐
│   Clients   │
└──────┬──────┘
       │
   ┌───▼────────────────────────────────┐
   │    API Gateway / Load Balancer     │
   │  (Geo-routing to region)           │
   └───┬─────────────────────────────────┘
       │
  ┌────┴──────────────────────────────────┐
  │                                       │
┌─▼──────────────┐            ┌──────────▼──┐
│  Auth Service  │            │ Rate Limiter │
│  (validates    │            │  (Redis      │
│   tokens)      │            │   backed)    │
└─┬──────────────┘            └──┬───────────┘
  │                              │
  │ Session Cache (Redis)        │ Distributed counter
  │ User DB (PostgreSQL)         │ (Redis)
  │                              │
  └──────────────┬───────────────┘
                 │
         ┌───────▼────────┐
         │  API Handlers  │
         └───────┬────────┘
                 │
      ┌──────────┼──────────┬────────────┐
      │          │          │            │
   ┌──▼──┐   ┌───▼───┐  ┌──▼──┐    ┌────▼────┐
   │Audit│   │Event  │  │User │    │Webhook  │
   │Log  │   │Bus    │  │Data │    │Service  │
   │Svc  │   │(RabbitMQ)│ DB │    │         │
   └──┬──┘   └───────┘  └─────┘    └─┬──────┘
      │                              │
   ┌──▼──────────────────────────────▼──┐
   │  PostgreSQL (Regional + Replicas)   │
   │  - Users, Sessions, Audit Logs      │
   │  - Webhook payloads (encrypted)     │
   └──────────────────────────────────────┘
```

## Final Summary

### Architecture Overview
This is a regionally-aware, asynchronous backend platform serving ~10K-100K concurrent users with audit compliance, rate limiting, and webhook delivery. Session validation and rate limiting are the critical hot paths served from Redis for sub-50ms latency. Audit logging and webhook delivery are decoupled to message queues to prevent database bottlenecks. Multi-region deployment enforces data residency for GDPR compliance, with users pinned to their home region but supported for brief cross-region travel. The system gracefully scales horizontally by adding more service instances and leveraging distributed cache and queue infrastructure.

### Key Tradeoffs
1. **Async audit logging vs. consistency**: Audit logs are fire-and-forget to keep the hot path fast, accepting 100-200ms delay before logs are durable. This is acceptable for enterprise compliance since logs are eventually consistent and immutable once written.

2. **Per-user rate limiting vs. fairness**: Per-user rate limits (100 req/min) are simple but don't account for CI/CD pipelines sharing credentials. We added tiered limits and whitelisting, accepting added configuration complexity in exchange for fair sharing.

3. **Encrypted webhooks vs. debuggability**: Payloads are encrypted but decryption is available via dashboard with audit trail, balancing security (security team) with customer debugging (product team). Tradeoff: slightly worse UX for debugging vs. eliminated risk of accidental exposure.

4. **Regional data residency vs. operational complexity**: GDPR requires EU data to stay in EU, forcing multi-region architecture with operational burden. Worth it for legal compliance and customer trust.

5. **Immediate 10x scaling vs. architectural changes**: Under 2-week deadline, we scale horizontally rather than rearchitecting (e.g., database sharding, webhook acceleration). This works for the immediate crisis but database sharding becomes critical beyond 100K concurrent users.

### Known Limitations
1. **Database sharding not yet planned**: Single PostgreSQL will hit bottleneck at ~500K QPS. Need shard key strategy (user_id likely).

2. **Webhook payload deduplication**: Not implemented. If webhook service crashes mid-delivery, customer might receive duplicate events. Need idempotency keys and customer-side deduplication.

3. **Rate limiter clock skew**: Distributed Redis uses server time, but clock skew between instances can cause ~1% errors in limiting accuracy. Could improve with atomic clock service.

4. **Session invalidation TTL**: Hard-coded 1-hour TTL means logout isn't instant (users could still auth for up to 1 hour after logout if they reuse session token). Could add explicit invalidation list (Bloom filter).

5. **Webhook encryption key rotation**: Public key rotation not yet planned. Need versioning strategy and grace period for customers.

### Operational Runbook

**How to know if it's broken:**
- Monitor `api_gateway.response_time_p99` - should be <500ms. If >1s, check database CPU and audit log query latency.
- Monitor `rate_limiter.redis_latency_p99` - should be <10ms. If >50ms, Redis is under memory pressure or is partitioned.
- Monitor `audit_service.queue_depth` - should be <1K messages. If growing, audit log writes are saturated.
- Monitor `webhook_service.dlq_count` - should be 0. If >0, customer endpoints are down and retries are exhausted.
- Monitor `auth_service.cache_hit_rate` - should be >95%. If <80%, session store is unstable.

**How to fix common issues:**

1. **Response time spike (hot path slow)**:
   - Check `SELECT * FROM audit_logs` query latency first - audit logging should be async only
   - If not that: check Redis latency and heap size
   - Increase Rate Limiter instance count if CPU >70%

2. **Rate limiter not working**:
   - Verify Redis connection is healthy and not partitioned
   - Check if rate limit tier is correctly assigned to customer
   - Confirm Redis cluster replication is in sync

3. **Webhook delivery failing**:
   - Check customer endpoint via manual curl
   - Verify payload is encrypting correctly (check vault access)
   - If queue is backed up, scale webhook consumer instances horizontally
   - For DLQ failures, investigate customer endpoint logs and retry manually

4. **Audit log query slow on dashboard**:
   - Confirm (user_id, timestamp DESC) index exists
   - If table >1GB, archive logs >30 days to separate table
   - Use read replica for dashboard queries

5. **Regional data leaking between regions**:
   - Verify router is assigning correct region based on user home region
   - Check cross-region RPC calls in webhook delivery - should route to customer's region
   - Audit log shipping should never cross regions

