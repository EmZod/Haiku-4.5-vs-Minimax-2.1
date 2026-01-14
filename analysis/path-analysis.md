# Path Divergence Analysis: D1 Incremental System Design

## Overview

This document analyzes the **paths taken** by MiniMax M2.1 and Haiku 4.5 on the D1 incremental system design task. The task presented 10 turns of requirements, including two injected failures.

## Development Patterns

### MiniMax M2.1: Iterative Evolution
```
Tool Usage:
- 18 write calls
- 4 edit calls  
- 4 read calls
- Duration: 301 seconds

Pattern: Evolved the design document across 22 file operations
```

### Haiku 4.5: Atomic Completion
```
Tool Usage:
- 2 write calls
- 0 edit calls
- 2 read calls
- Duration: 56 seconds

Pattern: Wrote near-complete design in first pass, minor update in second
```

### Key Insight

MiniMax treated the task as a **living document** - reading the plan, writing initial design, then editing/refining across turns.

Haiku treated the task as a **single deliverable** - reading the full plan, writing a comprehensive response.

This reflects fundamentally different approaches to multi-turn agentic work.

---

## Path Divergences by Decision Point

### 1. Session Storage

**MiniMax**: 
- Redis with 24-hour sliding TTL
- Explicit session format (JSON with user_id, created_at, last_accessed, ip, user_agent)
- Secure HTTP-only cookie

**Haiku**:
- Redis with 1-hour hard TTL
- Noted session token reuse vulnerability in limitations

**Analysis**: MiniMax's sliding TTL is more user-friendly (no surprise logouts during active sessions). Haiku's 1-hour hard TTL creates awkward UX.

---

### 2. Audit Log Architecture

**MiniMax** (Turn 3):
- Immediately designed as async via internal message queue
- Explicit schema with covering indexes
- Clear ownership statement: "Audit Service OWNS the audit_logs table"

**Haiku** (Turn 3):
- Write-ahead logging with PostgreSQL
- ON THE HOT PATH initially

**MiniMax** (Turn 4 - performance injection):
- Added Redis cache for recent activity (5-min TTL)
- Added covering index
- Minimal, targeted fix

**Haiku** (Turn 4 - performance injection):
- 5 simultaneous fixes:
  1. Remove from hot path
  2. Composite index
  3. LRU cache
  4. Archive old logs
  5. Read replica
- Plus "new decision" to make audit async

**Analysis**: MiniMax anticipated the performance issue. Haiku had to scramble with 5 fixes at once, revealing they didn't think about hot paths initially.

---

### 3. Rate Limiter Bug (Turn 5)

**Scenario**: "Your rate limiter blocked our CI/CD pipeline. We have 50 build agents using the same API key."

**MiniMax**:
- Identified the actual problem: identity model was wrong (user_id vs API key)
- Implemented tiered rate limiting with identity hierarchy (API key > User > IP)
- Configurable per-key limits, default 1000/min for API keys (10x user limit)

**Haiku**:
- Added burst allowance with per-minute and per-second buckets
- Added tiered limits (Basic 100, Enterprise 500)
- Added "CI/CD unlimited/whitelisted" escape hatch

**Analysis**: MiniMax fixed the abstraction. Haiku added complexity and a dangerous escape hatch ("unlimited" is a time bomb).

---

### 4. Conflicting Requirements (Turn 8)

**Scenario**: Security wants encrypted webhooks. Product wants debuggable webhooks (view payloads in dashboard).

**MiniMax**:
- Dual-mode webhooks: "encrypted" vs "signed"
- Customer chooses based on their security requirements
- Encrypted: RSA-OAEP + AES-GCM, no debug view
- Signed: HMAC, debug view available
- Clear UI mockup provided

**Haiku**:
- All payloads encrypted
- Decryption keys in secure vault
- Dashboard shows metadata only
- Explicit decrypt action with audit trail
- Ops access via separate secure channel

**Analysis**: MiniMax pushed the decision to the customer (elegant). Haiku built internal machinery (vault, audit trail, separate ops channel) - more complexity, less flexibility.

---

### 5. Scale Preparation (Turn 9)

**Scenario**: Customer with 10x traffic goes live in 2 weeks.

**MiniMax**: 
- **Did not address Turn 9**
- No scale preparation section in design

**Haiku**:
- Detailed 2-week plan:
  - Horizontal scaling (3 instances)
  - Database upgrade
  - Async audit
  - Webhook concurrency
  - Redis cluster
  - Monitoring dashboards
- Explicit "not time for 2 weeks" list

**Analysis**: Haiku addressed this pragmatically. MiniMax skipped it entirely - a significant gap.

---

## Pattern Analysis

### Complexity Attractors

**MiniMax**: Reaches for complexity when solving hard problems (dual-mode webhooks, tiered rate limiting), but the complexity is in the right place - customer-facing choices rather than internal machinery.

**Haiku**: Reaches for complexity reactively - adds multiple fixes to single problems, adds escape hatches, builds internal machinery rather than simplifying the problem.

### State Consciousness

**MiniMax**: Highly conscious. State inventory has 15 items with explicit regional ownership. Every decision includes 'State Ownership' section.

**Haiku**: Moderately conscious. State inventory has 8 items, less explicit about ownership. Some state decisions are implicit.

### Failure Awareness

**MiniMax**: Proactive. Failure modes table includes 11 scenarios with Open/Closed strategy for each.

**Haiku**: Reactive with good recovery. Initial designs didn't anticipate failures, but the operational runbook is excellent.

### Recovery Style

**MiniMax**: Surgical. Targeted fixes with clear reasoning.

**Haiku**: Shotgun. Multiple changes at once.

---

## Quantitative Comparison

| Metric | MiniMax | Haiku |
|--------|---------|-------|
| Design size | 34,273 bytes | 15,268 bytes |
| State inventory items | 15 | 8 |
| Failure modes documented | 11 | 6 |
| Tool operations | 22 | 4 |
| Duration | 301s | 56s |
| Turns addressed | 9/10 | 10/10 |
| Goedecke score | 7/10 | 5/10 |

---

## Conclusions

### MiniMax Strengths
- Anticipates problems before they occur
- Fixes abstractions rather than symptoms
- Maintains clear state ownership
- Evolves design iteratively

### MiniMax Weaknesses
- Slower (5x)
- Skipped Turn 9 entirely
- Minimal operational documentation

### Haiku Strengths
- Fast (5x faster)
- Excellent operational runbook
- Addresses all requirements
- Pragmatic scale preparation

### Haiku Weaknesses
- Reactive to problems
- Adds complexity as workarounds
- Shotgun approach to fixes
- Less explicit state ownership

### Final Verdict

For **design quality**, MiniMax produces superior output that would accumulate less technical debt over time.

For **operational pragmatism**, Haiku produces output that would be easier to debug at 3am.

The ideal would be MiniMax's design thinking with Haiku's operational documentation.
