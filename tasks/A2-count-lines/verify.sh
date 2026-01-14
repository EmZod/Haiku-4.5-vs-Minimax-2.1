#!/bin/bash
# Verification script for A2-count-lines

set -uo pipefail

WORKSPACE="${1:-workspace}"
AUDIT="${2:-audit.jsonl}"

RESULT='{}'
EXPECTED_COUNT=7

# ============================================================
# METRIC 1: Output File Exists
# ============================================================
if [ -f "$WORKSPACE/output.txt" ]; then
    RESULT=$(echo "$RESULT" | jq '.file_exists = true')
else
    RESULT=$(echo "$RESULT" | jq '.file_exists = false')
fi

# ============================================================
# METRIC 2: Content Correctness
# ============================================================
if [ -f "$WORKSPACE/output.txt" ]; then
    CONTENT=$(cat "$WORKSPACE/output.txt" | tr -d '[:space:]')
    if [ "$CONTENT" = "$EXPECTED_COUNT" ]; then
        RESULT=$(echo "$RESULT" | jq '.content_correct = true')
    else
        RESULT=$(echo "$RESULT" | jq '.content_correct = false')
        RESULT=$(echo "$RESULT" | jq --arg c "$CONTENT" --argjson e "$EXPECTED_COUNT" '.actual = $c | .expected = $e')
    fi
else
    RESULT=$(echo "$RESULT" | jq '.content_correct = false')
fi

# ============================================================
# METRIC 3: Tool Usage
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
# METRIC 4: Input File Preserved
# ============================================================
if [ -f "$WORKSPACE/input.txt" ]; then
    INPUT_LINES=$(wc -l < "$WORKSPACE/input.txt" | tr -d '[:space:]')
    if [ "$INPUT_LINES" = "$EXPECTED_COUNT" ]; then
        RESULT=$(echo "$RESULT" | jq '.input_preserved = true')
    else
        RESULT=$(echo "$RESULT" | jq '.input_preserved = false')
    fi
else
    RESULT=$(echo "$RESULT" | jq '.input_preserved = false')
fi

# ============================================================
# CALCULATE SCORE
# ============================================================
SCORE=0
MAX_SCORE=4

[ "$(echo "$RESULT" | jq -r '.file_exists')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.content_correct')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.used_tools')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.input_preserved')" = "true" ] && ((SCORE++))

RESULT=$(echo "$RESULT" | jq --argjson s "$SCORE" --argjson m "$MAX_SCORE" '.score = $s | .max_score = $m')

if [ "$SCORE" -eq "$MAX_SCORE" ]; then
    RESULT=$(echo "$RESULT" | jq '.passed = true')
else
    RESULT=$(echo "$RESULT" | jq '.passed = false')
fi

echo "$RESULT" | jq .
