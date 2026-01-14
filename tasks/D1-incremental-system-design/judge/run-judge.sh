#!/bin/bash
# LLM Judge Runner for D1-incremental-system-design
#
# Usage: ./run-judge.sh <design.md path> [output.json path]
#
# This script invokes an LLM to evaluate the quality of the design.
# It uses pi CLI with a judge prompt.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DESIGN_PATH="${1:-}"
OUTPUT_PATH="${2:-judge_result.json}"

if [ -z "$DESIGN_PATH" ] || [ ! -f "$DESIGN_PATH" ]; then
    echo "Usage: $0 <design.md path> [output.json path]"
    echo "Error: design.md not found at: $DESIGN_PATH"
    exit 1
fi

# Read the design document
DESIGN_CONTENT=$(cat "$DESIGN_PATH")

# Read the judge prompt template
JUDGE_PROMPT=$(cat "$SCRIPT_DIR/JUDGE_PROMPT.md")

# Combine prompt with design content
FULL_PROMPT="$JUDGE_PROMPT

---

## The Design Document to Evaluate

\`\`\`markdown
$DESIGN_CONTENT
\`\`\`

---

Please evaluate this design and provide your assessment in the JSON format specified above."

# Create temp file for prompt
TEMP_PROMPT=$(mktemp)
echo "$FULL_PROMPT" > "$TEMP_PROMPT"

echo "Running LLM judge..."
echo "Design: $DESIGN_PATH"
echo "Output: $OUTPUT_PATH"

# Run judge using pi CLI (blocking, print mode)
# Use Opus 4.5 for judging (highest quality evaluation)
cat > ~/.pi/agent/settings.json << 'EOF'
{
  "defaultProvider": "anthropic",
  "defaultModel": "claude-opus-4-5",
  "defaultThinkingLevel": "none"
}
EOF

# Run the judge
JUDGE_OUTPUT=$(pi --print --max-turns 3 "$(cat $TEMP_PROMPT)" 2>&1)

# Extract JSON from output (find the JSON block)
JSON_RESULT=$(echo "$JUDGE_OUTPUT" | grep -A1000 '```json' | grep -B1000 '```' | grep -v '```' | head -50)

if [ -n "$JSON_RESULT" ]; then
    # Validate JSON
    if echo "$JSON_RESULT" | jq . > /dev/null 2>&1; then
        echo "$JSON_RESULT" | jq . > "$OUTPUT_PATH"
        echo "✅ Judge evaluation saved to: $OUTPUT_PATH"
    else
        echo "⚠️ Judge output was not valid JSON. Saving raw output."
        echo "$JUDGE_OUTPUT" > "${OUTPUT_PATH%.json}.txt"
    fi
else
    echo "⚠️ No JSON found in judge output. Saving raw output."
    echo "$JUDGE_OUTPUT" > "${OUTPUT_PATH%.json}.txt"
fi

# Cleanup
rm -f "$TEMP_PROMPT"

# Show summary if JSON was valid
if [ -f "$OUTPUT_PATH" ]; then
    echo ""
    echo "=== Judge Summary ==="
    jq -r '"Weighted Total: \(.weighted_total // "N/A")"' "$OUTPUT_PATH" 2>/dev/null || true
    jq -r '"Would Goedecke Approve: \(.qualitative_assessment.would_goedecke_approve // "N/A")"' "$OUTPUT_PATH" 2>/dev/null || true
fi
