---
name: Logic Issues Detection
description: Evaluates how accurately a skill identifies business logic vulnerabilities in Solidity smart contracts, using synthetic contracts modeled after real verified findings.
recommended_model: claude-sonnet-4-6
temperature: 0
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

1. Fetch all target skills from the registry: `GET https://forefy.com/api/benchmarks/<benchmark_id>/targets` - use the `SKILL.md` entry from each skill's `files` array as the system prompt.
2. For each skill:
   a. For each case in `expected.json`, read all `.sol` files in `corpus/public/<case_id>/` as the contract source and run the skill against them using the invocation above.
   b. Collect all outputs into a JSON file named `<skill-id>-output.json`.
   c. Score with: `python scorer.py <skill-id>-output.json expected.json`
   d. Record the score.
3. Print a ranked leaderboard of all skills by score (highest first).
4. To submit a run, POST to `https://forefy.com/api/benchmark-runs/token-submit` with header `X-Run-Token: <your token>` and body:
   - `benchmark_skill_id`: the benchmark ID (provided in your run prompt)
   - `tested_skill_id`: the skill ID
   - `score`: the float from `scorer.py`
   - `score_log`: the `findings` array from `<skill-id>-output.json` as a JSON string
   - `corpus_hash`: provided in your run prompt
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
