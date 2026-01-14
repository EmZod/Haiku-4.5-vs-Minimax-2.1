#!/bin/bash
# Verification script for A1-create-file
# Called after agent completes, in the run directory
# Outputs JSON metrics to stdout

set -uo pipefail

WORKSPACE="${1:-workspace}"
AUDIT="${2:-audit.jsonl}"

# Initialize result
RESULT='{}'

# ============================================================
# METRIC 1: File Existence (tool-verified)
# ============================================================
if [ -f "$WORKSPACE/hello.txt" ]; then
    RESULT=$(echo "$RESULT" | jq '.file_exists = true')
else
    RESULT=$(echo "$RESULT" | jq '.file_exists = false')
fi

# ============================================================
# METRIC 2: Content Correctness
# ============================================================
if [ -f "$WORKSPACE/hello.txt" ]; then
    CONTENT=$(cat "$WORKSPACE/hello.txt")
    # Check if content contains "Hello World" (allowing trailing newline)
    if [[ "$CONTENT" == "Hello World" ]] || [[ "$CONTENT" == "Hello World"$'\n' ]]; then
        RESULT=$(echo "$RESULT" | jq '.content_correct = true')
    else
        RESULT=$(echo "$RESULT" | jq '.content_correct = false')
        # Store actual content for debugging (escaped)
        ESCAPED=$(echo "$CONTENT" | jq -Rs '.')
        RESULT=$(echo "$RESULT" | jq --argjson c "$ESCAPED" '.actual_content = $c')
    fi
else
    RESULT=$(echo "$RESULT" | jq '.content_correct = false')
fi

# ============================================================
# METRIC 3: Tool Usage (anti-hallucination check)
# ============================================================
if [ -f "$AUDIT" ]; then
    # Check if agent actually used write or bash tool
    # Use grep -c and ensure we get a clean integer
    WRITE_CALLS=$(grep -c '"tool":"[Ww]rite"' "$AUDIT" 2>/dev/null | tr -d '[:space:]' || echo "0")
    BASH_CALLS=$(grep -c '"tool":"[Bb]ash"' "$AUDIT" 2>/dev/null | tr -d '[:space:]' || echo "0")
    
    # Default to 0 if empty
    WRITE_CALLS=${WRITE_CALLS:-0}
    BASH_CALLS=${BASH_CALLS:-0}
    
    TOTAL_TOOLS=$((WRITE_CALLS + BASH_CALLS))
    
    RESULT=$(echo "$RESULT" | jq --argjson w "$WRITE_CALLS" '.write_tool_calls = $w')
    RESULT=$(echo "$RESULT" | jq --argjson b "$BASH_CALLS" '.bash_tool_calls = $b')
    
    if [ "$TOTAL_TOOLS" -gt 0 ]; then
        RESULT=$(echo "$RESULT" | jq '.used_tools = true')
    else
        RESULT=$(echo "$RESULT" | jq '.used_tools = false')
    fi
else
    RESULT=$(echo "$RESULT" | jq '.used_tools = null | .audit_missing = true')
fi

# ============================================================
# METRIC 4: No Extra Files (excluding plan.md which we provide)
# ============================================================
# Count files excluding plan.md (which is provided by harness)
FILE_COUNT=$(ls -1 "$WORKSPACE" 2>/dev/null | grep -v '^plan\.md$' | wc -l | tr -d ' ')
if [ "$FILE_COUNT" -eq 1 ]; then
    RESULT=$(echo "$RESULT" | jq '.no_extra_files = true')
else
    RESULT=$(echo "$RESULT" | jq '.no_extra_files = false')
    RESULT=$(echo "$RESULT" | jq --argjson c "$FILE_COUNT" '.file_count = $c')
    FILES=$(ls -1 "$WORKSPACE" 2>/dev/null | grep -v '^plan\.md$' | jq -R -s 'split("\n") | map(select(length > 0))')
    RESULT=$(echo "$RESULT" | jq --argjson f "$FILES" '.files_found = $f')
fi

# ============================================================
# CALCULATE SCORE
# ============================================================
SCORE=0
MAX_SCORE=4

[ "$(echo "$RESULT" | jq -r '.file_exists')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.content_correct')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.used_tools')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.no_extra_files')" = "true" ] && ((SCORE++))

RESULT=$(echo "$RESULT" | jq --argjson s "$SCORE" --argjson m "$MAX_SCORE" '.score = $s | .max_score = $m')

# Pass/Fail determination
if [ "$SCORE" -eq "$MAX_SCORE" ]; then
    RESULT=$(echo "$RESULT" | jq '.passed = true')
else
    RESULT=$(echo "$RESULT" | jq '.passed = false')
fi

# ============================================================
# OUTPUT
# ============================================================
echo "$RESULT" | jq .
