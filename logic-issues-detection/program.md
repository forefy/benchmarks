# Logic Issues Detection - Agent Loop Instructions

## Objective
Improve the target skill's ability to detect business logic vulnerabilities in Solidity smart contracts. The skill must output structured JSON matching the required schema.

## Required Output Format
For each contract case in the input, the skill must produce:
```json
{
  "findings": [
    {
      "case_id": "<case id from input>",
      "vulnerable": true,
      "vulnerability_type": "<concise type, e.g. price_manipulation, incorrect_accounting>",
      "affected_function": "<function name>",
      "explanation": "<one sentence root cause>"
    }
  ]
}
```

For non-vulnerable cases, set `"vulnerable": false` and leave other fields as empty strings.

## Iteration Strategy

1. **Run the skill** against all test cases in `expected.json`. Parse the JSON output.
2. **Score with scorer.py**: `python scorer.py <output.json> expected.json`
3. If score < 1.0, identify missed cases (false negatives) and false positives.
4. **Improve the SKILL.md** by:
   - Adding patterns for missed vulnerability types
   - Tightening false-positive criteria
   - Adding examples of subtle logic bugs (integer rounding, state update order, access control gaps)
5. Repeat until score >= 0.85 or 10 iterations reached.

## Important Constraints
- Do NOT hardcode case IDs or contract names in the skill instructions
- The skill must reason about the code structure, not memorize examples
- `temperature: 0` is mandatory - set this in your agent config
- Output must be valid JSON - malformed output scores 0 for that case
