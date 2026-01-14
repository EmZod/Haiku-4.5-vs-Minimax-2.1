#!/bin/bash
# Verification script for C7-merge-intervals

set -uo pipefail

WORKSPACE="${1:-workspace}"
AUDIT="${2:-audit.jsonl}"

RESULT='{}'

# ============================================================
# METRIC 1: File Exists
# ============================================================
if [ -f "$WORKSPACE/intervals.py" ]; then
    RESULT=$(echo "$RESULT" | jq '.file_exists = true')
else
    RESULT=$(echo "$RESULT" | jq '.file_exists = false')
fi

# ============================================================
# METRIC 2: Valid Python Syntax
# ============================================================
if [ -f "$WORKSPACE/intervals.py" ]; then
    if python3 -m py_compile "$WORKSPACE/intervals.py" 2>/dev/null; then
        RESULT=$(echo "$RESULT" | jq '.valid_syntax = true')
    else
        RESULT=$(echo "$RESULT" | jq '.valid_syntax = false')
    fi
else
    RESULT=$(echo "$RESULT" | jq '.valid_syntax = false')
fi

# ============================================================
# METRIC 3: Has merge_intervals Function
# ============================================================
if [ -f "$WORKSPACE/intervals.py" ]; then
    if grep -q "def merge_intervals" "$WORKSPACE/intervals.py"; then
        RESULT=$(echo "$RESULT" | jq '.has_function = true')
    else
        RESULT=$(echo "$RESULT" | jq '.has_function = false')
    fi
else
    RESULT=$(echo "$RESULT" | jq '.has_function = false')
fi

# ============================================================
# METRIC 4: All Test Cases Pass
# ============================================================
if [ -f "$WORKSPACE/intervals.py" ]; then
    # Create test runner
    cat > "$WORKSPACE/test_intervals.py" << 'PYTEST'
import sys
sys.path.insert(0, '.')
from intervals import merge_intervals

test_cases = [
    # (input, expected, description)
    ([], [], "empty input"),
    ([[1,3]], [[1,3]], "single interval"),
    ([[1,3],[2,6],[8,10],[15,18]], [[1,6],[8,10],[15,18]], "basic merge"),
    ([[1,4],[4,5]], [[1,5]], "adjacent intervals"),
    ([[1,4],[0,4]], [[0,4]], "overlapping with earlier start"),
    ([[1,4],[2,3]], [[1,4]], "nested interval"),
    ([[2,3],[4,5],[6,7],[8,9],[1,10]], [[1,10]], "one covers all"),
    ([[1,4],[0,2],[3,5]], [[0,5]], "three-way merge"),
]

passed = 0
failed = 0
failures = []

for input_val, expected, desc in test_cases:
    try:
        result = merge_intervals(input_val)
        # Sort both for comparison
        result_sorted = sorted([sorted(x) for x in result])
        expected_sorted = sorted([sorted(x) for x in expected])
        
        if result_sorted == expected_sorted:
            passed += 1
        else:
            failed += 1
            failures.append(f"{desc}: expected {expected}, got {result}")
    except Exception as e:
        failed += 1
        failures.append(f"{desc}: exception {e}")

print(f"PASSED: {passed}")
print(f"FAILED: {failed}")
for f in failures:
    print(f"  - {f}")

sys.exit(0 if failed == 0 else 1)
PYTEST

    # Run tests
    cd "$WORKSPACE"
    TEST_OUTPUT=$(python3 test_intervals.py 2>&1)
    TEST_EXIT=$?
    cd - > /dev/null
    
    PASSED_COUNT=$(echo "$TEST_OUTPUT" | grep "PASSED:" | awk '{print $2}')
    FAILED_COUNT=$(echo "$TEST_OUTPUT" | grep "FAILED:" | awk '{print $2}')
    
    PASSED_COUNT=${PASSED_COUNT:-0}
    FAILED_COUNT=${FAILED_COUNT:-0}
    
    RESULT=$(echo "$RESULT" | jq --argjson p "$PASSED_COUNT" --argjson f "$FAILED_COUNT" \
        '.tests_passed = $p | .tests_failed = $f')
    
    if [ "$TEST_EXIT" -eq 0 ]; then
        RESULT=$(echo "$RESULT" | jq '.all_tests_pass = true')
    else
        RESULT=$(echo "$RESULT" | jq '.all_tests_pass = false')
        # Capture failure details
        FAILURES=$(echo "$TEST_OUTPUT" | grep "^  -" | head -5)
        RESULT=$(echo "$RESULT" | jq --arg f "$FAILURES" '.failure_details = $f')
    fi
    
    # Cleanup
    rm -f "$WORKSPACE/test_intervals.py"
else
    RESULT=$(echo "$RESULT" | jq '.all_tests_pass = false | .tests_passed = 0')
fi

# ============================================================
# METRIC 5: Tool Usage
# ============================================================
if [ -f "$AUDIT" ]; then
    READ_CALLS=$(grep -c '"tool":"[Rr]ead"' "$AUDIT" 2>/dev/null | tr -d '[:space:]' || echo "0")
    WRITE_CALLS=$(grep -c '"tool":"[Ww]rite"' "$AUDIT" 2>/dev/null | tr -d '[:space:]' || echo "0")
    BASH_CALLS=$(grep -c '"tool":"[Bb]ash"' "$AUDIT" 2>/dev/null | tr -d '[:space:]' || echo "0")
    
    READ_CALLS=${READ_CALLS:-0}
    WRITE_CALLS=${WRITE_CALLS:-0}
    BASH_CALLS=${BASH_CALLS:-0}
    
    TOTAL=$((READ_CALLS + WRITE_CALLS + BASH_CALLS))
    
    RESULT=$(echo "$RESULT" | jq --argjson r "$READ_CALLS" --argjson w "$WRITE_CALLS" --argjson b "$BASH_CALLS" \
        '.read_calls = $r | .write_calls = $w | .bash_calls = $b')
    
    if [ "$TOTAL" -gt 0 ]; then
        RESULT=$(echo "$RESULT" | jq '.used_tools = true')
    else
        RESULT=$(echo "$RESULT" | jq '.used_tools = false')
    fi
else
    RESULT=$(echo "$RESULT" | jq '.used_tools = null | .audit_missing = true')
fi

# ============================================================
# CALCULATE SCORE
# ============================================================
SCORE=0
MAX_SCORE=5

[ "$(echo "$RESULT" | jq -r '.file_exists')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.valid_syntax')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.has_function')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.all_tests_pass')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.used_tools')" = "true" ] && ((SCORE++))

RESULT=$(echo "$RESULT" | jq --argjson s "$SCORE" --argjson m "$MAX_SCORE" '.score = $s | .max_score = $m')

if [ "$SCORE" -eq "$MAX_SCORE" ]; then
    RESULT=$(echo "$RESULT" | jq '.passed = true')
else
    RESULT=$(echo "$RESULT" | jq '.passed = false')
fi

echo "$RESULT" | jq .
