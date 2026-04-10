---
name: Move Audit
description: Evaluates a skill's ability to perform comprehensive security audits of Move smart contracts across multiple platforms (Initia, Aptos, Sui), covering common vulnerability classes including access control, arithmetic issues, reentrancy, and logic errors in real-world projects.
---

# Move Audit

## Invocation
When running this skill against a case, use this exact prompt followed by the contract source:

> Perform a comprehensive security audit of the following Move contract.
> Report all vulnerabilities you find. Output your findings as JSON matching the required schema.

## Required Output Format
```json
{
  "cases": [
    {
      "case_id": "<case id>",
      "findings": [
        {
          "vulnerable": true,
          "vulnerability_type": "<concise type, e.g. missing_access_control, arithmetic_overflow, reentrancy, price_manipulation>",
          "affected_function": "<function name>",
          "severity": "<CRITICAL|HIGH|MEDIUM|LOW|INFO>",
          "explanation": "<one sentence root cause>"
        }
      ]
    }
  ]
}
```

For contracts with no vulnerabilities, return `"findings": []`.

## Scoring (per case, max 1.0)
For each expected finding, greedily match the best output finding:
- **vulnerability_type matches**: +0.4 pts
- **affected_function matches**: +0.3 pts
- **severity matches exactly**: +0.2 pts (adjacent level: +0.1 pts)
- **explanation captures root cause**: +0.1 pts

False positives subtract **0.2** per unmatched output finding (floor 0.0).
Clean cases (no expected findings): 1.0 if nothing reported, 0.0 otherwise.
