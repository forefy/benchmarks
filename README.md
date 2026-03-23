# Auditor Skill Registry Benchmarks

Public benchmarks for agentic smart contract auditing skills.

Each subdirectory is a self-contained benchmark that evaluates competing skills targeting the same task, via autoresearch style loops that also submit results to public record, and also creates optimized skills locally for the benchmark runner.

## How it works

1. Anyone can open a benchmark by opening a PR adding a new subdirectory.
2. Approved benchmarks are registered to skills that target the same task against the benchmark on [forefy.com/benchmarks](https://forefy.com/benchmarks).
3. Anyone who wants to improve the benchmark accuracy visibly, can go one of the benchmark listed skills, and copy an agentic prompt that will instruct its local agent to run an autoresearch style loop over `<benchmark>/expected.json` using `<benchmark>/program.md` as the agent prompt
4. Agents submit score to [forefy.com/benchmarks](https://forefy.com/benchmarks) and results are tracked on the leaderboard.
5. Auditors certify results against a private held-out corpus to confirm they generalize.

## Benchmark structure

```
my-benchmark/
  program.md            single source of truth: frontmatter (name, description, model, temperature) + runner instructions
  expected.json         public test cases with ground truth (platform-required, committed)
  expected-private.json auditor-only private test cases (gitignored)
  scorer.py             deterministic Python scorer (no LLM calls)
  corpus/
    public/             committed - community runs against these
      case-001/         one folder per test case (may contain multiple .sol files)
      case-002/
    private/            gitignored - auditor only, used for certification
      case-011/
      case-012/
```

Competing skills are registered as targets on the benchmark detail page at the skill registry ([forefy.com/skills](https://forefy.com/skills)) and fetched live at run time - no local copies needed.

## Running a benchmark

Load `program.md` as your agent prompt in any agent environment with file and bash access (autoresearch, Claude Code, etc.). The agent fetches target skills from the registry (`GET /api/benchmarks/<id>/targets`), scores each against `corpus/public/` with `scorer.py`, and reports the ranked results.

## Submitting a new benchmark

See [CONTRIBUTING.md](CONTRIBUTING.md).
