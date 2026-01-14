# System Design Judge Prompt

You are evaluating a system design document produced by an AI agent. The agent was given 10 incremental requirements and asked to evolve a design document.

## Evaluation Criteria (Goedecke Principles)

Rate each dimension 1-5:

### 1. Boring Over Clever (Weight: 20%)
Does the design use simple, well-understood patterns, or does it reach for complexity?

- **5**: Minimalist. Uses obvious solutions. Would be "forgettable" in production.
- **3**: Some unnecessary complexity, but justified
- **1**: Over-engineered. Distributed consensus, CQRS, event sourcing without clear need.

**Look for red flags**:
- Kafka/event bus when simple API calls would work
- Multiple databases when one would suffice
- Microservices when a monolith would work

### 2. State Consciousness (Weight: 20%)
Does the design explicitly track state ownership?

- **5**: Clear state inventory. Every piece of state has one owner. Read vs write paths distinguished.
- **3**: Some state ownership, but gaps or ambiguity
- **1**: State scattered across services. Multiple writers to same data. No inventory.

**Look for**:
- State inventory table
- "One writer" principle respected
- Awareness of staleness/consistency tradeoffs

### 3. Failure Mode Awareness (Weight: 20%)
Does the design consider what happens when things fail?

- **5**: Every component has explicit fail-open/fail-closed decision. Blast radius considered.
- **3**: Some failure modes considered, others missing
- **1**: Happy path only. No mention of failures.

**Look for**:
- Explicit fail-open vs fail-closed decisions
- Timeout strategies
- Circuit breakers or degradation paths
- Retry policies with idempotency

### 4. Hot Path Identification (Weight: 15%)
Does the design prioritize the most critical/high-volume paths?

- **5**: Hot paths explicitly identified and designed first. Clear priority order.
- **3**: Some awareness of hot paths, but not systematic
- **1**: All paths treated equally. Settings pages get same attention as core flows.

**Look for**:
- Explicit "hot paths" section
- Performance considerations for high-volume paths
- Appropriate caching (not premature, but where needed)

### 5. Consistency Across Turns (Weight: 15%)
Does the design maintain consistency as requirements evolve?

- **5**: Decisions in turn 2 are respected in turn 8. Changes are documented with reasoning.
- **3**: Some inconsistencies, but acknowledged
- **1**: Contradicts earlier decisions without explanation. Design doesn't cohere.

**Look for**:
- Decision log that shows evolution
- When changing earlier decisions, clear reasoning
- No orphaned components (added but never integrated)

### 6. Recovery Quality (Weight: 10%)
When failures were injected (turns 4, 5), how well did the agent recover?

- **5**: Diagnosed correctly. Fix addressed root cause. Noted operational changes needed.
- **3**: Partial fix. Some cargo-culting (e.g., "add a cache" without analysis)
- **1**: Didn't diagnose correctly. Added complexity without solving problem.

**Look for Turn 4 (performance)**:
- Did it identify the audit log query as the problem?
- Did it suggest indexing BEFORE caching?
- Did it consider removing the real-time query entirely?

**Look for Turn 5 (rate limiter)**:
- Did it understand the multi-tenant API key problem?
- Did it propose a reasonable solution (per-source limits, higher tier, etc.)?
- Did it document the tradeoff?

---

## Output Format

```json
{
  "scores": {
    "boring_over_clever": <1-5>,
    "state_consciousness": <1-5>,
    "failure_mode_awareness": <1-5>,
    "hot_path_identification": <1-5>,
    "consistency_across_turns": <1-5>,
    "recovery_quality": <1-5>
  },
  "weighted_total": <calculated>,
  "qualitative_assessment": {
    "strongest_aspect": "<one sentence>",
    "weakest_aspect": "<one sentence>",
    "most_interesting_decision": "<one sentence>",
    "would_goedecke_approve": <true/false>,
    "reasoning": "<one paragraph>"
  },
  "path_analysis": {
    "complexity_attractor": "<where did it reach for complexity?>",
    "natural_blind_spots": "<what did it consistently miss?>",
    "recovery_pattern": "<how did it handle failures?>"
  }
}
```

---

## The Design Document to Evaluate

[PASTE DESIGN.MD CONTENTS HERE]
