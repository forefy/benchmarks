# Contributing a benchmark

## Prerequisites

- You must be a verified auditor on forefy.com.
- Your benchmark must target a supported skill category (see forefy.com/skills for the current list).

## Steps

1. Fork this repo.
2. Create a new subdirectory using lowercase letters, numbers, and hyphens (e.g. `reentrancy-detection`).
3. Add the required files (see structure below).
4. Open a PR. The title must be: `benchmark: <subdirectory-name>`.
5. Once merged, register your benchmark at forefy.com/benchmarks using the subdirectory URL.
6. Upload your private corpus (25 held-out cases) through the forefy.com dashboard.

## Required files

### SKILL.md
A skill definition with `category: benchmark`. This is used by forefy.com to ingest the benchmark. The name and description fields are what appears on the leaderboard.

```yaml
---
name: My Benchmark Name
description: One sentence describing what this benchmark evaluates.
category: benchmark
---
```

### config.json
Benchmark configuration and the canonical output schema skills must produce.

```json
{
  "targets_category": "smart-contract-audit",
  "recommended_model": "claude-opus-4-5",
  "temperature": 0,
  "output_schema": {
    "findings": ["string"],
    "severity": "none|low|medium|high|critical"
  }
}
```

- `targets_category`: must match a category that exists on forefy.com/skills.
- `recommended_model`: advisory only - any model is accepted but shown on leaderboard.
- `temperature`: must be 0 for reproducibility.
- `output_schema`: the JSON schema the skill must output. scorer.py validates against this.

### expected.json
25 public test cases with ground truth. Community uses these for optimization.

```json
[
  {
    "id": "case-001",
    "input": {
      "contract": "pragma solidity ^0.8.0; ..."
    },
    "expected_output": {
      "findings": ["reentrancy at line 42"],
      "severity": "high"
    }
  }
]
```

- Keep inputs realistic - use anonymized or synthetic contracts.
- Do not reuse cases from your private corpus.
- `id` must be unique within the file and stable across benchmark versions.

### scorer.py
Pure Python, no LLM calls, deterministic. Must accept `--cases` and `--skill` arguments.

```
python scorer.py --cases expected.json --skill path/to/skill.md
```

Output format (stdout, JSON):
```json
{
  "score": 0.84,
  "passed": 21,
  "total": 25,
  "results": [
    {"id": "case-001", "passed": true, "reason": ""},
    {"id": "case-002", "passed": false, "reason": "missing reentrancy finding"}
  ]
}
```

### program.md
Natural language instructions for the optimization agent. Explain:
- What the skill should do.
- What the required JSON output format is.
- How to run the scorer.
- Any domain-specific guidance.

## Private corpus

After your benchmark is merged and registered on forefy.com, upload your private corpus through the dashboard. The private corpus contains 25 held-out cases used by you to certify community submissions for overfitting.

The private corpus never leaves your machine in plaintext - it is encrypted at rest on forefy.com servers and only you can download it.

## Versioning

Breaking changes to `expected.json` or the output schema require a new subdirectory (e.g. `reentrancy-detection-v2`). Non-breaking additions (new cases, scorer improvements that do not change pass/fail outcomes) can be done in-place via PR.
