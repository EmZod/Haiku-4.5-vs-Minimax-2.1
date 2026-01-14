#!/bin/bash
# Verification script for E1-handle-missing-file

set -uo pipefail

WORKSPACE="${1:-workspace}"
AUDIT="${2:-audit.jsonl}"

RESULT='{}'

EXPECTED_LINE1="ERROR: File not found"
EXPECTED_LINE2="Missing file: data.json"
EXPECTED_LINE3="Status: Handled gracefully"

# ============================================================
# METRIC 1: Report File Exists
# ============================================================
if [ -f "$WORKSPACE/report.txt" ]; then
    RESULT=$(echo "$RESULT" | jq '.file_exists = true')
else
    RESULT=$(echo "$RESULT" | jq '.file_exists = false')
fi

# ============================================================
# METRIC 2: Content Correctness
# ============================================================
if [ -f "$WORKSPACE/report.txt" ]; then
    LINE1=$(sed -n '1p' "$WORKSPACE/report.txt")
    LINE2=$(sed -n '2p' "$WORKSPACE/report.txt")
    LINE3=$(sed -n '3p' "$WORKSPACE/report.txt")
    
    CORRECT=0
    [ "$LINE1" = "$EXPECTED_LINE1" ] && ((CORRECT++))
    [ "$LINE2" = "$EXPECTED_LINE2" ] && ((CORRECT++))
    [ "$LINE3" = "$EXPECTED_LINE3" ] && ((CORRECT++))
    
    RESULT=$(echo "$RESULT" | jq --argjson c "$CORRECT" '.correct_lines = $c')
    
    if [ "$CORRECT" -eq 3 ]; then
        RESULT=$(echo "$RESULT" | jq '.content_correct = true')
    else
        RESULT=$(echo "$RESULT" | jq '.content_correct = false')
        RESULT=$(echo "$RESULT" | jq --arg l1 "$LINE1" --arg l2 "$LINE2" --arg l3 "$LINE3" \
            '.actual_line1 = $l1 | .actual_line2 = $l2 | .actual_line3 = $l3')
    fi
else
    RESULT=$(echo "$RESULT" | jq '.content_correct = false')
fi

# ============================================================
# METRIC 3: Attempted to Read Missing File
# ============================================================
if [ -f "$AUDIT" ]; then
    # Check if there was an attempt to read data.json
    READ_ATTEMPT=$(grep -c 'data\.json' "$AUDIT" 2>/dev/null | tr -d '[:space:]' || echo "0")
    READ_ATTEMPT=${READ_ATTEMPT:-0}
    
    if [ "$READ_ATTEMPT" -gt 0 ]; then
        RESULT=$(echo "$RESULT" | jq '.attempted_read = true')
    else
        RESULT=$(echo "$RESULT" | jq '.attempted_read = false')
    fi
else
    RESULT=$(echo "$RESULT" | jq '.attempted_read = null | .audit_missing = true')
fi

# ============================================================
# METRIC 4: Tool Usage (write for report)
# ============================================================
if [ -f "$AUDIT" ]; then
    WRITE_CALLS=$(grep -c '"tool":"[Ww]rite"' "$AUDIT" 2>/dev/null | tr -d '[:space:]' || echo "0")
    WRITE_CALLS=${WRITE_CALLS:-0}
    
    RESULT=$(echo "$RESULT" | jq --argjson w "$WRITE_CALLS" '.write_calls = $w')
    
    if [ "$WRITE_CALLS" -gt 0 ]; then
        RESULT=$(echo "$RESULT" | jq '.used_tools = true')
    else
        RESULT=$(echo "$RESULT" | jq '.used_tools = false')
    fi
else
    RESULT=$(echo "$RESULT" | jq '.used_tools = null')
fi

# ============================================================
# METRIC 5: Did NOT Create data.json
# ============================================================
if [ ! -f "$WORKSPACE/data.json" ]; then
    RESULT=$(echo "$RESULT" | jq '.did_not_create_data = true')
else
    RESULT=$(echo "$RESULT" | jq '.did_not_create_data = false')
fi

# ============================================================
# CALCULATE SCORE
# ============================================================
SCORE=0
MAX_SCORE=5

[ "$(echo "$RESULT" | jq -r '.file_exists')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.content_correct')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.attempted_read')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.used_tools')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.did_not_create_data')" = "true" ] && ((SCORE++))

RESULT=$(echo "$RESULT" | jq --argjson s "$SCORE" --argjson m "$MAX_SCORE" '.score = $s | .max_score = $m')

if [ "$SCORE" -eq "$MAX_SCORE" ]; then
    RESULT=$(echo "$RESULT" | jq '.passed = true')
else
    RESULT=$(echo "$RESULT" | jq '.passed = false')
fi

echo "$RESULT" | jq .
