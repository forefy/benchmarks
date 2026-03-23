---
name: Logic Issues Detection
description: Evaluates how accurately a skill identifies business logic vulnerabilities in Solidity smart contracts, using synthetic contracts modeled after real verified findings.
recommended_model: claude-sonnet-4-6
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

## Skill Improvement (runs after submission for each skill)

After each skill's run is submitted, perform the following improvement analysis in the **same isolated process** that ran that skill:

### 1. Identify failures
After submission the API returns the run ID. The graded score log is stored server-side and available in the benchmark detail page. Each entry in the stored log has been enriched with:
- `grade`: `correct` | `partial` | `incorrect` | `false_positive`
- `expected_vulnerable`, `expected_function`, `expected_type`: the ground-truth answers
- `points_earned` / `points_possible`: exact credit for that case

Use the output file `<skill-id>-output.json` you already have alongside `expected.json` to identify failures directly:
- **`incorrect`** (`grade`): skill output `vulnerable: false` but expected `vulnerable: true`
- **`partial`** (`grade`): correct detection but `affected_function` or `vulnerability_type` mismatch
- **`false_positive`** (`grade`): skill output `vulnerable: true` but expected `vulnerable: false`

### 2. Diagnose root causes
For each failure, examine the contract source (`corpus/public/<case_id>/`) and the skill's `SKILL.md` and identify *why* the skill failed — missing detection pattern, vague instructions, wrong terminology, lacks examples, etc.

### 3. Propose targeted improvements to SKILL.md
Based on the failures, write a minimal, targeted diff to the skill's `SKILL.md`. Focus only on changes that would have fixed the observed failures. Valid improvement areas:
- Add or sharpen detection heuristics for missed vulnerability classes
- Clarify output field instructions (e.g. what counts as `affected_function`)
- Add concrete examples of subtle patterns the skill missed
- Tighten or fix output format instructions that caused schema mismatches
Do **not** rewrite the skill wholesale — only touch what the failures justify.

### 4. Open a PR from a fork
Use `gh` CLI to open a pull request. Steps:

```bash
# 1. Clone the skill's repo (get URL from the skill's GitHub URL field)
gh repo clone <owner>/<repo> /tmp/skill-improve-<skill-id>
cd /tmp/skill-improve-<skill-id>

# 2. Record the pre-improvement commit SHA
START_SHA=$(git rev-parse HEAD)

# 3. Apply your improvements to SKILL.md
# (write the improved content directly)

# 4. Commit
git checkout -b benchmark/improve-<first-8-chars-of-run-id>
git add SKILL.md
git commit -m "benchmark: improve logic-issues-detection score

Score before: <score>
Failures addressed: <comma-separated list of case IDs that failed>

<one sentence per failure explaining what was changed and why>"

# 5. Fork and push
gh repo fork --remote
git push fork benchmark/improve-<first-8-chars-of-run-id>

# 6. Record post-improvement SHA
END_SHA=$(git rev-parse HEAD)

# 7. Open PR
gh pr create \
  --repo <owner>/<repo> \
  --head <your-github-username>:benchmark/improve-<first-8-chars-of-run-id> \
  --title "Improve logic-issues-detection score (<score> → projected higher)" \
  --body "## Benchmark Run
- Benchmark: Logic Issues Detection
- Score: <score>
- Run ID: <run-id>

## Failures Addressed
<table of case_id | failure_type | what was changed>

## Changes
<description of what was changed in SKILL.md and why>"
```

### 5. Re-submit run with diff
After opening the PR, re-submit the same run to the API with:
- `start_commit_sha`: the SHA before your changes
- `end_commit_sha`: the SHA after your changes
- `diff_patch`: the output of `git diff HEAD~1 HEAD -- SKILL.md`

This links the benchmark run to the exact skill version that was evaluated and the improvement proposed.

### Constraints for improvement phase
- Only open a PR if the skill repo is public and hosted on GitHub.
- If the skill scored perfectly (1.000), skip the improvement phase entirely.
- Never modify corpus files, `expected.json`, or `scorer.py`.
- The PR must reference the specific failures it addresses — no generic improvements.
- Clean up the cloned repo after the PR is opened: `rm -rf /tmp/skill-improve-<skill-id>`

## Constraints
- `temperature: 0` is mandatory for reproducibility.
- **Evaluate each skill in an isolated background agent, not inline in this session.** This session accumulates context - running skill A then reasoning about skill B in the same session contaminates results. Spawn a fresh process per skill, with no access to this session's history.
- **Each skill writes output to its own file** (`<skill-name>-output.json`). Never share or overwrite output files between skills.
- Do not share information between skills - each run must be fully independent.
- Output must be valid JSON - malformed output scores 0 for that case.
- Do not hardcode case IDs or contract names into any skill instructions.
