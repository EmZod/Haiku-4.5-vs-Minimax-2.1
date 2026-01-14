# Comparative System Design Judge

You are comparing two system designs produced by different AI models (Model A and Model B) given identical requirements.

Your job is to identify **path differences** - where did the models make different choices, and what do those choices reveal about their reasoning patterns?

## Evaluation Framework

### Part 1: Path Divergence Analysis

For each major decision point, identify:
1. What did Model A choose?
2. What did Model B choose?
3. Which choice is more "Goedecke-approved" (boring, simple, obvious)?

Decision points to analyze:
- **Session storage**: How did each model store sessions?
- **Rate limiting approach**: In-memory, Redis, database?
- **Audit log architecture**: Where does audit state live?
- **Performance fix (Turn 4)**: How did each diagnose and fix?
- **Rate limiter fix (Turn 5)**: How did each handle the multi-tenant case?
- **Multi-region strategy**: How did each partition state?
- **Webhook reliability**: How did each handle slow/failing endpoints?
- **Conflicting requirements**: How did each resolve security vs debuggability?
- **Scale preparation**: What did each prioritize for 10x growth?

### Part 2: Pattern Recognition

Identify recurring patterns:

**Complexity Attractors**
- Which model reaches for complexity more often?
- What triggers the reach for complexity?

**State Handling**
- Which model is more conscious of state ownership?
- Which model creates more shared/ambiguous state?

**Failure Awareness**
- Which model considers failures proactively?
- Which model only addresses failures when injected?

**Recovery Style**
- When failures were injected, how did each recover?
- Did they diagnose root cause or apply band-aids?

### Part 3: Qualitative Verdict

Answer these questions:

1. **If you had to ship one of these designs tomorrow, which would you choose and why?**

2. **Which design would be easier to operate at 3am during an incident?**

3. **Which design would be easier to explain to a new team member?**

4. **In 6 months, which design would have accumulated more technical debt?**

## Output Format

```json
{
  "path_divergences": [
    {
      "decision_point": "<name>",
      "model_a_choice": "<description>",
      "model_b_choice": "<description>",
      "better_choice": "A" | "B" | "TIE",
      "reasoning": "<why>"
    }
  ],
  "pattern_analysis": {
    "complexity_attractor": {
      "model_a": "<pattern>",
      "model_b": "<pattern>",
      "more_restrained": "A" | "B"
    },
    "state_consciousness": {
      "model_a": "<pattern>",
      "model_b": "<pattern>",
      "more_conscious": "A" | "B"
    },
    "failure_awareness": {
      "model_a": "<pattern>",
      "model_b": "<pattern>",
      "more_aware": "A" | "B"
    },
    "recovery_style": {
      "model_a": "<pattern>",
      "model_b": "<pattern>",
      "better_recovery": "A" | "B"
    }
  },
  "verdict": {
    "ship_tomorrow": "A" | "B",
    "easier_to_operate": "A" | "B",
    "easier_to_explain": "A" | "B",
    "less_debt_in_6_months": "A" | "B",
    "overall_winner": "A" | "B" | "TIE",
    "confidence": "HIGH" | "MEDIUM" | "LOW",
    "summary": "<one paragraph explaining the key differences>"
  },
  "goedecke_verdict": {
    "model_a_score": "<1-10>",
    "model_b_score": "<1-10>",
    "model_a_would_approve": true | false,
    "model_b_would_approve": true | false,
    "key_insight": "<what would Goedecke say about these designs?>"
  }
}
```

---

## Model A Design Document

```markdown
[MODEL_A_DESIGN_HERE]
```

---

## Model B Design Document

```markdown
[MODEL_B_DESIGN_HERE]
```
