---
name: Solana Anchor Audit
description: Evaluates a skill's ability to audit Solana Anchor programs for account validation, signer authorization, PDA seed, token-account, arithmetic, and lifecycle vulnerabilities.
---

# Solana Anchor Audit

## Invocation
When running this skill against a case, use this exact prompt followed by all source and context files in the case folder:

> Perform a comprehensive security audit of the following Solana Anchor program.
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
          "vulnerability_type": "<concise type, e.g. missing_signer_check, pda_seed_collision, missing_token_account_validation>",
          "affected_function": "<function name>",
          "severity": "<CRITICAL|HIGH|MEDIUM|LOW|INFO>",
          "explanation": "<one sentence root cause>"
        }
      ]
    }
  ]
}
```

## Corpus Layout
Each public case is a small Anchor-style program folder. A case may contain:
- `Anchor.toml`: Anchor workspace configuration
- `Cargo.toml`: Rust workspace configuration
- `programs/<case_name>/Cargo.toml`: program crate manifest
- `programs/<case_name>/src/lib.rs`: primary program entrypoint and account constraints
- `programs/<case_name>/src/state.rs`: account/state model used by the program
- `programs/<case_name>/src/errors.rs`: custom errors and validation intent
- `README.md`: neutral product context for the case

The runner should concatenate all files in deterministic path order before invoking a skill.

For programs with no vulnerabilities, return `"findings": []`.

## Scoring (per case, max 1.0)
For each expected finding, greedily match the best output finding:
- **vulnerability_type matches**: +0.4 pts
- **affected_function matches**: +0.3 pts
- **severity matches exactly**: +0.2 pts (adjacent level: +0.1 pts)
- **explanation captures root cause**: +0.1 pts

False positives subtract **0.2** per unmatched output finding (floor 0.0).
Clean cases (no expected findings): 1.0 if nothing reported, 0.0 otherwise.

## Case Themes
| Case | Theme |
|------|-------|
| case-001 | Missing owner/admin authorization |
| case-002 | Missing signer authorization |
| case-003 | Missing PDA seed validation |
| case-004 | Arbitrary CPI program |
| case-005 | Missing token account mint/authority validation |
| case-006 | Arithmetic overflow/underflow |
| case-007 | Reinitialization |
| case-008 | Insecure account close/drain destination |
| case-009 | Missing remaining account validation |
| case-010 | Missing oracle freshness check |
| case-011 | Missing recipient validation |
| case-012 | PDA seed collision from ambiguous concatenation |
| case-013 | Clean vault deposit/withdraw |
| case-014 | Clean PDA config update |
| case-015 | Clean reward claim |
