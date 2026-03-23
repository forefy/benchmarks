"""
Scorer for foundry-poc benchmark.

Usage: python scorer.py <output.json> <expected.json>

output.json must contain:
  {"pocs": [{"case_id": "...", "poc_code": "...", "vulnerability_type": "..."}, ...]}

Scoring per case (max 1.0):
  - PoC compiles (forge build succeeds): 0.3 pts
  - Test passes (forge test exits 0): 0.5 pts
  - funds_drained_wei > 0 logged in output: 0.2 pts

Requires: forge (Foundry) installed and on PATH.

Returns a float 0.0-1.0 printed to stdout.
Exit code 0 on success, 1 on error.
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

FOUNDRY_TOML = """\
[profile.default]
src = "src"
test = "test"
out = "out"
libs = []
solc_version = "0.8.24"
"""


def load_json(path: str):
    with open(path) as f:
        return json.load(f)


def check_forge() -> bool:
    return shutil.which("forge") is not None


def run_forge_test(poc_code: str) -> tuple[bool, bool, bool]:
    """
    Returns (compiles, test_passes, funds_logged).
    """
    tmpdir = tempfile.mkdtemp(prefix="foundry_poc_")
    try:
        src_dir = os.path.join(tmpdir, "src")
        test_dir = os.path.join(tmpdir, "test")
        os.makedirs(src_dir)
        os.makedirs(test_dir)

        with open(os.path.join(tmpdir, "foundry.toml"), "w") as f:
            f.write(FOUNDRY_TOML)

        test_file = os.path.join(test_dir, "PoCTest.t.sol")
        with open(test_file, "w") as f:
            f.write(poc_code)

        build_result = subprocess.run(
            ["forge", "build", "--root", tmpdir],
            capture_output=True,
            text=True,
            timeout=60,
        )
        compiles = build_result.returncode == 0

        if not compiles:
            return False, False, False

        test_result = subprocess.run(
            ["forge", "test", "--root", tmpdir, "--match-test", "testExploit", "-v"],
            capture_output=True,
            text=True,
            timeout=120,
        )
        test_passes = test_result.returncode == 0

        combined_output = test_result.stdout + test_result.stderr
        funds_logged = bool(
            re.search(r"funds_drained_wei[^\d]*([1-9]\d*)", combined_output)
        )

        return compiles, test_passes, funds_logged

    except subprocess.TimeoutExpired:
        return False, False, False
    except Exception:
        return False, False, False
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def score_case(poc_code: str | None) -> float:
    if not poc_code or not poc_code.strip():
        return 0.0

    compiles, test_passes, funds_logged = run_forge_test(poc_code)

    score = 0.0
    if compiles:
        score += 0.3
    if test_passes:
        score += 0.5
    if funds_logged:
        score += 0.2

    return score


def main() -> None:
    if len(sys.argv) != 3:
        print("Usage: python scorer.py <output.json> <expected.json>", file=sys.stderr)
        sys.exit(1)

    if not check_forge():
        print("Error: forge not found on PATH. Install Foundry to run this scorer.", file=sys.stderr)
        sys.exit(1)

    output_path, expected_path = sys.argv[1], sys.argv[2]

    try:
        output_data = load_json(output_path)
        expected_data = load_json(expected_path)
    except (json.JSONDecodeError, FileNotFoundError) as e:
        print(f"Error loading files: {e}", file=sys.stderr)
        sys.exit(1)

    if not isinstance(expected_data, list):
        print("expected.json must be a JSON array", file=sys.stderr)
        sys.exit(1)

    pocs: list[dict] = output_data.get("pocs", [])
    poc_by_id: dict[str, str] = {
        p["case_id"]: p.get("poc_code", "")
        for p in pocs
        if "case_id" in p
    }

    total_cases = len(expected_data)
    if total_cases == 0:
        print("1.0")
        return

    total_score = 0.0
    for case in expected_data:
        case_id = case.get("id", "")
        poc_code = poc_by_id.get(case_id)
        case_score = score_case(poc_code)
        total_score += case_score
        print(f"  {case_id}: {case_score:.2f}", file=sys.stderr)

    final_score = total_score / total_cases
    print(f"{final_score:.4f}")


if __name__ == "__main__":
    main()
