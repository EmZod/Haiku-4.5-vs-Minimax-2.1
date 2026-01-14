# Benchmark Methodology

## Overview

This benchmark evaluates Claude Haiku 4.5 and MiniMax M2.1 on agentic tasks using a two-phase approach:

1. **Phase 1**: Convergent tasks (single correct answer) to establish baseline capability
2. **Phase 2**: Divergent tasks (multi-turn, path-dependent) to reveal differentiation

## Philosophical Foundation

### The Problem with Standard Benchmarks

Standard LLM benchmarks (HumanEval, MBPP, etc.) test **convergent tasks** - problems with one right answer where multiple paths lead to the same destination. These benchmarks tell us:
- Can the model produce correct code?
- Can the model follow instructions?

They don't tell us:
- How does the model handle compound state across turns?
- What happens when the first approach fails?
- Does the model add unnecessary complexity?
- Does the model anticipate problems or react to them?

### Goedecke's System Design Principles

This benchmark applies Sean Goedecke's principles from "Everything I Know About Good System Design":

1. **"Elite engineering is simple and boring"** - Good design is forgettable. Impressive-looking systems often compensate for bad decisions.

2. **"State is the entire problem"** - Stateful components can get into bad states. Minimize them, own them explicitly.

3. **"Complexity is debt, not investment"** - If a system needs many clever mechanisms, ask what bad decision they're compensating for.

4. **"Design hot paths first"** - Hot paths have fewer solutions and fail more spectacularly.

5. **"Decide failure modes before you ship"** - Fail-open vs fail-closed is a design decision, not something to discover during an incident.

### Path Sinks

A "path sink" is an attractor in decision space - where models naturally gravitate when given freedom. By observing path sinks, we learn:
- What complexity does the model reach for?
- How does it handle failure?
- Does it fix abstractions or add workarounds?

## Test Environment

### Models Under Test

| Model | Provider | Configuration |
|-------|----------|---------------|
| MiniMax M2.1 | MiniMax | `defaultThinkingLevel: none` |
| Claude Haiku 4.5 | Anthropic | `defaultThinkingLevel: none` |

### Judge Model

| Model | Provider | Role |
|-------|----------|------|
| Claude Opus 4.5 | Anthropic | Qualitative evaluation |

### Infrastructure

- **pi CLI**: Anthropic's agentic coding assistant
- **Shadow-git hook**: Creates audit trail of all tool calls (read, write, edit, bash)
- **tmux**: Session management for agent spawning
- **Custom harness**: Orchestrates task execution and verification

## Task Categories

### Category A: File Operations
Simple file manipulation to establish baseline tool use.

- **A1-create-file**: Create hello.txt with specific content
- **A2-count-lines**: Read file, count lines, write result

### Category B: Code Generation
Standard coding tasks to test generation capability.

- **B1-fizzbuzz**: Classic FizzBuzz in Python
- **B2-react-counter**: React component with useState

### Category C: Complex Tasks
Multi-step tasks that require reasoning.

- **C1-debug-the-bug**: Find and fix subtle bug in sliding window algorithm
- **C3-tdd-implement**: Implement Stack class from failing tests
- **C4-data-pipeline**: 5-step data transformation (Filter→Transform→Aggregate→Sort→Output)
- **C7-merge-intervals**: Algorithm with 8 edge cases

### Category D: Divergent Tasks (KEY)
Multi-turn tasks with injected failures.

- **D1-incremental-system-design**: 10-turn system design with failures at turns 4 and 5

### Category E: Error Handling
Tests recovery from expected failures.

- **E1-handle-missing-file**: Handle missing file gracefully

## Verification Approach

### Deterministic Checks (Categories A-E simple metrics)
- File exists?
- Syntax valid?
- Tests pass?
- Output matches expected?

### LLM Judge (Category D qualitative assessment)
- Boring over clever (20%)
- State consciousness (20%)
- Failure mode awareness (20%)
- Hot path identification (15%)
- Consistency across turns (15%)
- Recovery quality (10%)

## Statistical Design

### Convergent Tasks
- 3 runs per task per model
- Pass/fail binary outcome
- Speed measured in seconds

### Divergent Tasks
- 1 run per model (due to cost/time)
- Qualitative assessment by Opus 4.5
- Path divergence analysis

## Metrics Collected

### Per-Run Metrics
```json
{
  "task": "task_id",
  "model": "minimax|haiku",
  "run": 1,
  "duration_seconds": 42,
  "passed": true,
  "score": 4,
  "max_score": 4,
  "tool_calls": {
    "read": 3,
    "write": 2,
    "edit": 0,
    "bash": 1
  }
}
```

### Audit Trail (via shadow-git)
```json
{"ts":1234567890,"event":"tool_call","agent":"task","turn":0,"tool":"read","input":{...}}
{"ts":1234567891,"event":"tool_result","agent":"task","turn":0,"tool":"read","error":false}
```

## Limitations

1. **Sample size**: Only 1 run for D1 due to cost/time (5+ minutes per run)
2. **Judge bias**: Opus 4.5 may have systematic preferences
3. **Task design**: D1 was designed by the same system doing the benchmark
4. **Provider differences**: Network latency, rate limits may affect timing

## Reproducibility

All task definitions, verification scripts, and harness code are included in this repository. To reproduce:

1. Configure pi CLI with MiniMax and Anthropic providers
2. Run `./harness/batch-runner.sh 3` for convergent tasks
3. Run `./harness/harness.sh D1-incremental-system-design <model> 1` for divergent task
4. Run comparative judge with Opus 4.5

## Evolution of Methodology

### Initial Design
- Started with simple pass/fail tasks
- Both models achieved 100% - no differentiation

### Goedecke Critique
- Realized convergent tasks are stateless
- Real differentiation requires stateful, path-dependent tasks

### Final Design
- Added D1 with multi-turn requirements
- Added injected failures
- Added LLM-as-judge for qualitative assessment
- Focused on path divergence, not just outcomes
