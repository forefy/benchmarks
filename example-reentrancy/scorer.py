#!/usr/bin/env python3
import argparse
import json
import re
import sys


SEVERITY_ORDER = ["none", "low", "medium", "high", "critical"]
FINDING_MATCH_THRESHOLD = 0.6


def severity_score(expected: str, actual: str) -> float:
    try:
        ei = SEVERITY_ORDER.index(expected.lower())
        ai = SEVERITY_ORDER.index(actual.lower())
    except ValueError:
        return 0.0
    diff = abs(ei - ai)
    if diff == 0:
        return 1.0
    if diff == 1:
        return 0.5
    return 0.0


def normalize(text: str) -> str:
    return re.sub(r"[^a-z0-9]", " ", text.lower()).split()


def token_overlap(a: str, b: str) -> float:
    ta = set(normalize(a))
    tb = set(normalize(b))
    if not ta and not tb:
        return 1.0
    if not ta or not tb:
        return 0.0
    return len(ta & tb) / len(ta | tb)


def match_findings(expected_findings: list, actual_findings: list) -> float:
    if not expected_findings and not actual_findings:
        return 1.0
    if not expected_findings:
        return 0.0
    if not actual_findings:
        return 0.0

    matched = 0.0
    used = set()
    for ef in expected_findings:
        best = 0.0
        best_idx = -1
        for i, af in enumerate(actual_findings):
            if i in used:
                continue
            score = token_overlap(ef, af)
            if score > best:
                best = score
                best_idx = i
        if best >= FINDING_MATCH_THRESHOLD:
            matched += best
            if best_idx >= 0:
                used.add(best_idx)

    return matched / len(expected_findings)



def score_case(case: dict, skill_output: dict) -> dict:
    case_id = case["id"]
    expected = case["expected_output"]

    if not isinstance(skill_output, dict):
        return {"id": case_id, "passed": False, "score": 0.0, "reason": "output is not a JSON object"}

    if "findings" not in skill_output or "severity" not in skill_output:
        return {"id": case_id, "passed": False, "score": 0.0, "reason": "missing required fields: findings, severity"}

    if not isinstance(skill_output["findings"], list):
        return {"id": case_id, "passed": False, "score": 0.0, "reason": "findings must be an array"}

    finding_score = match_findings(expected["findings"], skill_output["findings"])
    sev_score = severity_score(expected["severity"], skill_output["severity"])

    combined = (finding_score * 0.7) + (sev_score * 0.3)
    passed = combined >= 0.8

    reason = ""
    if finding_score < 1.0:
        reason = f"finding match {finding_score:.2f}"
    if sev_score < 1.0:
        sep = ", " if reason else ""
        reason += f"{sep}severity mismatch (expected {expected['severity']}, got {skill_output['severity']})"

    return {
        "id": case_id,
        "passed": passed,
        "score": round(combined, 4),
        "reason": reason,
    }


def load_skill_outputs(outputs_path: str) -> dict:
    with open(outputs_path) as f:
        data = json.load(f)
    if isinstance(data, list):
        return {item["id"]: item["output"] for item in data}
    return data


def main():
    parser = argparse.ArgumentParser(description="Score a skill against benchmark cases")
    parser.add_argument("--cases", required=True, help="Path to expected.json")
    parser.add_argument("--skill", required=True, help="Path to skill .md file")
    parser.add_argument(
        "--outputs",
        help="Path to pre-collected skill outputs JSON (list of {id, output}). "
             "If omitted, scorer prints instructions and exits.",
    )
    args = parser.parse_args()

    with open(args.cases) as f:
        cases = json.load(f)

    if not args.outputs:
        print(
            json.dumps({
                "error": "no outputs provided",
                "instructions": (
                    "Run your skill against each case in expected.json and collect outputs. "
                    "Provide results as --outputs path/to/outputs.json where the file is: "
                    "[{\"id\": \"case-001\", \"output\": {\"findings\": [...], \"severity\": \"...\"}}]"
                ),
            }),
            file=sys.stderr,
        )
        sys.exit(1)

    outputs = load_skill_outputs(args.outputs)

    results = []
    for case in cases:
        skill_output = outputs.get(case["id"])
        if skill_output is None:
            results.append({
                "id": case["id"],
                "passed": False,
                "score": 0.0,
                "reason": "no output provided for this case",
            })
        else:
            results.append(score_case(case, skill_output))

    passed = sum(1 for r in results if r["passed"])
    total = len(results)
    overall = round(sum(r["score"] for r in results) / total, 4) if total else 0.0

    output = {
        "score": overall,
        "passed": passed,
        "total": total,
        "results": results,
    }
    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
