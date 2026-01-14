#!/bin/bash
# Batch Runner - Execute all tasks with multiple iterations
# Usage: ./batch-runner.sh [runs_per_task] [tasks...]
# Example: ./batch-runner.sh 3 A1-create-file B1-fizzbuzz

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Configuration
RUNS=${1:-3}
shift || true

# Get tasks (default: all)
if [ $# -gt 0 ]; then
    TASKS=("$@")
else
    TASKS=($(ls -1 tasks/))
fi

MODELS=("minimax" "haiku")

echo "============================================================"
echo "BENCHMARK BATCH RUN"
echo "============================================================"
echo "Tasks:  ${TASKS[*]}"
echo "Models: ${MODELS[*]}"
echo "Runs:   $RUNS per task per model"
echo "Total:  $((${#TASKS[@]} * ${#MODELS[@]} * RUNS)) benchmark runs"
echo "============================================================"
echo ""

# Create summary file
SUMMARY_FILE="results/batch-summary-$(date +%Y%m%d-%H%M%S).json"
echo '{"runs": []}' > "$SUMMARY_FILE"

TOTAL=0
PASSED=0
FAILED=0

for task in "${TASKS[@]}"; do
    for model in "${MODELS[@]}"; do
        for run in $(seq 1 $RUNS); do
            echo ""
            echo ">>> Running: $task | $model | run $run/$RUNS"
            echo "-----------------------------------------------------------"
            
            # Run the benchmark
            if ./harness.sh "$task" "$model" "$run" > /tmp/harness-output.txt 2>&1; then
                HARNESS_EXIT=0
            else
                HARNESS_EXIT=$?
            fi
            
            # Extract results
            RESULT_FILE="results/$model/$task/run-$run/metrics.json"
            if [ -f "$RESULT_FILE" ]; then
                TASK_PASSED=$(jq -r '.passed' "$RESULT_FILE")
                TASK_SCORE=$(jq -r '.score' "$RESULT_FILE")
                TASK_MAX=$(jq -r '.max_score' "$RESULT_FILE")
                TASK_DURATION=$(jq -r '.duration_seconds' "$RESULT_FILE")
                
                if [ "$TASK_PASSED" = "true" ]; then
                    echo "✅ PASSED ($TASK_SCORE/$TASK_MAX) in ${TASK_DURATION}s"
                    ((PASSED++))
                else
                    echo "❌ FAILED ($TASK_SCORE/$TASK_MAX) in ${TASK_DURATION}s"
                    ((FAILED++))
                fi
                
                # Add to summary
                jq --arg t "$task" --arg m "$model" --argjson r "$run" \
                   --argjson p "$([ "$TASK_PASSED" = "true" ] && echo true || echo false)" \
                   --argjson s "$TASK_SCORE" --argjson mx "$TASK_MAX" --argjson d "$TASK_DURATION" \
                   '.runs += [{task: $t, model: $m, run: $r, passed: $p, score: $s, max_score: $mx, duration: $d}]' \
                   "$SUMMARY_FILE" > "$SUMMARY_FILE.tmp" && mv "$SUMMARY_FILE.tmp" "$SUMMARY_FILE"
            else
                echo "⚠️  NO RESULT FILE"
                ((FAILED++))
            fi
            
            ((TOTAL++))
            
            # Small delay between runs
            sleep 2
        done
    done
done

echo ""
echo "============================================================"
echo "BATCH COMPLETE"
echo "============================================================"
echo "Total runs: $TOTAL"
echo "Passed:     $PASSED"
echo "Failed:     $FAILED"
echo "Pass rate:  $(echo "scale=1; $PASSED * 100 / $TOTAL" | bc)%"
echo ""
echo "Summary saved to: $SUMMARY_FILE"
echo ""

# Show summary by model
echo "=== Results by Model ==="
for model in "${MODELS[@]}"; do
    MODEL_PASSED=$(jq "[.runs[] | select(.model == \"$model\") | select(.passed == true)] | length" "$SUMMARY_FILE")
    MODEL_TOTAL=$(jq "[.runs[] | select(.model == \"$model\")] | length" "$SUMMARY_FILE")
    MODEL_AVG_DURATION=$(jq "[.runs[] | select(.model == \"$model\") | .duration] | add / length" "$SUMMARY_FILE")
    echo "$model: $MODEL_PASSED/$MODEL_TOTAL passed, avg ${MODEL_AVG_DURATION}s"
done

echo ""
echo "=== Results by Task ==="
for task in "${TASKS[@]}"; do
    TASK_PASSED=$(jq "[.runs[] | select(.task == \"$task\") | select(.passed == true)] | length" "$SUMMARY_FILE")
    TASK_TOTAL=$(jq "[.runs[] | select(.task == \"$task\")] | length" "$SUMMARY_FILE")
    echo "$task: $TASK_PASSED/$TASK_TOTAL passed"
done
