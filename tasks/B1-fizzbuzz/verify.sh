#!/bin/bash
# Verification script for B1-fizzbuzz

set -uo pipefail

WORKSPACE="${1:-workspace}"
AUDIT="${2:-audit.jsonl}"

RESULT='{}'
EXPECTED="['1', '2', 'Fizz', '4', 'Buzz', 'Fizz', '7', '8', 'Fizz', 'Buzz', '11', 'Fizz', '13', '14', 'FizzBuzz']"

# ============================================================
# METRIC 1: File Exists
# ============================================================
if [ -f "$WORKSPACE/fizzbuzz.py" ]; then
    RESULT=$(echo "$RESULT" | jq '.file_exists = true')
else
    RESULT=$(echo "$RESULT" | jq '.file_exists = false')
fi

# ============================================================
# METRIC 2: Valid Python Syntax
# ============================================================
if [ -f "$WORKSPACE/fizzbuzz.py" ]; then
    if python3 -m py_compile "$WORKSPACE/fizzbuzz.py" 2>/dev/null; then
        RESULT=$(echo "$RESULT" | jq '.valid_syntax = true')
    else
        RESULT=$(echo "$RESULT" | jq '.valid_syntax = false')
        ERR=$(python3 -m py_compile "$WORKSPACE/fizzbuzz.py" 2>&1 | head -3)
        RESULT=$(echo "$RESULT" | jq --arg e "$ERR" '.syntax_error = $e')
    fi
else
    RESULT=$(echo "$RESULT" | jq '.valid_syntax = false')
fi

# ============================================================
# METRIC 3: Correct Output
# ============================================================
if [ -f "$WORKSPACE/fizzbuzz.py" ]; then
    # Run the script and capture output
    cd "$WORKSPACE"
    OUTPUT=$(python3 fizzbuzz.py 2>&1) || OUTPUT="ERROR: $?"
    cd - > /dev/null
    
    # Normalize whitespace for comparison
    OUTPUT_CLEAN=$(echo "$OUTPUT" | tr -d '[:space:]')
    EXPECTED_CLEAN=$(echo "$EXPECTED" | tr -d '[:space:]')
    
    if [ "$OUTPUT_CLEAN" = "$EXPECTED_CLEAN" ]; then
        RESULT=$(echo "$RESULT" | jq '.output_correct = true')
    else
        RESULT=$(echo "$RESULT" | jq '.output_correct = false')
        # Store first 200 chars of actual output
        ACTUAL_SHORT=$(echo "$OUTPUT" | head -c 200)
        RESULT=$(echo "$RESULT" | jq --arg a "$ACTUAL_SHORT" '.actual_output = $a')
    fi
else
    RESULT=$(echo "$RESULT" | jq '.output_correct = false')
fi

# ============================================================
# METRIC 4: Tool Usage
# ============================================================
if [ -f "$AUDIT" ]; then
    WRITE_CALLS=$(grep -c '"tool":"[Ww]rite"' "$AUDIT" 2>/dev/null | tr -d '[:space:]' || echo "0")
    BASH_CALLS=$(grep -c '"tool":"[Bb]ash"' "$AUDIT" 2>/dev/null | tr -d '[:space:]' || echo "0")
    
    WRITE_CALLS=${WRITE_CALLS:-0}
    BASH_CALLS=${BASH_CALLS:-0}
    TOTAL=$((WRITE_CALLS + BASH_CALLS))
    
    RESULT=$(echo "$RESULT" | jq --argjson w "$WRITE_CALLS" --argjson b "$BASH_CALLS" \
        '.write_calls = $w | .bash_calls = $b')
    
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
MAX_SCORE=4

[ "$(echo "$RESULT" | jq -r '.file_exists')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.valid_syntax')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.output_correct')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.used_tools')" = "true" ] && ((SCORE++))

RESULT=$(echo "$RESULT" | jq --argjson s "$SCORE" --argjson m "$MAX_SCORE" '.score = $s | .max_score = $m')

if [ "$SCORE" -eq "$MAX_SCORE" ]; then
    RESULT=$(echo "$RESULT" | jq '.passed = true')
else
    RESULT=$(echo "$RESULT" | jq '.passed = false')
fi

echo "$RESULT" | jq .
