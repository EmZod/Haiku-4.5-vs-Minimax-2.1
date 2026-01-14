#!/bin/bash
# Verification script for B2-react-counter

set -uo pipefail

WORKSPACE="${1:-workspace}"
AUDIT="${2:-audit.jsonl}"

RESULT='{}'

# ============================================================
# METRIC 1: File Exists
# ============================================================
if [ -f "$WORKSPACE/Counter.jsx" ]; then
    RESULT=$(echo "$RESULT" | jq '.file_exists = true')
else
    RESULT=$(echo "$RESULT" | jq '.file_exists = false')
fi

# ============================================================
# METRIC 2: Contains useState Hook
# ============================================================
if [ -f "$WORKSPACE/Counter.jsx" ]; then
    if grep -q 'useState' "$WORKSPACE/Counter.jsx"; then
        RESULT=$(echo "$RESULT" | jq '.has_useState = true')
    else
        RESULT=$(echo "$RESULT" | jq '.has_useState = false')
    fi
else
    RESULT=$(echo "$RESULT" | jq '.has_useState = false')
fi

# ============================================================
# METRIC 3: Has Required data-testid Attributes
# ============================================================
if [ -f "$WORKSPACE/Counter.jsx" ]; then
    HAS_COUNT=$(grep -c 'data-testid.*count\|data-testid="count"' "$WORKSPACE/Counter.jsx" || echo "0")
    HAS_INCREMENT=$(grep -c 'data-testid.*increment\|data-testid="increment"' "$WORKSPACE/Counter.jsx" || echo "0")
    HAS_DECREMENT=$(grep -c 'data-testid.*decrement\|data-testid="decrement"' "$WORKSPACE/Counter.jsx" || echo "0")
    
    RESULT=$(echo "$RESULT" | jq --argjson c "$HAS_COUNT" --argjson i "$HAS_INCREMENT" --argjson d "$HAS_DECREMENT" \
        '.testid_count = ($c > 0) | .testid_increment = ($i > 0) | .testid_decrement = ($d > 0)')
    
    if [ "$HAS_COUNT" -gt 0 ] && [ "$HAS_INCREMENT" -gt 0 ] && [ "$HAS_DECREMENT" -gt 0 ]; then
        RESULT=$(echo "$RESULT" | jq '.has_all_testids = true')
    else
        RESULT=$(echo "$RESULT" | jq '.has_all_testids = false')
    fi
else
    RESULT=$(echo "$RESULT" | jq '.has_all_testids = false')
fi

# ============================================================
# METRIC 4: Has Default Export
# ============================================================
if [ -f "$WORKSPACE/Counter.jsx" ]; then
    if grep -qE 'export\s+default|module\.exports' "$WORKSPACE/Counter.jsx"; then
        RESULT=$(echo "$RESULT" | jq '.has_export = true')
    else
        RESULT=$(echo "$RESULT" | jq '.has_export = false')
    fi
else
    RESULT=$(echo "$RESULT" | jq '.has_export = false')
fi

# ============================================================
# METRIC 5: Tool Usage
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
MAX_SCORE=5

[ "$(echo "$RESULT" | jq -r '.file_exists')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.has_useState')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.has_all_testids')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.has_export')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.used_tools')" = "true" ] && ((SCORE++))

RESULT=$(echo "$RESULT" | jq --argjson s "$SCORE" --argjson m "$MAX_SCORE" '.score = $s | .max_score = $m')

if [ "$SCORE" -eq "$MAX_SCORE" ]; then
    RESULT=$(echo "$RESULT" | jq '.passed = true')
else
    RESULT=$(echo "$RESULT" | jq '.passed = false')
fi

echo "$RESULT" | jq .
