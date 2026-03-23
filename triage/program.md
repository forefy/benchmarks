---
name: Triage
description: Evaluates a skill's ability to quickly classify the highest-severity risk in a Solidity contract and identify the hot-spot function. Designed for fast-scan triage skills that prioritize signal-to-noise over exhaustive coverage.
recommended_model: claude-haiku-4-5
---

# Triage - Benchmark Runner

## Invocation
When running each skill against a case, use this exact prompt followed by the contract source:

> Triage the following Solidity contract. Classify its highest severity risk and identify the primary vulnerable function.
> Output your assessment as JSON matching the required schema.

## Objective
Score each competing skill listed in the frontmatter against the test cases in `corpus/public/` and produce a ranked leaderboard. This benchmark rewards precision and speed - a skill that correctly identifies the top risk is preferred over one that noisily reports every potential concern.

## Required Output Format
Each skill must produce JSON with the following structure for each contract case:
```json
{
  "case_id": "<case id from input>",
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

## Scoring
For each case, evaluate against `expected.json`:

- **Exact severity match**: 0.6 points
- **Adjacent severity match** (one level off: CRITICAL↔HIGH, HIGH↔MEDIUM, MEDIUM↔LOW, LOW↔INFO, INFO↔NONE): 0.3 points
- **Two levels off**: 0 points
- **hot_spot match** (case-insensitive, only scored if severity is not NONE): 0.4 points

**False positive penalty**: If expected severity is NONE but skill reports anything other than NONE, score is 0.0 for that case.

Normalize per-case score to [0.0, 1.0].

## Running the Benchmark

For each case in `corpus/public/`:
1. Read the Solidity file(s)
2. Build the prompt using the invocation above, appending the contract source
3. Run the competing skill with `temperature: 0` and the model specified in the frontmatter
4. Parse the JSON output and evaluate against `expected.json`
5. Record score and log per case

Submit the score log to the platform using the benchmark submission endpoint documented in the platform README.

## Autoresearch Improvement Loop

After scoring, if the overall score < 1.0:
1. Identify which cases the skill misclassified (wrong severity or wrong hot_spot)
2. Distinguish over-reporting (false positives on NONE cases) from under-reporting (missed HIGH/CRITICAL)
3. Propose one targeted edit to the skill's SKILL.md to address the most impactful failure pattern
4. Fork the skill's repository, apply the edit, open a PR with a failure table in the PR body
5. Re-submit a run with `diff_patch` and the fork commit SHA

Only one improvement proposal per benchmark run. Do not push directly to the original repo - always fork first. Clean up `/tmp/skill-improve-<skill-id>` after opening the PR.
