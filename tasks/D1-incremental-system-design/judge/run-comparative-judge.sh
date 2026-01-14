#!/bin/bash
# Comparative LLM Judge for D1-incremental-system-design
#
# Usage: ./run-comparative-judge.sh <model_a_design.md> <model_b_design.md> [output.json]
#
# Compares two designs side-by-side using LLM evaluation

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DESIGN_A="${1:-}"
DESIGN_B="${2:-}"
OUTPUT_PATH="${3:-comparative_judge_result.json}"

if [ -z "$DESIGN_A" ] || [ -z "$DESIGN_B" ]; then
    echo "Usage: $0 <model_a_design.md> <model_b_design.md> [output.json]"
    exit 1
fi

if [ ! -f "$DESIGN_A" ]; then
    echo "Error: Model A design not found: $DESIGN_A"
    exit 1
fi

if [ ! -f "$DESIGN_B" ]; then
    echo "Error: Model B design not found: $DESIGN_B"
    exit 1
fi

# Read both designs
DESIGN_A_CONTENT=$(cat "$DESIGN_A")
DESIGN_B_CONTENT=$(cat "$DESIGN_B")

# Read the comparative judge prompt
JUDGE_TEMPLATE=$(cat "$SCRIPT_DIR/COMPARATIVE_JUDGE_PROMPT.md")

# Build the full prompt
FULL_PROMPT=$(echo "$JUDGE_TEMPLATE" | sed "s|\[MODEL_A_DESIGN_HERE\]|$DESIGN_A_CONTENT|" | sed "s|\[MODEL_B_DESIGN_HERE\]|$DESIGN_B_CONTENT|")

# For large content, use a file
TEMP_PROMPT=$(mktemp)
cat > "$TEMP_PROMPT" << PROMPT_EOF
$JUDGE_TEMPLATE

---

## Model A Design Document

\`\`\`markdown
$DESIGN_A_CONTENT
\`\`\`

---

## Model B Design Document

\`\`\`markdown
$DESIGN_B_CONTENT
\`\`\`

---

Please provide your comparative analysis in the JSON format specified above.
PROMPT_EOF

echo "=============================================="
echo "COMPARATIVE LLM JUDGE"
echo "=============================================="
echo "Model A: $DESIGN_A"
echo "Model B: $DESIGN_B"
echo "Output:  $OUTPUT_PATH"
echo "=============================================="

# Use Opus 4.5 for comparative judging (highest quality evaluation)
cat > ~/.pi/agent/settings.json << 'EOF'
{
  "defaultProvider": "anthropic",
  "defaultModel": "claude-opus-4-5",
  "defaultThinkingLevel": "none"
}
EOF

echo ""
echo "Running comparative judge (this may take a minute)..."

# Run the judge
JUDGE_OUTPUT=$(pi --print --max-turns 5 "$(cat $TEMP_PROMPT)" 2>&1)

# Extract JSON from output
JSON_RESULT=$(echo "$JUDGE_OUTPUT" | sed -n '/```json/,/```/p' | grep -v '```')

if [ -n "$JSON_RESULT" ]; then
    if echo "$JSON_RESULT" | jq . > /dev/null 2>&1; then
        echo "$JSON_RESULT" | jq . > "$OUTPUT_PATH"
        echo ""
        echo "✅ Comparative evaluation saved to: $OUTPUT_PATH"
        
        # Show verdict
        echo ""
        echo "=============================================="
        echo "VERDICT"
        echo "=============================================="
        jq -r '"Overall Winner: \(.verdict.overall_winner)"' "$OUTPUT_PATH"
        jq -r '"Confidence: \(.verdict.confidence)"' "$OUTPUT_PATH"
        echo ""
        jq -r '"Goedecke Scores:"' "$OUTPUT_PATH"
        jq -r '"  Model A: \(.goedecke_verdict.model_a_score)/10"' "$OUTPUT_PATH"
        jq -r '"  Model B: \(.goedecke_verdict.model_b_score)/10"' "$OUTPUT_PATH"
        echo ""
        jq -r '.verdict.summary' "$OUTPUT_PATH"
    else
        echo "⚠️ Judge output was not valid JSON"
        echo "$JUDGE_OUTPUT" > "${OUTPUT_PATH%.json}_raw.txt"
        echo "Raw output saved to: ${OUTPUT_PATH%.json}_raw.txt"
    fi
else
    echo "⚠️ No JSON found in judge output"
    echo "$JUDGE_OUTPUT" > "${OUTPUT_PATH%.json}_raw.txt"
fi

# Cleanup
rm -f "$TEMP_PROMPT"
