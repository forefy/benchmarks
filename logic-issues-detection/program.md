---
name: Logic Issues Detection
description: Evaluates how accurately a skill identifies business logic vulnerabilities in Solidity smart contracts, using synthetic contracts modeled after real verified findings.
recommended_model: claude-sonnet-4-6
temperature: 0
competing_skills:
  - https://forefy.com/skills/e1a4cb9e-e075-4ac2-8346-34d564546aae
  - https://forefy.com/skills/bee11b72-c6f3-4e03-b4b6-3d6c6168bbda
---

# Logic Issues Detection - Benchmark Runner

## Invocation
When running each skill against a case, use this exact prompt followed by the contract source:

> Find all business logic vulnerabilities in the following Solidity contract.
> Output your findings as JSON matching the required schema.

## Objective
Score each competing skill listed in the frontmatter against the test cases in `corpus/public/` and produce a ranked leaderboard.

## Required Output Format
Each skill must produce JSON with the following structure for each contract case:
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

## Instructions

1. Read the `competing_skills` URLs from this file's frontmatter - each is a skill to evaluate.
2. For each skill:
   a. Fetch it from the registry: `GET https://forefy.com/api/skills/<id>` (extract the ID from the URL tail) - use the `SKILL.md` entry from the returned `files` array as the system prompt.
   b. For each case in `expected.json`, read all `.sol` files in `corpus/public/<id>/` as the contract source and run the skill against them using the invocation above.
   c. Collect all outputs into a JSON file named `<skill-id>-output.json`.
   d. Score with: `python scorer.py <skill-id>-output.json expected.json`
   e. Record the score.
3. Print a ranked leaderboard of all skills by score (highest first).
4. To submit a run to the platform, POST to `/api/benchmarks/<benchmark_id>/runs` with:
   - `tested_skill_id`: the ID from the skill URL
   - `score`: the float from `scorer.py`
   - `score_log`: the `findings` array from `<skill-id>-output.json` as a JSON string - this is the per-case output used to verify results
   - `corpus_hash`: shown on the benchmark detail page (auto-filled when using the UI)
   - `model_id`: the model used for evaluation
   - `start_commit_sha` / `end_commit_sha`: before/after commit SHAs if you applied autoresearch improvements
   - `diff_patch`: the SKILL.md diff from autoresearch (omit or empty string if no changes were made)

## Constraints
- `temperature: 0` is mandatory for reproducibility.
- **Evaluate each skill in an isolated subprocess, not inline in this session.** This session accumulates context - running skill A then reasoning about skill B in the same session contaminates results. Spawn a fresh process per skill (e.g. a script that calls the LLM API with only the skill system prompt and the case as input), with no access to this session's history.
- **Each skill writes output to its own file** (`<skill-name>-output.json`). Never share or overwrite output files between skills.
- Do not share information between skills - each run must be fully independent.
- Output must be valid JSON - malformed output scores 0 for that case.
- Do not hardcode case IDs or contract names into any skill instructions.
