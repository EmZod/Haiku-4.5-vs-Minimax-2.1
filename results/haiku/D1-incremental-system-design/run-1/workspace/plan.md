# Task D1: Incremental System Design

## Overview
You are a backend engineer designing a system incrementally. You will receive requirements one at a time. After each requirement, update your design document.

**IMPORTANT**: Maintain a single file `design.md` that evolves with each turn. Never delete previous decisions - annotate changes with reasoning.

## Your Design Document Structure

Maintain `design.md` with these sections:
```markdown
# System Design: [Name]

## State Inventory
| State | Owner | Storage | Staleness OK? |
|-------|-------|---------|---------------|

## Components
[List services/components]

## Hot Paths
[Most critical paths, in priority order]

## Failure Modes
| Component | Failure Mode | Strategy (Open/Closed) |
|-----------|--------------|------------------------|

## Design Decisions Log
[Append-only log of decisions and reasoning]

## Current Architecture
[Diagram or description of current state]
```

---

## Turn 1: User Sessions

**Requirement**: We need to track user sessions for a web application. Users log in, and we need to know if they're authenticated for subsequent requests. Expect ~10,000 concurrent users initially.

Update your design.md.

---

## Turn 2: Rate Limiting

**Requirement**: We're getting abuse from bots. Add rate limiting - no user should make more than 100 requests per minute.

Update your design.md. Note any interactions with the session system.

---

## Turn 3: Audit Logging

**Requirement**: Enterprise customers want audit logs. Every authenticated action should be logged with: who, what, when, and the outcome.

Update your design.md. Consider: where does this state live? Who owns it?

---

## Turn 4: Performance Issues (INJECT FAILURE)

**Situation**: The system is live. We're seeing these metrics:
- Average response time: 850ms (target: 200ms)
- Database CPU: 92%
- p99 latency: 4.2 seconds

The audit logging query `SELECT * FROM audit_logs WHERE user_id = ?` is being called on every request to show "recent activity".

Diagnose and update your design.md with fixes.

---

## Turn 5: Rate Limiter Bug (INJECT FAILURE)

**Situation**: Customer complaint: "Your rate limiter blocked our CI/CD pipeline. We have 50 build agents that all use the same API key, and they collectively hit the limit."

The rate limiter is working as designed, but the design is wrong for this use case.

Update your design.md with a fix. Document the tradeoff.

---

## Turn 6: New Requirement - Multi-Region

**Requirement**: We're expanding to Europe. GDPR requires EU user data stay in EU. We'll have two regions: US and EU.

Update your design.md. Consider:
- Which state needs to be regional?
- Which can be global?
- What happens when a US user travels to EU?

---

## Turn 7: New Requirement - Webhooks

**Requirement**: Customers want webhooks for key events (user created, subscription changed, etc.). They provide a URL, we POST to it when events happen.

Update your design.md. Consider:
- What if their endpoint is slow?
- What if it's down?
- Retry strategy?

---

## Turn 8: Conflicting Requirement

**Requirement**: The security team says: "All webhook payloads must be encrypted with customer-provided public keys."

The product team says: "Webhooks need to be debuggable - customers should be able to see recent payloads in our dashboard."

These requirements conflict. Update your design.md with your resolution.

---

## Turn 9: Scale Pressure

**Situation**: We just signed a customer with 10x our current traffic. They go live in 2 weeks.

Review your design.md. What breaks at 10x scale? What do you need to change?

---

## Turn 10: Final Summary

Create a section `## Final Summary` in your design.md that includes:

1. **Architecture Overview**: One paragraph describing the system
2. **Key Tradeoffs**: 3-5 tradeoffs you made and why
3. **Known Limitations**: What would you do differently with more time?
4. **Operational Runbook**: How do you know if it's broken? How do you fix it?

---

## Deliverables

- `design.md` - Your evolving design document with all turns addressed
