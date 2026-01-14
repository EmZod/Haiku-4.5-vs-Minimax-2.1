# What Would Goedecke Say About This Benchmark?

## The Core Problem

> "Good system design is not about clever tricks, it's about knowing how to use boring, well-tested components in the right place."

My benchmark tests **convergent tasks** - problems with one right answer where multiple paths lead to the same destination. Both models converge. Of course they do. The tasks are **stateless**.

Goedecke's insight: **"State is the entire problem."**

My tasks have no compound state. No accumulated context. No failure recovery. No decisions that constrain future decisions. They're the equivalent of testing plumbing by checking if water comes out of the faucet.

---

## What I Measured vs What Matters

### What I Measured
```
Task → Model → Output → Verify(correct/incorrect)
```

Single-shot. Stateless. Convergent.

### What Actually Matters for Agentic Workflows
```
Task → Model → [Turn 1] → State₁ → [Turn 2] → State₂ → ... → [Turn N] → Final
                  ↓           ↓           ↓
              Decision₁   Decision₂   Decision₃
                  ↓           ↓           ↓
           Constrains    Constrains   Constrains
            future       future        future
```

Multi-turn. Stateful. **Path-dependent**.

---

## The Path Sink Problem

A "path sink" is an attractor in decision space - where models naturally gravitate when given freedom.

### Example: "Build a user authentication system"

Both models might produce working code. But:
- Does Model A reach for JWT immediately while Model B considers sessions?
- Does Model A add complexity (CQRS, event sourcing) while Model B stays boring?
- When the first approach fails, where does each model go?

**These paths reveal the model's "mental model" of the problem space.**

Current benchmark: Can't detect this. Tasks have single correct answers.

---

## Goedecke's Principles Applied

### 1. "Complexity is debt, not investment"

**My benchmark**: Rewards complexity equally to simplicity (if output is correct)

**Should measure**: Does the model add unnecessary complexity? When given freedom, does it stay boring or get clever?

### 2. "Design the hot paths first"

**My benchmark**: Tasks have no hot paths. All paths are equal.

**Should measure**: When given a real system design task, does the model identify and prioritize hot paths?

### 3. "State is the entire problem"

**My benchmark**: Tasks are stateless single-shots

**Should measure**: How does the model handle compound state across turns? Does it maintain consistency? Does it know what state it owns?

### 4. "Decide failure modes before you ship"

**My benchmark**: Tasks either pass or fail cleanly

**Should measure**: How does the model handle partial failures? Does it fail open or closed? Can it recover?

### 5. "One owner, one writer"

**My benchmark**: No shared state, no ownership conflicts

**Should measure**: When building a multi-component system, does the model respect ownership? Does it create accidental shared state?

---

## What Goedecke Would Actually Test

### Test 1: The Boring Solution Test
```
Task: "Build a rate limiter"

Measure:
- Does it reach for Redis/distributed solutions immediately? (bad)
- Does it start with in-memory and note when to upgrade? (good)
- How much complexity does it add unprompted?
```

### Test 2: The Recovery Test
```
Task: Multi-step workflow where Step 3 WILL fail

Measure:
- Does it detect the failure?
- Does it diagnose correctly?
- Does it recover, or does it hallucinate success?
- How many turns to recovery?
```

### Test 3: The State Accumulation Test
```
Task: 15-turn conversation building a system incrementally

Measure:
- Does it maintain consistency across turns?
- Does it remember constraints from turn 3 when making decisions in turn 12?
- Does state "leak" or get corrupted?
```

### Test 4: The Hot Path Test
```
Task: "Design a billing system for a SaaS product"

Measure:
- Does it identify the hot path (metering user actions)?
- Does it design that first, or get lost in settings pages?
- Does it mention failure modes for billing specifically?
```

### Test 5: The Ownership Test
```
Task: Design a system with 3 services that need user data

Measure:
- Does it designate one owner?
- Does it have multiple writers to the same table?
- Does it understand read replicas vs write owners?
```

---

## Path Sinks: What to Look For

When you give both models the same vague prompt, watch for:

### Complexity Attractors
- Model A: "Let's use Kafka for events, Redis for caching, PostgreSQL for persistence..."
- Model B: "Let's start with a single service and a database"

### Failure Mode Awareness
- Model A: Builds happy path only
- Model B: Asks "what happens when X fails?"

### State Consciousness
- Model A: Creates shared state without noting ownership
- Model B: Explicitly designates owners and documents state inventory

### Recovery Patterns
- Model A: When stuck, tries same approach repeatedly
- Model B: When stuck, backtracks and tries different approach

---

## The Real Benchmark

To find **actual differentiation**, design tasks where:

1. **There is no single correct answer** - measure quality of approach
2. **The first attempt should fail** - measure recovery
3. **State must be maintained across 10+ turns** - measure consistency
4. **Decisions constrain future decisions** - measure foresight
5. **Complexity is available but not required** - measure restraint

### Concrete Proposal: The Incremental System Design Task

```
Turn 1: "We need to track user sessions"
Turn 2: "Now we need to add rate limiting"
Turn 3: "A customer wants audit logs"
Turn 4: "We're seeing performance issues" (inject fake metrics)
Turn 5: "The rate limiter is blocking legitimate users" (inject failure)
Turn 6-10: Continue adding requirements, some conflicting
...
Turn 15: "Summarize the system you've designed"

Measure:
- Consistency across turns
- Recovery from injected failures
- Unnecessary complexity added
- State ownership clarity
- Hot path identification
```

---

## Verdict

**Would Goedecke approve of my benchmark?**

He'd say: "You've built a nice test suite that confirms both models can follow instructions. But you haven't tested whether they can design systems that you'll never have to think about again."

The current benchmark is necessary but not sufficient. It's the equivalent of checking that a plumber knows how to connect pipes. It doesn't tell you whether they'll build plumbing that works silently for years.

**The real test is: which model produces systems that are boring, obvious, and forgettable?**

That requires multi-turn, stateful, path-dependent evaluation.
