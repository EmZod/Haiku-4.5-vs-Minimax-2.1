# Understanding the Audit Trails

This document explains how to read the execution logs and git traces from the benchmark runs.

## Log Types

### 1. Git Traces (`logs/git-traces/`)
Human-readable summaries of agent actions extracted from shadow-git.

**Files**:
- `minimax-D1-commits.txt` - One-line summary of each action
- `minimax-D1-full.txt` - Full commit messages with file changes
- `haiku-D1-commits.txt` - One-line summary
- `haiku-D1-full.txt` - Full commit messages

**Reading the commits**:
```
3d892a8 [D1-incremental-system-design:turn] turn 8 complete
07f67de [D1-incremental-system-design:tool] write: design.md
```

Format: `[agent:event] description`
- `turn` - A turn completed
- `tool` - A tool was called (read, write, edit, bash)
- `start` - Agent started
- `end` - Agent completed

### 2. Audit JSONL (`results/*/agents/*/audit.jsonl`)
Machine-readable event stream of all agent actions.

**Example**:
```json
{"ts":1768407186930,"event":"session_start","agent":"D1-incremental-system-design","turn":0}
{"ts":1768407192359,"event":"tool_call","agent":"D1","turn":0,"tool":"read","input":{"path":"plan.md"}}
{"ts":1768407192361,"event":"tool_result","agent":"D1","turn":0,"tool":"read","error":false}
```

**Events**:
- `session_start` - Agent initialized
- `turn_start` / `turn_end` - Turn boundaries
- `tool_call` - Tool invoked with inputs
- `tool_result` - Tool returned (with error status)
- `agent_end` - Agent completed

### 3. Run Logs (`results/*/run.log`)
Raw stdout/stderr from the pi CLI execution.

### 4. Orchestration Log (`logs/orchestration-log.md`)
My (the orchestrator's) execution log following the logging protocol.

## Key Insight: D1 Execution Patterns

### MiniMax (30+ commits)
```
[turn 1] read: plan.md → write: design.md
[turn 2] write: design.md
[turn 3] write: design.md
[turn 4] write: design.md  ← Performance fix
[turn 5] write: design.md  ← Rate limiter fix
[turn 6] write: design.md
[turn 7] write: design.md
[turn 8] write: design.md
```

MiniMax **evolved the design iteratively**, writing to design.md after each requirement.

### Haiku (7 commits)
```
[turn 1] read: plan.md
[turn 2] write: design.md  ← Wrote complete design in one pass
```

Haiku **wrote the entire design at once** after reading all requirements.

## Querying the Audit Logs

```bash
# Count tool calls by type
jq -r 'select(.event=="tool_call") | .tool' audit.jsonl | sort | uniq -c

# Find all write operations
jq 'select(.event=="tool_call" and .tool=="write")' audit.jsonl

# Get timeline of events
jq -c '{ts: .ts, event: .event, tool: .tool}' audit.jsonl

# Find errors
jq 'select(.error==true)' audit.jsonl
```

## Exploring the Git History

Each run has a full git repository with the shadow-git audit trail:

```bash
cd results/minimax/D1-incremental-system-design/run-1

# See all commits
git log --oneline

# See what changed in each commit
git log --stat

# See the actual diff for a specific commit
git show <commit-hash>

# See the design at a specific point in time
git show <commit-hash>:workspace/design.md
```

## Reproducing a Run

1. Look at the task definition in `tasks/<task-id>/plan.md`
2. Check the setup script: `tasks/<task-id>/setup.sh`
3. Run with harness: `./harness/harness.sh <task-id> <model> <run>`
4. Results will appear in `results/<model>/<task-id>/run-<n>/`
