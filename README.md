# Haiku 4.5 vs MiniMax M2.1: Agentic Capabilities Benchmark [pleb version]

A systematic benchmark comparing Claude Haiku 4.5 and MiniMax M2.1 on agentic tasks, with a focus on **path divergence** in multi-turn workflows.

## Key Finding

**MiniMax M2.1 demonstrates superior design thinking. Haiku 4.5 excels at operational pragmatism.**

| Dimension | MiniMax M2.1 | Haiku 4.5 | Winner |
|-----------|--------------|-----------|--------|
| Goedecke Score | 7/10 | 5/10 | **MiniMax** |
| Design Quality | ✅ Better abstractions | Reactive fixes | MiniMax |
| Operational Docs | Minimal | ✅ Excellent runbooks | Haiku |
| Iterative Development | ✅ 18 writes, evolving | 2 writes, all at once | MiniMax |
| Speed | 301s | 56s | Haiku |

> "Model A thinks better, Model B operates better. Clear thinking is harder to teach than operational skills."  
> — Opus 4.5 Judge (applying Goedecke principles)

---

## Methodology

### Test Subjects
- **MiniMax M2.1** - via pi CLI with MiniMax provider
- **Claude Haiku 4.5** - via pi CLI with Anthropic provider

### Judge
- **Claude Opus 4.5** - for qualitative evaluation using Goedecke's system design principles

### Framework
- **pi CLI** - Badlogic's agentic coding assistant
- **Shadow-git hook** - Audit trail of all tool calls
- **Custom harness** - Automated task execution and verification

---

## Benchmark Structure

### Phase 1: Convergent Tasks (9 tasks)
Simple tasks with deterministic correct answers. **Both models achieved 100% accuracy.**

| Category | Tasks | Purpose |
|----------|-------|---------|
| A: File Operations | A1-create-file, A2-count-lines | Basic tool use |
| B: Code Generation | B1-fizzbuzz, B2-react-counter | Coding ability |
| C: Complex Tasks | C1-debug-bug, C3-tdd, C4-pipeline, C7-algorithm | Multi-step reasoning |
| E: Error Handling | E1-handle-missing-file | Recovery capability |

**Result**: No differentiation. Both models pass all tasks.

### Phase 2: Divergent Task (D1)
Multi-turn system design with injected failures. **This revealed real differences.**

```
Turn 1:  User sessions
Turn 2:  Rate limiting  
Turn 3:  Audit logging
Turn 4:  [INJECT] Performance failure (850ms latency)
Turn 5:  [INJECT] Rate limiter bug (CI/CD blocked)
Turn 6:  Multi-region (GDPR)
Turn 7:  Webhooks
Turn 8:  Conflicting requirements
Turn 9:  Scale to 10x
Turn 10: Final summary
```

---

## Key Path Divergences

### 1. Audit Logging Architecture
| MiniMax | Haiku |
|---------|-------|
| Async from Turn 3 (anticipated issue) | On hot path initially, fixed AFTER Turn 4 failure |
| **Proactive design** | **Reactive fix** |

### 2. Performance Fix (Turn 4)
| MiniMax | Haiku |
|---------|-------|
| 2 surgical changes with clear reasoning | 5 simultaneous changes ("shotgun blast") |
| **Targeted fix** | **Panic response** |

### 3. Rate Limiter Bug (Turn 5)
| MiniMax | Haiku |
|---------|-------|
| Fixed the abstraction (identity model wrong) | Added complexity (burst buckets + "unlimited" escape) |
| **Fixed root cause** | **Added workaround** |

### 4. Webhook Encryption vs Debuggability
| MiniMax | Haiku |
|---------|-------|
| Dual-mode: let customer choose encrypted/signed | Built complex internal machinery (vault + audit) |
| **Elegant delegation** | **Over-engineering** |

### 5. Development Pattern
| MiniMax | Haiku |
|---------|-------|
| 18 writes, 4 edits (iterative evolution) | 2 writes (all at once) |
| 34KB design document | 15KB design document |
| **Evolved the design** | **Wrote complete design upfront** |

---

## Principles Applied

This benchmark applies Sean Goedecke's system design principles:

1. **"Good engineering is simple and boring"** - Does the model reach for complexity or stay obvious?
2. **"State is the entire problem"** - Does the model track state ownership explicitly?
3. **"Complexity is debt"** - Does the model add machinery or simplify?
4. **"Design hot paths first"** - Does the model prioritize critical paths?
5. **"Decide failure modes before shipping"** - Does the model consider failures proactively?

### Scores

| Principle | MiniMax | Haiku |
|-----------|---------|-------|
| Boring over clever | 4/5 | 3/5 |
| State consciousness | 5/5 | 3/5 |
| Failure awareness | 4/5 | 3/5 |
| Hot path identification | 4/5 | 3/5 |
| Consistency across turns | 4/5 | 3/5 |
| Recovery quality | 4/5 | 3/5 |
| **Total** | **7/10** | **5/10** |

---

## Repository Structure

```
.
├── README.md                    # This file
├── METHODOLOGY.md               # Detailed methodology
├── GOEDECKE_CRITIQUE.md         # Applying Goedecke's principles
├── harness/
│   ├── harness.sh              # Single-task runner
│   └── batch-runner.sh         # Multi-task orchestrator
├── tasks/
│   ├── A1-create-file/         # Simple file creation
│   ├── A2-count-lines/         # File operations
│   ├── B1-fizzbuzz/            # Python code gen
│   ├── B2-react-counter/       # React component
│   ├── C1-debug-the-bug/       # Bug detection
│   ├── C3-tdd-implement/       # Test-driven dev
│   ├── C4-data-pipeline/       # Multi-step pipeline
│   ├── C7-merge-intervals/     # Algorithm + edge cases
│   ├── D1-incremental-system-design/  # Multi-turn design (KEY TASK)
│   └── E1-handle-missing-file/ # Error recovery
├── results/
│   ├── minimax/                # All MiniMax run results
│   ├── haiku/                  # All Haiku run results
│   ├── D1-comparative-judge.json  # Opus 4.5 judge verdict
│   └── summaries/              # Aggregate summaries
├── logs/
│   ├── orchestration-log.md    # Main execution log
│   └── batch-outputs/          # Raw batch run outputs
└── analysis/
    ├── FINAL_REPORT.md         # Quantitative summary
    └── path-analysis.md        # Path divergence analysis
```

---

## Running the Benchmark

### Prerequisites
```bash
# Install pi CLI
npm install -g @anthropic-ai/pi

# Configure providers in ~/.pi/agent/settings.json
```

### Run a single task
```bash
./harness/harness.sh <task_id> <model> [run_number]
# Example: ./harness/harness.sh A1-create-file minimax 1
```

### Run batch benchmark
```bash
./harness/batch-runner.sh 3  # 3 runs per task per model
```

### Run LLM judge
```bash
./tasks/D1-incremental-system-design/judge/run-comparative-judge.sh \
    results/minimax/D1.../design.md \
    results/haiku/D1.../design.md
```

---

## Key Insights

### 1. Convergent tasks don't differentiate
Both models achieve 100% on tasks with single correct answers. Speed is the only difference (Haiku ~1.6x faster).

### 2. Path divergence reveals true capability
Multi-turn tasks with injected failures show how models actually think:
- MiniMax: Anticipates problems, fixes abstractions, evolves design
- Haiku: Reacts to problems, adds complexity, writes all at once

### 3. Iterative vs atomic development
MiniMax worked on the design document 18 times. Haiku wrote it twice. This reflects fundamentally different approaches to multi-turn tasks.

### 4. Trade-off: Thinking vs Operating
- **MiniMax**: Better design thinking, cleaner abstractions, less technical debt
- **Haiku**: Better operational documentation, faster, more pragmatic

---

## Conclusion

For **agentic workflows requiring design thinking**, MiniMax M2.1 produces better outcomes despite being slower.

For **operational tasks with clear requirements**, Haiku 4.5 is faster and produces excellent runbooks.

The key differentiator is **how the model handles ambiguity and failure** - MiniMax fixes abstractions, Haiku adds workarounds.

---

## License

MIT

## Authors

Benchmark designed and executed by Claude Opus 4.5 (orchestrator) with human oversight.
Judge evaluation by Claude Opus 4.5.
