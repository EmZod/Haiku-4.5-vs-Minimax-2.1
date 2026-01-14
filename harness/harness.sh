#!/bin/bash
# Benchmark Harness for MiniMax vs Haiku Evaluation
# Usage: ./harness.sh <task_id> <model> [run_number]
# Example: ./harness.sh A1-create-file minimax 1

set -uo pipefail

# ============================================================
# CONFIGURATION
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BENCHMARK_DIR="$SCRIPT_DIR"
TASKS_DIR="$BENCHMARK_DIR/tasks"
RESULTS_DIR="$BENCHMARK_DIR/results"
MAX_TURNS=30
TIMEOUT_SECONDS=300

# Shadow git hook (optional)
HOOK="/Users/jay/Documents/Broad Building/daily_workspaces/jan5/shadow-git-hook/src/shadow-git.ts"

# ============================================================
# ARGUMENTS
# ============================================================
TASK_ID="${1:-}"
MODEL="${2:-}"
RUN_NUM="${3:-1}"

if [ -z "$TASK_ID" ] || [ -z "$MODEL" ]; then
    echo "Usage: $0 <task_id> <model> [run_number]"
    echo "  task_id: e.g., A1-create-file"
    echo "  model: minimax or haiku"
    echo "  run_number: 1-5 (default: 1)"
    exit 1
fi

TASK_DIR="$TASKS_DIR/$TASK_ID"
if [ ! -d "$TASK_DIR" ]; then
    echo "ERROR: Task not found: $TASK_DIR"
    exit 1
fi

# ============================================================
# MODEL CONFIGURATION
# ============================================================
set_model() {
    local model="$1"
    case "$model" in
        minimax)
            cat > ~/.pi/agent/settings.json << 'EOF'
{
  "defaultProvider": "minimax",
  "defaultModel": "MiniMax-M2.1",
  "defaultThinkingLevel": "none"
}
EOF
            ;;
        haiku)
            cat > ~/.pi/agent/settings.json << 'EOF'
{
  "defaultProvider": "anthropic",
  "defaultModel": "claude-haiku-4-5",
  "defaultThinkingLevel": "none"
}
EOF
            ;;
        *)
            echo "ERROR: Unknown model: $model (use 'minimax' or 'haiku')"
            exit 1
            ;;
    esac
    echo "Model set to: $(jq -r '.defaultModel' ~/.pi/agent/settings.json)"
}

# ============================================================
# SETUP RUN DIRECTORY
# ============================================================
RUN_DIR="$RESULTS_DIR/$MODEL/$TASK_ID/run-$RUN_NUM"
mkdir -p "$RUN_DIR/workspace"

echo "============================================================"
echo "BENCHMARK RUN"
echo "============================================================"
echo "Task:     $TASK_ID"
echo "Model:    $MODEL"
echo "Run:      $RUN_NUM"
echo "Dir:      $RUN_DIR"
echo "============================================================"

# Initialize git for shadow-git (if not exists)
cd "$RUN_DIR"
if [ ! -d .git ]; then
    git init -q
    git commit --allow-empty -m "Initialize benchmark run" -q
fi

# Copy plan.md to workspace
cp "$TASK_DIR/plan.md" "$RUN_DIR/workspace/"

# Run setup script if exists
if [ -f "$TASK_DIR/setup.sh" ]; then
    echo "Running setup..."
    (cd "$RUN_DIR/workspace" && bash "$TASK_DIR/setup.sh")
fi

# ============================================================
# SET MODEL
# ============================================================
set_model "$MODEL"

# ============================================================
# RUN AGENT
# ============================================================
echo ""
echo "Starting agent..."
START_TIME=$(date +%s)

# Generate unique session name
SESSION="bench-${MODEL}-${TASK_ID}-run${RUN_NUM}-$$"

# Spawn agent with tmux for observability
tmux new-session -d -s "$SESSION" \
    "cd '$RUN_DIR/workspace' && \
     PI_WORKSPACE_ROOT='$RUN_DIR' \
     PI_AGENT_NAME='$TASK_ID' \
     pi --print --max-turns $MAX_TURNS \
        'Read plan.md and execute the task. Create the required files.' \
        2>&1 | tee '../run.log'"

echo "Agent spawned in tmux session: $SESSION"
echo "Waiting for completion (timeout: ${TIMEOUT_SECONDS}s)..."

# Wait for completion with timeout
ELAPSED=0
while tmux has-session -t "$SESSION" 2>/dev/null; do
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    
    if [ $ELAPSED -ge $TIMEOUT_SECONDS ]; then
        echo "TIMEOUT: Killing agent after ${TIMEOUT_SECONDS}s"
        tmux kill-session -t "$SESSION" 2>/dev/null
        break
    fi
    
    # Progress indicator
    printf "."
done
echo ""

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "Agent completed in ${DURATION}s"

# Small delay for file sync
sleep 2

# ============================================================
# VERIFICATION
# ============================================================
echo ""
echo "Running verification..."

# Check for audit.jsonl (shadow-git creates it at agents/{name}/audit.jsonl)
AUDIT_FILE=""
for possible in \
    "$RUN_DIR/agents/$TASK_ID/audit.jsonl" \
    "$RUN_DIR/audit.jsonl" \
    "$RUN_DIR/workspace/audit.jsonl"; do
    if [ -f "$possible" ]; then
        AUDIT_FILE="$possible"
        echo "Found audit at: $AUDIT_FILE"
        break
    fi
done

if [ -z "$AUDIT_FILE" ]; then
    echo "WARNING: No audit.jsonl found - tool usage verification will be skipped"
fi

# Run verification script
chmod +x "$TASK_DIR/verify.sh"
METRICS=$("$TASK_DIR/verify.sh" "$RUN_DIR/workspace" "$AUDIT_FILE")

# Add timing metadata
METRICS=$(echo "$METRICS" | jq \
    --arg task "$TASK_ID" \
    --arg model "$MODEL" \
    --argjson run "$RUN_NUM" \
    --argjson duration "$DURATION" \
    --arg timestamp "$(date -Iseconds)" \
    '. + {task: $task, model: $model, run: $run, duration_seconds: $duration, timestamp: $timestamp}')

# Save metrics
echo "$METRICS" | jq . > "$RUN_DIR/metrics.json"

# ============================================================
# REPORT
# ============================================================
echo ""
echo "============================================================"
echo "RESULTS"
echo "============================================================"
echo "$METRICS" | jq .

PASSED=$(echo "$METRICS" | jq -r '.passed')
SCORE=$(echo "$METRICS" | jq -r '.score')
MAX=$(echo "$METRICS" | jq -r '.max_score')

echo ""
if [ "$PASSED" = "true" ]; then
    echo "✅ PASSED ($SCORE/$MAX)"
else
    echo "❌ FAILED ($SCORE/$MAX)"
fi

echo ""
echo "Results saved to: $RUN_DIR/metrics.json"
echo "Run log at: $RUN_DIR/run.log"
echo "Workspace at: $RUN_DIR/workspace/"
