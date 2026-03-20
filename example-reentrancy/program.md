# Reentrancy Detection Benchmark - Optimization Instructions

## Goal

Optimize the skill to detect reentrancy vulnerabilities in Solidity smart contracts as accurately as possible.

## What the skill receives

Each test case provides a Solidity contract source. The skill must analyze it and return a JSON object.

## Required output format

The skill MUST produce valid JSON matching this schema exactly. No extra text outside the JSON object.

```json
{
  "findings": ["description of each finding"],
  "severity": "none|low|medium|high|critical"
}
```

- `findings`: array of strings, one per distinct vulnerability found. Empty array if none.
- `severity`: overall severity of the worst finding. Use "none" if no vulnerabilities found.
- Findings should reference line numbers when possible: "reentrancy at line 42 - external call before state update"

## Scoring

Run the scorer after each iteration:

```bash
python scorer.py --cases expected.json --skill your_skill.md
```

The scorer checks:
- Whether the correct findings are present (partial match allowed - see scorer.py for weights)
- Whether the severity matches

A score of 1.0 means all 25 cases were fully correct.

## Running the skill

For each case in `expected.json`, pass `input.contract` as the contract source to your skill. Collect the JSON output and compare against `expected_output`.

## Tips

- Temperature must be 0 for reproducible results.
- The skill should focus on the check-effects-interactions pattern violation.
- Cross-function and cross-contract reentrancy are in scope.
- Read-only reentrancy is in scope for high-severity cases.
