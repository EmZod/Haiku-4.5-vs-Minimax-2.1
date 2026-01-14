#!/bin/bash
# Verification script for C1-debug-the-bug

set -uo pipefail

WORKSPACE="${1:-workspace}"
AUDIT="${2:-audit.jsonl}"

RESULT='{}'

# ============================================================
# METRIC 1: File Exists
# ============================================================
if [ -f "$WORKSPACE/buggy.py" ]; then
    RESULT=$(echo "$RESULT" | jq '.file_exists = true')
else
    RESULT=$(echo "$RESULT" | jq '.file_exists = false')
fi

# ============================================================
# METRIC 2: Valid Python Syntax
# ============================================================
if [ -f "$WORKSPACE/buggy.py" ]; then
    if python3 -m py_compile "$WORKSPACE/buggy.py" 2>/dev/null; then
        RESULT=$(echo "$RESULT" | jq '.valid_syntax = true')
    else
        RESULT=$(echo "$RESULT" | jq '.valid_syntax = false')
    fi
else
    RESULT=$(echo "$RESULT" | jq '.valid_syntax = false')
fi

# ============================================================
# METRIC 3: Test Cases Pass
# ============================================================
if [ -f "$WORKSPACE/buggy.py" ]; then
    # Create test runner
    cat > "$WORKSPACE/test_runner.py" << 'PYTEST'
import sys
sys.path.insert(0, '.')
from buggy import longest_unique_substring

test_cases = [
    ("", 0),
    ("a", 1),
    ("abcabcbb", 3),
    ("bbbbb", 1),
    ("pwwkew", 3),
    ("abba", 2),  # This is the tricky case that exposes the bug
]

passed = 0
failed = 0
failures = []

for input_str, expected in test_cases:
    try:
        result = longest_unique_substring(input_str)
        if result == expected:
            passed += 1
        else:
            failed += 1
            failures.append(f"'{input_str}': expected {expected}, got {result}")
    except Exception as e:
        failed += 1
        failures.append(f"'{input_str}': exception {e}")

print(f"PASSED: {passed}")
print(f"FAILED: {failed}")
for f in failures:
    print(f"  - {f}")

sys.exit(0 if failed == 0 else 1)
PYTEST

    # Run tests
    cd "$WORKSPACE"
    TEST_OUTPUT=$(python3 test_runner.py 2>&1)
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
    rm -f "$WORKSPACE/test_runner.py"
else
    RESULT=$(echo "$RESULT" | jq '.all_tests_pass = false')
fi

# ============================================================
# METRIC 4: Bug Was Actually Fixed (check for valid fix patterns)
# ============================================================
if [ -f "$WORKSPACE/buggy.py" ]; then
    # Valid fixes:
    # 1. Using max(): window_start = max(window_start, char_index[char] + 1)
    # 2. Using condition: if char in char_index and char_index[char] >= window_start:
    if grep -q "max.*window_start" "$WORKSPACE/buggy.py" || \
       grep -q "window_start.*max" "$WORKSPACE/buggy.py" || \
       grep -q "char_index\[char\].*>=.*window_start" "$WORKSPACE/buggy.py" || \
       grep -q "window_start.*<=.*char_index" "$WORKSPACE/buggy.py"; then
        RESULT=$(echo "$RESULT" | jq '.correct_fix_pattern = true')
    else
        RESULT=$(echo "$RESULT" | jq '.correct_fix_pattern = false')
    fi
else
    RESULT=$(echo "$RESULT" | jq '.correct_fix_pattern = false')
fi

# ============================================================
# METRIC 5: Tool Usage
# ============================================================
if [ -f "$AUDIT" ]; then
    READ_CALLS=$(grep -c '"tool":"[Rr]ead"' "$AUDIT" 2>/dev/null | tr -d '[:space:]' || echo "0")
    EDIT_CALLS=$(grep -c '"tool":"[Ee]dit"' "$AUDIT" 2>/dev/null | tr -d '[:space:]' || echo "0")
    WRITE_CALLS=$(grep -c '"tool":"[Ww]rite"' "$AUDIT" 2>/dev/null | tr -d '[:space:]' || echo "0")
    BASH_CALLS=$(grep -c '"tool":"[Bb]ash"' "$AUDIT" 2>/dev/null | tr -d '[:space:]' || echo "0")
    
    READ_CALLS=${READ_CALLS:-0}
    EDIT_CALLS=${EDIT_CALLS:-0}
    WRITE_CALLS=${WRITE_CALLS:-0}
    BASH_CALLS=${BASH_CALLS:-0}
    
    RESULT=$(echo "$RESULT" | jq --argjson r "$READ_CALLS" --argjson e "$EDIT_CALLS" \
        --argjson w "$WRITE_CALLS" --argjson b "$BASH_CALLS" \
        '.read_calls = $r | .edit_calls = $e | .write_calls = $w | .bash_calls = $b')
    
    TOTAL=$((READ_CALLS + EDIT_CALLS + WRITE_CALLS + BASH_CALLS))
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
[ "$(echo "$RESULT" | jq -r '.all_tests_pass')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.correct_fix_pattern')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.used_tools')" = "true" ] && ((SCORE++))

RESULT=$(echo "$RESULT" | jq --argjson s "$SCORE" --argjson m "$MAX_SCORE" '.score = $s | .max_score = $m')

if [ "$SCORE" -eq "$MAX_SCORE" ]; then
    RESULT=$(echo "$RESULT" | jq '.passed = true')
else
    RESULT=$(echo "$RESULT" | jq '.passed = false')
fi

echo "$RESULT" | jq .
