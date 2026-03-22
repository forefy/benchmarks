# Contributing a benchmark

## Prerequisites

- You must be a verified auditor on forefy.com.
- Your benchmark will target specific skills - you select which skills it evaluates after registering on forefy.com.

## Steps

1. Fork this repo.
2. Create a new subdirectory using lowercase letters, numbers, and hyphens (e.g. `reentrancy-detection`).
3. Add the required files (see structure below).
4. Open a PR. The title must be: `benchmark: <subdirectory-name>`.
5. Once merged, register your benchmark at forefy.com/benchmarks using the subdirectory URL.
6. On the benchmark detail page, select which skills this benchmark targets.

## Required files

### program.md
The single source of truth for the benchmark. Contains YAML frontmatter (read by forefy.com for registry ingestion) and the agent runner instructions.

Frontmatter fields:
- `name` (required): benchmark name shown on the leaderboard
- `description` (required): one sentence describing what this benchmark evaluates
- `recommended_model` (optional): advisory model for reproducibility
- `temperature` (optional): must be 0 for deterministic scoring

```md
---
name: My Benchmark Name
description: One sentence describing what this benchmark evaluates.
recommended_model: claude-opus-4-5
temperature: 0
---

# My Benchmark - Runner

## Invocation
When running each skill against a case, use this exact prompt followed by the input:

> [task-specific invocation matching the skill category]

## Required Output Format
...

## Instructions
1. Fetch the list of target skills from the registry: `GET https://forefy.com/api/benchmarks/<benchmark_id>/targets`.
2. For each skill, fetch it from the registry (`GET /api/skills/<id>`), run it against every case in `corpus/public/` using the invocation above.
3. Score with scorer.py and record results.
4. Print a ranked leaderboard.
```

The invocation line is critical - it defines the exact prompt used to call each skill, ensuring fair and reproducible comparison across all competitors.

- `recommended_model`: advisory only - any model is accepted but shown on leaderboard.
- `temperature`: must be 0 for reproducibility.
- `output_schema`: the JSON schema the skill must output. scorer.py validates against this.

### expected.json
25 public test cases with ground truth (committed, platform-required). Community uses these for optimization and scoring.

```json
[
  {
    "id": "case-001",
    "vulnerable": true,
    "vulnerability_type": "reentrancy",
    "affected_function": "withdraw",
    "explanation": "one sentence root cause"
  }
]
```

Case IDs map to contract folders in `corpus/public/<id>/`. Each folder may contain one or more `.sol` files.

- Keep contracts realistic - use anonymized or synthetic code.
- `id` must be unique and stable across benchmark versions.

### corpus/
Test case contracts split by visibility:

```
corpus/
  public/     committed - community runs against these
    case-001/
      Contract.sol
  private/    gitignored - auditor only, for certification
    case-011/
      Contract.sol
```

`corpus/private/` and `expected-private.json` are listed in `.gitignore` and never committed. The auditor maintains them locally to certify community submissions against unseen cases:

```
python scorer.py <skill>-output.json expected-private.json
```

### scorer.py
Pure Python, no LLM calls, deterministic. Accepts two positional arguments: skill output JSON and expected JSON.

```
python scorer.py <skill>-output.json expected.json
python scorer.py <skill>-output.json expected-private.json
```

Prints a float 0.0-1.0 to stdout.

### program.md
Natural language instructions for the optimization agent. Explain:
- What the skill should do.
- What the required JSON output format is.
- How to run the scorer.
- Any domain-specific guidance.

### Target skills
Target skills are managed on the benchmark detail page at forefy.com - no frontmatter needed. The runner fetches them live from the registry at run time via `GET /api/benchmarks/<id>/targets`.

Skills are always fetched at their current registry version. Each run records `start_commit_sha` / `end_commit_sha` to pin exactly which version was scored.

## Private corpus

The private corpus (`corpus/private/` + `expected-private.json`) lives only on the auditor's machine - never committed. Use it to certify community submissions against unseen cases and detect overfitting.

## Versioning

Breaking changes to `expected.json` or the output schema require a new subdirectory (e.g. `reentrancy-detection-v2`). Non-breaking additions (new cases, scorer improvements that do not change pass/fail outcomes) can be done in-place via PR.
