---
name: Autonomous Audit
description: Evaluates a skill's ability to perform a comprehensive security audit across common vulnerability classes - reentrancy, access control, input validation, signature security, and more - using realistic Solidity contracts.
recommended_model: claude-sonnet-4-6
---

# Autonomous Audit - Benchmark Runner

## Invocation
When running each skill against a case, use this exact prompt followed by the contract source:

> Perform a comprehensive security audit of the following Solidity contract.
> Report all vulnerabilities you find. Output your findings as JSON matching the required schema.

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
      "vulnerability_type": "<concise type, e.g. reentrancy, missing_access_control, signature_replay>",
      "affected_function": "<function name>",
      "severity": "<CRITICAL|HIGH|MEDIUM|LOW|INFO>",
      "explanation": "<one sentence root cause>"
    }
  ]
}
```

For contracts with no vulnerabilities, return `"findings": []`.

## Scoring
Evaluate each case against `expected.json`. For each expected finding in a case:

- **+0.4** if `vulnerability_type` matches (normalized: lowercase, spaces→`_`, hyphens→`_`)
- **+0.3** if `affected_function` matches (case-insensitive)
- **+0.2** if `severity` matches exactly
- **+0.1** if `explanation` captures the root cause (semantic match - judge on substance)

False positives (findings with no match in expected) subtract **0.2** per finding.

**Clean contract cases** (expected findings empty): full score if no findings reported, zero otherwise.

Normalize per-case score to [0.0, 1.0].

## Running the Benchmark

For each case in `corpus/public/`:
1. Read the Solidity file(s)
2. Build the prompt using the invocation above, appending the contract source
3. Run the competing skill with `temperature: 0`
4. Parse the JSON output and evaluate against `expected.json`
5. Record score and log per case

Submit the score log to the platform using the benchmark submission endpoint documented in the platform README.

## Autoresearch Improvement Loop

After scoring, if the overall score < 1.0:
1. Identify which cases the skill missed or partially scored
2. Analyze what the skill's output was vs. what was expected
3. Propose targeted edits to the skill's SKILL.md (one focused change per run)
4. Fork the skill's repository, apply the edit, open a PR with a failure table in the PR body
5. Re-submit a run with `diff_patch` and the fork commit SHA

Only one improvement proposal per benchmark run. Do not push directly to the original repo - always fork first. Clean up `/tmp/skill-improve-<skill-id>` after opening the PR.
