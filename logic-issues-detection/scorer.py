"""
Scorer for logic-issues-detection benchmark.

Usage: python scorer.py <output.json> <expected.json>

output.json must contain:
  {"findings": [{"case_id": "...", "vulnerable": bool, "vulnerability_type": "...", "affected_function": "...", "explanation": "..."}, ...]}

Returns a float 0.0-1.0 printed to stdout.
Exit code 0 on success, 1 on error.
"""

import json
import sys


def load_json(path: str) -> dict:
    with open(path) as f:
        return json.load(f)


def normalize(s: str) -> str:
    return s.strip().lower().replace(" ", "_").replace("-", "_")


def score_case(output: dict, expected: dict) -> float:
    """
    Scoring per case (max 1.0):
      - vulnerable flag correct: 0.5 pts
      - if vulnerable=True: affected_function correct adds 0.3 pts
      - if vulnerable=True: vulnerability_type correct adds 0.2 pts
    Non-vulnerable cases: only the vulnerable flag matters (0.5 each, normalized to 1.0).
    """
    is_vuln_expected = expected.get("vulnerable", False)
    is_vuln_output = output.get("vulnerable", False)

    if not is_vuln_expected:
        return 1.0 if not is_vuln_output else 0.0

    if not is_vuln_output:
        return 0.0

    score = 0.5

    exp_fn = normalize(expected.get("affected_function", ""))
    out_fn = normalize(output.get("affected_function", ""))
    if exp_fn and out_fn and exp_fn == out_fn:
        score += 0.3

    exp_type = normalize(expected.get("vulnerability_type", ""))
    out_type = normalize(output.get("vulnerability_type", ""))
    if exp_type and out_type and exp_type == out_type:
        score += 0.2

    return score


def main() -> None:
    if len(sys.argv) != 3:
        print("Usage: python scorer.py <output.json> <expected.json>", file=sys.stderr)
        sys.exit(1)

    output_path, expected_path = sys.argv[1], sys.argv[2]

    try:
        output_data = load_json(output_path)
        expected_data = load_json(expected_path)
    except (json.JSONDecodeError, FileNotFoundError) as e:
        print(f"Error loading files: {e}", file=sys.stderr)
        sys.exit(1)

    output_findings: list[dict] = output_data.get("findings", [])
    output_by_id: dict[str, dict] = {f["case_id"]: f for f in output_findings if "case_id" in f}

    if not isinstance(expected_data, list):
        print("expected.json must be a JSON array", file=sys.stderr)
        sys.exit(1)

    total_cases = len(expected_data)
    if total_cases == 0:
        print("1.0")
        return

    total_score = 0.0
    for case in expected_data:
        case_id = case.get("id", "")
        expected_output = case.get("expected_output", {})
        output = output_by_id.get(case_id, {})
        total_score += score_case(output, expected_output)

    final_score = total_score / total_cases
    print(f"{final_score:.4f}")


if __name__ == "__main__":
    main()
