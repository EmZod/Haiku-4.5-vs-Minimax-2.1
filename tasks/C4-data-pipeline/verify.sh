#!/bin/bash
# Verification script for C4-data-pipeline

set -uo pipefail

WORKSPACE="${1:-workspace}"
AUDIT="${2:-audit.jsonl}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

RESULT='{}'

# ============================================================
# METRIC 1: Output File Exists
# ============================================================
if [ -f "$WORKSPACE/summary.csv" ]; then
    RESULT=$(echo "$RESULT" | jq '.file_exists = true')
else
    RESULT=$(echo "$RESULT" | jq '.file_exists = false')
fi

# ============================================================
# METRIC 2: Has Correct Headers
# ============================================================
EXPECTED_HEADER="customer,order_count,total_spent,avg_order_value"
if [ -f "$WORKSPACE/summary.csv" ]; then
    ACTUAL_HEADER=$(head -1 "$WORKSPACE/summary.csv" | tr -d '\r')
    if [ "$ACTUAL_HEADER" = "$EXPECTED_HEADER" ]; then
        RESULT=$(echo "$RESULT" | jq '.correct_headers = true')
    else
        RESULT=$(echo "$RESULT" | jq '.correct_headers = false')
        RESULT=$(echo "$RESULT" | jq --arg h "$ACTUAL_HEADER" '.actual_header = $h')
    fi
else
    RESULT=$(echo "$RESULT" | jq '.correct_headers = false')
fi

# ============================================================
# METRIC 3: Correct Row Count (should be 3 customers + header)
# ============================================================
if [ -f "$WORKSPACE/summary.csv" ]; then
    LINE_COUNT=$(wc -l < "$WORKSPACE/summary.csv" | tr -d '[:space:]')
    if [ "$LINE_COUNT" -eq 4 ]; then
        RESULT=$(echo "$RESULT" | jq '.correct_row_count = true')
    else
        RESULT=$(echo "$RESULT" | jq '.correct_row_count = false')
        RESULT=$(echo "$RESULT" | jq --argjson c "$LINE_COUNT" '.actual_row_count = $c')
    fi
else
    RESULT=$(echo "$RESULT" | jq '.correct_row_count = false')
fi

# ============================================================
# METRIC 4: Correct Data Values
# ============================================================
if [ -f "$WORKSPACE/summary.csv" ] && [ -f "$SCRIPT_DIR/expected/summary.csv" ]; then
    # Compare content using numerical comparison (handles different decimal formats)
    DATA_MATCH=$(python3 << PYCHECK
import csv
import sys

def read_csv(path):
    try:
        with open(path, 'r') as f:
            reader = csv.DictReader(f)
            return sorted([dict(r) for r in reader], key=lambda x: x.get('customer', ''))
    except:
        return None

actual = read_csv("$WORKSPACE/summary.csv")
expected = read_csv("$SCRIPT_DIR/expected/summary.csv")

if actual is None or expected is None:
    print("ERROR")
    sys.exit(1)

if len(actual) != len(expected):
    print("LENGTH_MISMATCH")
    sys.exit(1)

all_match = True
for a, e in zip(actual, expected):
    for key in e.keys():
        try:
            # Compare as floats for numerical columns
            if key in ['order_count', 'total_spent', 'avg_order_value']:
                if abs(float(a.get(key, 0)) - float(e.get(key, 0))) > 0.01:
                    all_match = False
            else:
                if a.get(key) != e.get(key):
                    all_match = False
        except:
            all_match = False

print("MATCH" if all_match else "MISMATCH")
PYCHECK
)
    
    if [ "$DATA_MATCH" = "MATCH" ]; then
        RESULT=$(echo "$RESULT" | jq '.data_correct = true')
    else
        RESULT=$(echo "$RESULT" | jq '.data_correct = false')
        
        # Check individual rows
        CORRECT_ROWS=0
        
        # Charlie row
        if grep -q "Charlie,2,405" "$WORKSPACE/summary.csv"; then
            ((CORRECT_ROWS++))
        fi
        
        # Alice row
        if grep -q "Alice,2,300" "$WORKSPACE/summary.csv"; then
            ((CORRECT_ROWS++))
        fi
        
        # Bob row
        if grep -q "Bob,1,125" "$WORKSPACE/summary.csv"; then
            ((CORRECT_ROWS++))
        fi
        
        RESULT=$(echo "$RESULT" | jq --argjson r "$CORRECT_ROWS" '.correct_rows = $r')
        
        # Store actual content for debugging
        ACTUAL_CONTENT=$(cat "$WORKSPACE/summary.csv")
        RESULT=$(echo "$RESULT" | jq --arg a "$ACTUAL_CONTENT" '.actual_content = $a')
    fi
else
    RESULT=$(echo "$RESULT" | jq '.data_correct = false')
fi

# ============================================================
# METRIC 5: Correct Sort Order (Charlie first, then Alice, then Bob)
# ============================================================
if [ -f "$WORKSPACE/summary.csv" ]; then
    # Get order of customers (skip header)
    FIRST=$(sed -n '2p' "$WORKSPACE/summary.csv" | cut -d',' -f1)
    SECOND=$(sed -n '3p' "$WORKSPACE/summary.csv" | cut -d',' -f1)
    THIRD=$(sed -n '4p' "$WORKSPACE/summary.csv" | cut -d',' -f1)
    
    if [ "$FIRST" = "Charlie" ] && [ "$SECOND" = "Alice" ] && [ "$THIRD" = "Bob" ]; then
        RESULT=$(echo "$RESULT" | jq '.correct_sort = true')
    else
        RESULT=$(echo "$RESULT" | jq '.correct_sort = false')
        RESULT=$(echo "$RESULT" | jq --arg o "$FIRST,$SECOND,$THIRD" '.actual_order = $o')
    fi
else
    RESULT=$(echo "$RESULT" | jq '.correct_sort = false')
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
[ "$(echo "$RESULT" | jq -r '.correct_headers')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.correct_row_count')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.data_correct')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.correct_sort')" = "true" ] && ((SCORE++))
[ "$(echo "$RESULT" | jq -r '.used_tools')" = "true" ] && ((SCORE++))

RESULT=$(echo "$RESULT" | jq --argjson s "$SCORE" --argjson m "$MAX_SCORE" '.score = $s | .max_score = $m')

if [ "$SCORE" -eq "$MAX_SCORE" ]; then
    RESULT=$(echo "$RESULT" | jq '.passed = true')
else
    RESULT=$(echo "$RESULT" | jq '.passed = false')
fi

echo "$RESULT" | jq .
