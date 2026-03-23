---
name: Logic Issues Detection
description: Evaluates how accurately a skill identifies business logic vulnerabilities in Solidity smart contracts, using synthetic contracts modeled after real verified findings.
---

# Logic Issues Detection

## Invocation
When running this skill against a case, use this exact prompt followed by the contract source:

> Find all business logic vulnerabilities in the following Solidity contract.
> Output your findings as JSON matching the required schema.

## Required Output Format
```json
{
  "findings": [
    {
      "case_id": "<case id>",
      "vulnerable": true,
      "vulnerability_type": "<concise type, e.g. price_manipulation, incorrect_accounting>",
      "affected_function": "<function name>",
      "explanation": "<one sentence root cause>"
    }
  ]
}
```

For non-vulnerable cases, set `"vulnerable": false` and leave other fields as empty strings.

## Scoring (per case, max 1.0)
- **Vulnerable flag correct**: 0.5 pts
- **affected_function matches**: +0.3 pts
- **vulnerability_type matches**: +0.2 pts

Non-vulnerable cases: 1.0 if no vulnerability reported, 0.0 (false positive) otherwise.