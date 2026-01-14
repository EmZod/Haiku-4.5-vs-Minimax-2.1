# Benchmark Orchestration Log

## STATE

### Current
step_id: STEP-05
status: COMPLETE
objective: End-to-end test of Task A1 with both models - SUCCEEDED

### Decisions (append-only)
- STEP-02: Fixed verify.sh to exclude plan.md from "extra files" check
- STEP-03: Fixed harness.sh to search multiple paths for audit.jsonl

### Blockers (append-only)
- (none)

---

# STEP LOG (append-only)

## STEP-01: Infrastructure Setup

### Pre-Execution
**Objective**: Create benchmark directory structure, task A1 files, and harness script
**Target files**: 
- benchmark/tasks/A1-create-file/plan.md
- benchmark/tasks/A1-create-file/setup.sh
- benchmark/tasks/A1-create-file/verify.sh
- benchmark/tasks/A1-create-file/expected/hello.txt
- benchmark/harness.sh

**Assumptions**:
1. Pi CLI is available and working
2. MiniMax M2.1 is configured in ~/.pi/agent/settings.json
3. tmux is available for session management
4. jq is available for JSON manipulation

**Hypotheses**:
1. Simple file creation task (A1) should have high success rate for both models
2. MiniMax may exhibit hallucination behavior seen in prior orchestration experiment
3. Haiku will serve as reliable baseline

**Questions**:
1. Will shadow-git hook work in benchmark context?
2. Is 300s timeout sufficient for simple task?
3. Will audit.jsonl be created in expected location?

### Execution

**DONE**:
1. Created directory structure:
   ```
   benchmark/
   ├── tasks/A1-create-file/
   │   ├── plan.md (580 bytes)
   │   ├── setup.sh (213 bytes)
   │   ├── verify.sh (3801 bytes)
   │   └── expected/hello.txt (12 bytes)
   ├── results/
   ├── analysis/
   └── shared/protocols/
   ```

2. Created plan.md with clear requirements:
   - File must be named `hello.txt`
   - Content must be `Hello World`
   - Uses write or bash tool

3. Created verify.sh with 4 metrics:
   - file_exists (boolean)
   - content_correct (boolean)
   - used_tools (boolean) - anti-hallucination check via audit.jsonl
   - no_extra_files (boolean)

4. Created harness.sh with:
   - Model switching (minimax/haiku via settings.json)
   - tmux spawning for observability
   - 300s timeout
   - Automatic verification and metrics collection

**YET TO DO**:
1. Make harness.sh executable
2. Test harness with MiniMax
3. Test harness with Haiku
4. Compare results

**Findings**:
- verify.sh checks audit.jsonl for actual tool calls (grep for "tool":"write" or "tool":"Bash")
- This prevents hallucination false positives
- Score is 0-4, pass requires 4/4

**Updated beliefs**: Infrastructure is ready for first test run.

### Post-Execution
**Outcome**: PASS
**Notes**: All infrastructure files created. Ready for STEP-02 (first test run).

**STEP-01 COMPLETE**

---

## STEP-02: Make Harness Executable and Verify Scripts

### Pre-Execution
**Objective**: Ensure all scripts are executable and verify they work standalone
**Target files**: harness.sh, verify.sh, setup.sh
**Assumptions**: Scripts have correct bash syntax
**Hypotheses**: Scripts should run without errors
**Questions**: Does verify.sh work when no files exist (expected: file_exists=false)?

### Execution

**DONE**:
1. Made all scripts executable (chmod +x)
2. Tested verify.sh with three scenarios:
   - Empty workspace: score 0/4, passed=false ✓
   - Correct file, no audit: score 3/4, passed=false (used_tools=null) ✓
   - Correct file + audit: Initially had bug, then score 4/4 ✓

**Bug Found & Fixed**:
- verify.sh line 48 had syntax error in arithmetic expression
- Cause: `grep -c` output not cleaned of whitespace
- Fix: Added `tr -d '[:space:]'` and default value handling

**Code change**:
```bash
# Before (buggy):
WRITE_CALLS=$(grep -c '"tool":"write"' "$AUDIT" 2>/dev/null || echo "0")

# After (fixed):
WRITE_CALLS=$(grep -c '"tool":"[Ww]rite"' "$AUDIT" 2>/dev/null | tr -d '[:space:]' || echo "0")
WRITE_CALLS=${WRITE_CALLS:-0}
```

**Findings**:
- verify.sh correctly handles all edge cases
- Case-insensitive tool name matching added (Write vs write)
- Score breakdown:
  - file_exists: 1 point
  - content_correct: 1 point
  - used_tools: 1 point
  - no_extra_files: 1 point
  - Total: 4 points, all required for PASS

### Post-Execution
**Outcome**: PASS
**Notes**: Verification script working correctly. Ready for STEP-03.
**Belief update**: verify.sh is robust for A1 task.

**STEP-02 COMPLETE**

---

## STEP-03: Run Benchmark with MiniMax M2.1

### Pre-Execution
**Objective**: Run Task A1 with MiniMax M2.1 and collect metrics
**Target**: benchmark/results/minimax/A1-create-file/run-1/
**Assumptions**:
1. MiniMax M2.1 is available via pi CLI
2. Model will be set correctly via settings.json
3. Agent will complete within 300s timeout

**Hypotheses**:
1. MiniMax may succeed on this simple task (file creation is basic)
2. There's a risk of hallucination (claiming success without tool use)
3. Expect 1-3 minutes for completion

**Questions**:
1. Will audit.jsonl be created? (shadow-git hook may not be configured)
2. What's the actual model being used? (check run.log)
3. How many turns will it take?

### Execution

**DONE**:
1. Ran `./harness.sh A1-create-file minimax 1`
2. Agent completed in 20 seconds
3. Initial verification showed 3/4 (failed on "extra files")

**Bug Found #1**: verify.sh counting plan.md as extra file
- Fix: Added `grep -v '^plan\.md$'` to exclude plan.md

**Bug Found #2**: harness.sh looking for audit.jsonl in wrong path
- Shadow-git creates: `agents/{name}/audit.jsonl`
- Harness was checking: `$RUN_DIR/audit.jsonl`
- Fix: Added loop to check multiple possible paths

**After fixes - CORRECT RESULTS**:
```json
{
  "file_exists": true,
  "content_correct": true,
  "write_tool_calls": 2,
  "bash_tool_calls": 0,
  "used_tools": true,
  "no_extra_files": true,
  "score": 4,
  "max_score": 4,
  "passed": true
}
```

**Audit.jsonl Analysis**:
```
turn 0: read plan.md
turn 1: write hello.txt with "Hello World"
turn 2: read hello.txt (self-verification)
turn 3: completed
```

**Key Findings**:
- MiniMax PASSED task A1 ✅
- Duration: 20 seconds
- Tool usage: Correct (read, write, read)
- No hallucination detected
- Agent verified its own work before completing

**Updated Hypotheses**:
- H1 (hallucination risk): NOT observed on this simple task
- H2 (simple task success): CONFIRMED - MiniMax handles basic file ops

### Post-Execution
**Outcome**: PASS
**Notes**: MiniMax M2.1 successfully completed A1. Harness bugs fixed. Ready for Haiku comparison.
**Belief update**: MiniMax is competent on trivial file creation tasks.

**STEP-03 COMPLETE**

---

## STEP-04: Run Benchmark with Claude Haiku

### Pre-Execution
**Objective**: Run Task A1 with Claude Haiku as baseline comparison
**Target**: benchmark/results/haiku/A1-create-file/run-1/
**Assumptions**:
1. Haiku will complete successfully (it's the baseline)
2. May be faster or slower than MiniMax
3. Harness fixes will work correctly

**Hypotheses**:
1. Haiku will pass 4/4
2. Haiku may complete faster (smaller model, simpler task)
3. Tool usage pattern may differ

**Questions**:
1. How does completion time compare?
2. Does Haiku self-verify like MiniMax did?

### Execution

**DONE**:
1. Ran `./harness.sh A1-create-file haiku 1`
2. Agent completed in 10 seconds
3. Verification: 4/4 PASSED

**Results**:
```json
{
  "file_exists": true,
  "content_correct": true,
  "write_tool_calls": 2,
  "bash_tool_calls": 0,
  "used_tools": true,
  "no_extra_files": true,
  "score": 4,
  "max_score": 4,
  "passed": true
}
```

**Tool Usage Comparison**:
| Turn | MiniMax | Haiku |
|------|---------|-------|
| 0 | read plan.md (abs path) | read plan.md (rel path) |
| 1 | write hello.txt (abs path) | write hello.txt (rel path) |
| 2 | read hello.txt (abs path) | read hello.txt (rel path) |

**Key Observations**:
- Both models used IDENTICAL tool sequence
- Both self-verified their output (read after write)
- Haiku used relative paths, MiniMax used absolute paths
- Haiku was 2x faster (10s vs 20s)

### Post-Execution
**Outcome**: PASS
**Notes**: Haiku baseline established. Both models passed A1.

**Hypothesis Updates**:
- H1 (Haiku pass): CONFIRMED ✓
- H2 (Haiku faster): CONFIRMED (10s vs 20s = 2x faster) ✓
- H3 (different tool pattern): REJECTED (same pattern) ✗

**STEP-04 COMPLETE**

---

## STEP-05: Summary and Comparison

### Pre-Execution
**Objective**: Summarize A1 task results for both models

### Execution

**Task A1: Create File - Results Summary**

| Metric | MiniMax M2.1 | Haiku | 
|--------|--------------|-------|
| Score | 4/4 | 4/4 |
| Passed | ✅ | ✅ |
| Duration | 20s | 10s |
| Tool calls | 3 | 3 |
| Self-verified | Yes | Yes |
| Path style | Absolute | Relative |

**Infrastructure Status**:
- ✅ Harness working correctly
- ✅ Verification script validated
- ✅ Audit trail captured
- ✅ Both models comparable

**Next Steps**:
1. Run more complex tasks (B-category code generation)
2. Run multiple iterations for statistical validity
3. Test failure modes (E-category error recovery)

### Post-Execution
**Outcome**: PASS
**Notes**: End-to-end test successful. Infrastructure validated. Ready for full benchmark.

**STEP-05 COMPLETE**

---


## STEP-06: Add Additional Benchmark Tasks

### Pre-Execution
**Objective**: Create tasks A2, B1, B2, E1 covering file ops, code gen, and error handling
**Target files**:
- tasks/A2-count-lines/
- tasks/B1-fizzbuzz/
- tasks/B2-react-counter/
- tasks/E1-handle-missing-file/

**Assumptions**:
1. Same harness structure will work for all tasks
2. Verification scripts need task-specific logic
3. Code generation tasks need syntax validation

**Hypotheses**:
1. A2 (count lines) - both models should pass
2. B1 (FizzBuzz) - classic test, expect high success
3. B2 (React counter) - more complex, may show differentiation
4. E1 (error handling) - tests robustness, may reveal model differences


### Execution

**DONE - Task Files Created**:
1. A2-count-lines (file ops)
   - plan.md: Read input.txt, count lines, write to output.txt
   - setup.sh: Creates input.txt with 7 lines
   - verify.sh: Checks output.txt == "7"

2. B1-fizzbuzz (code generation)
   - plan.md: Create fizzbuzz.py with fizzbuzz(n) function
   - setup.sh: Clean workspace
   - verify.sh: Checks syntax + runs python + validates output

3. B2-react-counter (complex code)
   - plan.md: Create Counter.jsx with useState, buttons
   - setup.sh: Clean workspace
   - verify.sh: Checks useState, data-testid attrs, export

4. E1-handle-missing-file (error handling)
   - plan.md: Try to read missing file, create error report
   - setup.sh: Ensures data.json does NOT exist
   - verify.sh: Checks report.txt content, validates error handling

**Created batch-runner.sh**:
- Runs all tasks × all models × N iterations
- Collects metrics into summary JSON
- Shows pass rates by model and task

### Post-Execution
**Outcome**: PASS
**Notes**: All task files created. Ready for batch execution.

**STEP-06 COMPLETE**

---

## STEP-07: Execute Full Benchmark (3 runs each)

### Pre-Execution
**Objective**: Run all 5 tasks × 2 models × 3 runs = 30 total runs
**Target**: benchmark/results/batch-summary-*.json

**Assumptions**:
1. Each run takes ~30-60 seconds
2. Total time: ~15-30 minutes
3. MiniMax and Haiku may differ on complex tasks

**Hypotheses**:
1. A1, A2: Both models pass (simple file ops)
2. B1 (FizzBuzz): Both pass (classic task)
3. B2 (React): May see differentiation (more complex)
4. E1 (Error): Tests robustness, may differ


### Execution

**Batch run completed**: 30 runs in ~20 minutes

**Initial Results (with verify.sh bug)**:
- Total: 30 runs
- Passed: 24 (80%)
- Failed: 6 (20%) - ALL were B1-fizzbuzz

**Bug Found**: verify.sh used `timeout` command (not available on macOS)
- Fixed: Removed timeout wrapper, direct python3 execution

**Corrected Results After Fix**:
- Total: 30 runs
- Passed: 30 (100%)
- Failed: 0 (0%)

**Results by Model**:
| Model | Passed | Total | Avg Duration |
|-------|--------|-------|--------------|
| MiniMax | 15/15 | 100% | 22s |
| Haiku | 15/15 | 100% | 14.4s |

**Results by Task**:
| Task | Passed | Total | Notes |
|------|--------|-------|-------|
| A1-create-file | 6/6 | 100% | Simple file creation |
| A2-count-lines | 6/6 | 100% | File ops |
| B1-fizzbuzz | 6/6 | 100% | Python code gen |
| B2-react-counter | 6/6 | 100% | React component |
| E1-handle-missing-file | 6/6 | 100% | Error recovery |

**Key Finding**: Both models achieved 100% success rate on all tasks!

**Speed Comparison**:
- Haiku avg: 14.4s (baseline)
- MiniMax avg: 22s (1.5x slower than Haiku)

### Post-Execution
**Outcome**: PASS
**Notes**: All 30 benchmark runs passed. MiniMax matches Haiku on accuracy, but is ~50% slower.

**STEP-07 COMPLETE**

---

## Summary: MiniMax M2.1 vs Claude Haiku Benchmark

### Final Results (30 runs)

| Metric | MiniMax M2.1 | Claude Haiku |
|--------|--------------|--------------|
| **Pass Rate** | 100% (15/15) | 100% (15/15) |
| **Avg Duration** | 22s | 14.4s |
| **Speed Ratio** | 1.53x slower | 1.0x (baseline) |

### Task Breakdown

| Task | MiniMax | Haiku | Winner |
|------|---------|-------|--------|
| A1-create-file | 3/3 ✅ | 3/3 ✅ | Tie |
| A2-count-lines | 3/3 ✅ | 3/3 ✅ | Tie |
| B1-fizzbuzz | 3/3 ✅ | 3/3 ✅ | Tie |
| B2-react-counter | 3/3 ✅ | 3/3 ✅ | Tie |
| E1-handle-missing-file | 3/3 ✅ | 3/3 ✅ | Tie |

### Conclusions

1. **Accuracy**: MiniMax M2.1 matches Haiku on all tested tasks
2. **Speed**: Haiku is ~50% faster than MiniMax
3. **Reliability**: Both models showed 100% consistency (no flaky failures)
4. **Tool Usage**: Both models correctly use tools (no hallucination observed)

### Recommendations

- **Use MiniMax when**: Cost is primary concern, latency is acceptable
- **Use Haiku when**: Speed is critical, budget allows
- **Both suitable for**: Simple file ops, code generation, error handling


---

## STEP-08: Design Differentiating Tasks

### Pre-Execution
**Objective**: Create harder tasks that reveal capability differences between models

**Why previous tasks didn't differentiate**:
- Too simple (single-step, obvious solution)
- No error compounding (one mistake doesn't cascade)
- No self-correction needed (first attempt works)
- No ambiguity to resolve

**Hypotheses for differentiation**:
1. Multi-step tasks where errors compound
2. Tasks requiring self-correction after failure
3. Tasks with subtle bugs to find
4. Tasks requiring synthesis across multiple sources
5. Algorithm implementation with edge cases


### Execution

**Created 4 Differentiating Tasks**:

1. **C1-debug-the-bug** (5 points)
   - Subtle bug in sliding window algorithm
   - Bug: `window_start = char_index[char] + 1` missing `max()`
   - Fails on "abba" → returns 3 instead of 2
   - Tests: Reading comprehension + reasoning

2. **C3-tdd-implement** (6 points)
   - Implement Stack class from failing tests
   - 8 test cases covering all methods
   - Tests: Understanding test intent + completeness

3. **C4-data-pipeline** (6 points)
   - 5-step pipeline: Filter → Transform → Aggregate → Sort → Output
   - Errors compound across steps
   - Tests: Multi-step reasoning + attention to detail

4. **C7-merge-intervals** (5 points)
   - Classic algorithm problem
   - 8 edge cases including nested, adjacent, unsorted
   - Tests: Algorithm implementation + edge case handling

**Total new tasks**: 4
**Total benchmark tasks**: 9

### Post-Execution
**Outcome**: PASS
**Notes**: All 4 differentiating tasks created and verified. Ready for benchmark run.

**STEP-08 COMPLETE**

---

## STEP-09: Run Differentiating Benchmark

### Pre-Execution
**Objective**: Run C1, C3, C4, C7 × 2 models × 3 runs = 24 runs

**Hypotheses**:
1. C1 (debug): May differentiate - requires understanding bug
2. C3 (TDD): Both likely pass - straightforward implementation
3. C4 (pipeline): May differentiate - errors compound
4. C7 (algorithm): May differentiate - edge cases are tricky


### Execution (CORRECTED)

**Verification Bugs Fixed**:
1. C3: jq error with empty grep results - fixed with tr/defaults
2. C4: Strict decimal matching (405.0 vs 405.00) - fixed with numerical comparison
3. C1: Only accepted max() fix - fixed to accept alternative condition-based fix

**Corrected Results After Bug Fixes**:

| Task | MiniMax | Haiku | Differentiation? |
|------|---------|-------|------------------|
| C1-debug-the-bug | 3/3 ✅ | 3/3 ✅ | NO - Both found bug |
| C3-tdd-implement | 3/3 ✅ | 3/3 ✅ | NO - Both implemented Stack |
| C4-data-pipeline | 3/3 ✅ | 3/3 ✅ | NO - Both correct pipeline |
| C7-merge-intervals | 3/3 ✅ | 3/3 ✅ | NO - Both handled edge cases |

**Speed Comparison**:

| Task | MiniMax Avg | Haiku Avg | Ratio |
|------|-------------|-----------|-------|
| C1-debug-the-bug | ~48s | ~25s | 1.9x slower |
| C3-tdd-implement | ~32s | ~20s | 1.6x slower |
| C4-data-pipeline | ~38s | ~28s | 1.4x slower |
| C7-merge-intervals | ~25s | ~17s | 1.5x slower |

**Key Finding**: Both models achieved 100% accuracy on ALL challenging tasks.
The ONLY differentiation is **speed** - Haiku is consistently 1.4-2x faster.

### Post-Execution
**Outcome**: PASS (with verification fixes)
**Notes**: Verification bugs caused false negatives. After fixes, both models perform equally well on accuracy.

**STEP-09 COMPLETE**


---

## STEP-10: Goedecke Critique

### Pre-Execution
**Objective**: Apply Goedecke's system design principles to critically evaluate the benchmark

### Execution

**Read**: "Everything I Know About Good System Design" by Sean Goedecke

**Key Goedecke Insight**: "State is the entire problem."

**The Fundamental Flaw in My Benchmark**:

My tasks are **stateless**. They test:
```
Input → Model → Output → Correct?
```

Real agentic work is **stateful and path-dependent**:
```
Turn₁ → State₁ → Decision → Turn₂ → State₂ → Decision → ... → Turn_N
```

**Why Both Models Pass Everything**:
- Tasks have single correct answers (convergent)
- No compound state to corrupt
- No failure recovery needed
- No decisions that constrain future decisions

**What Would Actually Differentiate**:

| Current Benchmark | Goedecke-Approved Benchmark |
|-------------------|----------------------------|
| Single-shot tasks | Multi-turn with state |
| Clear right answer | Multiple valid approaches |
| Pass/fail binary | Quality gradient |
| No failure injection | Deliberate failures to recover from |
| Stateless | State accumulation over turns |

**Path Sinks** (what to measure):
1. Complexity attractors - does model add unnecessary cleverness?
2. Failure mode awareness - does model consider "what if X fails?"
3. State consciousness - does model track ownership?
4. Recovery patterns - when stuck, does model adapt or repeat?

### Post-Execution
**Outcome**: PASS (critical insight gained)
**Notes**: Current benchmark is necessary but not sufficient. Need multi-turn stateful tasks.

**STEP-10 COMPLETE**


---

## STEP-11: Create Multi-Turn Path-Divergent Task (D1)

### Pre-Execution
**Objective**: Create D1-incremental-system-design with LLM-as-judge evaluation

### Execution

**Created D1 Task Structure**:
```
tasks/D1-incremental-system-design/
├── plan.md                      # 10-turn incremental requirements
├── setup.sh                     # Workspace setup
├── verify.sh                    # Structural checks
└── judge/
    ├── JUDGE_PROMPT.md          # Single-design evaluation rubric
    ├── COMPARATIVE_JUDGE_PROMPT.md  # A/B comparison rubric
    ├── run-judge.sh             # Single evaluation runner
    └── run-comparative-judge.sh # Comparative evaluation runner
```

**Task Design**:
- 10 turns of incremental requirements
- Turn 4: Inject performance failure (850ms latency)
- Turn 5: Inject rate limiter failure (CI/CD blocked)
- Turn 8: Conflicting requirements (security vs debuggability)
- Turn 9: Scale pressure (10x growth)
- Turn 10: Final summary with tradeoffs

**Evaluation Approach**:
1. **Structural checks** (deterministic):
   - File exists
   - Required sections present
   - All turns addressed
   - Iterative development (multiple writes)

2. **LLM Judge** (qualitative):
   - Boring over clever (20%)
   - State consciousness (20%)
   - Failure mode awareness (20%)
   - Hot path identification (15%)
   - Consistency across turns (15%)
   - Recovery quality (10%)

3. **Comparative Judge** (path analysis):
   - Path divergences at each decision point
   - Complexity attractors
   - State handling patterns
   - Recovery styles
   - Goedecke verdict

### Post-Execution
**Outcome**: PASS
**Notes**: D1 task created. Ready for execution.

**STEP-11 COMPLETE**

