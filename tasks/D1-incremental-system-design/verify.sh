#!/bin/bash
# Verification script for D1-incremental-system-design
# 
# This script does TWO things:
# 1. Basic structural checks (deterministic)
# 2. Prepares output for LLM judge (qualitative evaluation)

set -uo pipefail

WORKSPACE="${1:-workspace}"
AUDIT="${2:-audit.jsonl}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

RESULT='{}'

# ============================================================
# STRUCTURAL CHECKS (Deterministic)
# ============================================================

# 1. File exists
if [ -f "$WORKSPACE/design.md" ]; then
    RESULT=$(echo "$RESULT" | jq '.file_exists = true')
    FILE_SIZE=$(wc -c < "$WORKSPACE/design.md" | tr -d '[:space:]')
    RESULT=$(echo "$RESULT" | jq --argjson s "$FILE_SIZE" '.file_size_bytes = $s')
else
    RESULT=$(echo "$RESULT" | jq '.file_exists = false')
fi

# 2. Has required sections
if [ -f "$WORKSPACE/design.md" ]; then
    SECTIONS=0
    
    grep -qi "state inventory" "$WORKSPACE/design.md" && ((SECTIONS++))
    grep -qi "components" "$WORKSPACE/design.md" && ((SECTIONS++))
    grep -qi "hot paths" "$WORKSPACE/design.md" && ((SECTIONS++))
    grep -qi "failure modes" "$WORKSPACE/design.md" && ((SECTIONS++))
    grep -qi "design decisions\|decision.*log" "$WORKSPACE/design.md" && ((SECTIONS++))
    grep -qi "final summary" "$WORKSPACE/design.md" && ((SECTIONS++))
    
    RESULT=$(echo "$RESULT" | jq --argjson s "$SECTIONS" '.sections_found = $s')
    RESULT=$(echo "$RESULT" | jq '.expected_sections = 6')
    
    if [ "$SECTIONS" -ge 5 ]; then
        RESULT=$(echo "$RESULT" | jq '.has_required_sections = true')
    else
        RESULT=$(echo "$RESULT" | jq '.has_required_sections = false')
    fi
else
    RESULT=$(echo "$RESULT" | jq '.has_required_sections = false')
fi

# 3. Addresses all turns (look for turn-related content)
if [ -f "$WORKSPACE/design.md" ]; then
    TURNS_ADDRESSED=0
    
    grep -qi "session" "$WORKSPACE/design.md" && ((TURNS_ADDRESSED++))      # Turn 1
    grep -qi "rate limit" "$WORKSPACE/design.md" && ((TURNS_ADDRESSED++))   # Turn 2
    grep -qi "audit" "$WORKSPACE/design.md" && ((TURNS_ADDRESSED++))        # Turn 3
    grep -qi "performance\|latency\|850ms" "$WORKSPACE/design.md" && ((TURNS_ADDRESSED++))  # Turn 4
    grep -qi "ci.cd\|build agent\|api key" "$WORKSPACE/design.md" && ((TURNS_ADDRESSED++))  # Turn 5
    grep -qi "region\|gdpr\|eu\|europe" "$WORKSPACE/design.md" && ((TURNS_ADDRESSED++))     # Turn 6
    grep -qi "webhook" "$WORKSPACE/design.md" && ((TURNS_ADDRESSED++))      # Turn 7
    grep -qi "encrypt\|security.*product\|conflict" "$WORKSPACE/design.md" && ((TURNS_ADDRESSED++))  # Turn 8
    grep -qi "10x\|scale" "$WORKSPACE/design.md" && ((TURNS_ADDRESSED++))   # Turn 9
    grep -qi "summary\|tradeoff\|limitation" "$WORKSPACE/design.md" && ((TURNS_ADDRESSED++)) # Turn 10
    
    RESULT=$(echo "$RESULT" | jq --argjson t "$TURNS_ADDRESSED" '.turns_addressed = $t')
    RESULT=$(echo "$RESULT" | jq '.expected_turns = 10')
fi

# 4. Tool usage
if [ -f "$AUDIT" ]; then
    WRITE_CALLS=$(grep -c '"tool":"[Ww]rite"' "$AUDIT" 2>/dev/null | tr -d '[:space:]' || echo "0")
    EDIT_CALLS=$(grep -c '"tool":"[Ee]dit"' "$AUDIT" 2>/dev/null | tr -d '[:space:]' || echo "0")
    READ_CALLS=$(grep -c '"tool":"[Rr]ead"' "$AUDIT" 2>/dev/null | tr -d '[:space:]' || echo "0")
    
    WRITE_CALLS=${WRITE_CALLS:-0}
    EDIT_CALLS=${EDIT_CALLS:-0}
    READ_CALLS=${READ_CALLS:-0}
    
    RESULT=$(echo "$RESULT" | jq --argjson w "$WRITE_CALLS" --argjson e "$EDIT_CALLS" --argjson r "$READ_CALLS" \
        '.write_calls = $w | .edit_calls = $e | .read_calls = $r')
    
    # For a 10-turn task, we expect multiple writes/edits
    TOTAL=$((WRITE_CALLS + EDIT_CALLS))
    if [ "$TOTAL" -ge 5 ]; then
        RESULT=$(echo "$RESULT" | jq '.iterative_development = true')
    else
        RESULT=$(echo "$RESULT" | jq '.iterative_development = false')
    fi
else
    RESULT=$(echo "$RESULT" | jq '.iterative_development = null | .audit_missing = true')
fi

# ============================================================
# STRUCTURAL SCORE (Max 10 points)
# ============================================================
STRUCTURAL_SCORE=0

[ "$(echo "$RESULT" | jq -r '.file_exists')" = "true" ] && ((STRUCTURAL_SCORE+=2))
[ "$(echo "$RESULT" | jq -r '.has_required_sections')" = "true" ] && ((STRUCTURAL_SCORE+=3))

TURNS=$(echo "$RESULT" | jq -r '.turns_addressed // 0')
if [ "$TURNS" -ge 8 ]; then
    ((STRUCTURAL_SCORE+=3))
elif [ "$TURNS" -ge 5 ]; then
    ((STRUCTURAL_SCORE+=2))
elif [ "$TURNS" -ge 3 ]; then
    ((STRUCTURAL_SCORE+=1))
fi

[ "$(echo "$RESULT" | jq -r '.iterative_development')" = "true" ] && ((STRUCTURAL_SCORE+=2))

RESULT=$(echo "$RESULT" | jq --argjson s "$STRUCTURAL_SCORE" '.structural_score = $s | .structural_max = 10')

# ============================================================
# PREPARE FOR LLM JUDGE
# ============================================================
if [ -f "$WORKSPACE/design.md" ]; then
    # Copy design.md to output for judge evaluation
    cp "$WORKSPACE/design.md" "$WORKSPACE/design_for_judge.md"
    RESULT=$(echo "$RESULT" | jq '.ready_for_llm_judge = true')
    RESULT=$(echo "$RESULT" | jq --arg p "$WORKSPACE/design_for_judge.md" '.judge_input_path = $p')
else
    RESULT=$(echo "$RESULT" | jq '.ready_for_llm_judge = false')
fi

# ============================================================
# FINAL RESULT
# Note: This is structural only. LLM judge provides qualitative score.
# ============================================================
if [ "$STRUCTURAL_SCORE" -ge 7 ]; then
    RESULT=$(echo "$RESULT" | jq '.structural_passed = true')
else
    RESULT=$(echo "$RESULT" | jq '.structural_passed = false')
fi

RESULT=$(echo "$RESULT" | jq '.note = "Structural check only. Run LLM judge for qualitative evaluation."')

echo "$RESULT" | jq .
