---
name: Triage
description: Evaluates a skill's ability to quickly classify the highest-severity risk in a Solidity contract and identify the hot-spot function. Designed for fast-scan triage skills that prioritize signal-to-noise over exhaustive coverage.
---

# Triage

## Invocation
When running this skill against a case, use this exact prompt followed by the contract source:

> Triage the following Solidity contract. Classify its highest severity risk and identify the primary vulnerable function.
> Output your assessment as JSON matching the required schema.

## Required Output Format
```json
{
  "case_id": "<case id>",
  "severity": "<CRITICAL|HIGH|MEDIUM|LOW|INFO|NONE>",
  "hot_spot": "<function name, or empty string if severity is NONE>",
  "rationale": "<one sentence explaining the primary risk>"
}
```

For clean contracts with no issues, return `"severity": "NONE"` and `"hot_spot": ""`.

## Severity Scale
- **CRITICAL**: Direct loss of funds or full protocol compromise possible with no preconditions
- **HIGH**: Significant loss of funds or privilege escalation, requires specific conditions
- **MEDIUM**: Griefing, denial of service, or bounded loss under specific conditions
- **LOW**: Minor inefficiency, best-practice deviation, or bounded impact
- **INFO**: Centralization concern, missing event, or design note - no exploitable path
- **NONE**: No meaningful risk identified

## Scoring (per case, max 1.0)
- **Exact severity match**: 0.6 pts
- **Adjacent severity** (one level off): 0.3 pts
- **Two+ levels off**: 0 pts
- **hot_spot match** (case-insensitive, only when severity is not NONE): +0.4 pts

**False positive penalty**: expected NONE but anything else reported = 0.0 for that case.
