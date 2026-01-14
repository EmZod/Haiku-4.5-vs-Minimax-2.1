#!/bin/bash
# Verification script for C3-tdd-implement

set -uo pipefail

WORKSPACE="${1:-workspace}"
AUDIT="${2:-audit.jsonl}"

RESULT='{}'

# ============================================================
# METRIC 1: Solution File Exists
# ============================================================
if [ -f "$WORKSPACE/solution.py" ]; then
    RESULT=$(echo "$RESULT" | jq '.file_exists = true')
else
    RESULT=$(echo "$RESULT" | jq '.file_exists = false')
fi

# ============================================================
# METRIC 2: Valid Python Syntax
# ============================================================
if [ -f "$WORKSPACE/solution.py" ]; then
    if python3 -m py_compile "$WORKSPACE/solution.py" 2>/dev/null; then
        RESULT=$(echo "$RESULT" | jq '.valid_syntax = true')
    else
        RESULT=$(echo "$RESULT" | jq '.valid_syntax = false')
    fi
else
    RESULT=$(echo "$RESULT" | jq '.valid_syntax = false')
fi

# ============================================================
# METRIC 3: Stack Class Exists
# ============================================================
if [ -f "$WORKSPACE/solution.py" ]; then
    if grep -q "class Stack" "$WORKSPACE/solution.py"; then
        RESULT=$(echo "$RESULT" | jq '.has_stack_class = true')
    else
        RESULT=$(echo "$RESULT" | jq '.has_stack_class = false')
    fi
else
    RESULT=$(echo "$RESULT" | jq '.has_stack_class = false')
fi

# ============================================================
# METRIC 4: All Tests Pass
# ============================================================
if [ -f "$WORKSPACE/solution.py" ] && [ -f "$WORKSPACE/test_solution.py" ]; then
    cd "$WORKSPACE"
    
    # Run tests and capture output
    TEST_OUTPUT=$(python3 -m unittest test_solution -v 2>&1) || true
    
    # Count passed/failed
    PASSED=$(echo "$TEST_OUTPUT" | grep -c "\.\.\..*ok$" 2>/dev/null || echo "0")
    FAILED=$(echo "$TEST_OUTPUT" | grep -c "\.\.\..*FAIL$\|\.\.\..*ERROR$" 2>/dev/null || echo "0")
    
    # Ensure we have valid integers
    PASSED=$(echo "$PASSED" | tr -d '[:space:]')
    FAILED=$(echo "$FAILED" | tr -d '[:space:]')
    PASSED=${PASSED:-0}
    FAILED=${FAILED:-0}
    
    # Check overall result
    if echo "$TEST_OUTPUT" | grep -q "^OK"; then
        ALL_PASSED=true
    else
        ALL_PASSED=false
    fi
    
    cd - > /dev/null
    
    RESULT=$(echo "$RESULT" | jq --argjson p "$PASSED" --argjson f "$FAILED" \
        '.tests_passed = $p | .tests_failed = $f')
    
    if [ "$ALL_PASSED" = "true" ]; then
        RESULT=$(echo "$RESULT" | jq '.all_tests_pass = true')
    else
        RESULT=$(echo "$RESULT" | jq '.all_tests_pass = false')
        # Get failure summary
        SUMMARY=$(echo "$TEST_OUTPUT" | tail -5)
        RESULT=$(echo "$RESULT" | jq --arg s "$SUMMARY" '.test_summary = $s')
    fi
else
    RESULT=$(echo "$RESULT" | jq '.all_tests_pass = false | .tests_passed = 0')
fi

# ============================================================
# METRIC 5: Has Required Methods
# ============================================================
if [ -f "$WORKSPACE/solution.py" ]; then
    HAS_PUSH=$(grep -c "def push" "$WORKSPACE/solution.py" || echo "0")
    HAS_POP=$(grep -c "def pop" "$WORKSPACE/solution.py" || echo "0")
    HAS_PEEK=$(grep -c "def peek" "$WORKSPACE/solution.py" || echo "0")
    HAS_IS_EMPTY=$(grep -c "def is_empty" "$WORKSPACE/solution.py" || echo "0")
    HAS_SIZE=$(grep -c "def size" "$WORKSPACE/solution.py" || echo "0")
    
    METHODS_COUNT=$((HAS_PUSH + HAS_POP + HAS_PEEK + HAS_IS_EMPTY + HAS_SIZE))
    
    RESULT=$(echo "$RESULT" | jq --argjson m "$METHODS_COUNT" '.methods_implemented = $m')
    
    if [ "$METHODS_COUNT" -ge 5 ]; then
        RESULT=$(echo "$RESULT" | jq '.has_all_methods = true')
    else
        RESULT=$(echo "$RESULT" | jq '.has_all_methods = false')
    fi
else
    RESULT=$(echo "$RESULT" | jq '.has_all_methods = false')
fi

# ============================================================
# METRIC 6: Tool Usage
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
MAX_SCORE=6

[ "$(echo "$RESULT" | jq -r '.file_exists')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.valid_syntax')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.has_stack_class')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.has_all_methods')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.all_tests_pass')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.used_tools')" = "true" ] && ((SCORE++))

RESULT=$(echo "$RESULT" | jq --argjson s "$SCORE" --argjson m "$MAX_SCORE" '.score = $s | .max_score = $m')

if [ "$SCORE" -eq "$MAX_SCORE" ]; then
    RESULT=$(echo "$RESULT" | jq '.passed = true')
else
    RESULT=$(echo "$RESULT" | jq '.passed = false')
fi

echo "$RESULT" | jq .
