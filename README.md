# forefy/benchmarks

Community benchmark definitions for the [forefy.com/skills](https://forefy.com/skills) auditor skill registry.

Each subdirectory is a self-contained benchmark that evaluates competing skills targeting the same task. Skills are scored on the same test cases and ranked - the benchmark is the arena, the skills are the contestants.

## How it works

1. An auditor publishes a benchmark by opening a PR adding a new subdirectory.
2. Skills that target the same task are registered against the benchmark on [forefy.com/skills/benchmarks](https://forefy.com/skills/benchmarks).
3. Each skill is run against `expected.json` using `program.md` as the agent prompt.
4. Scores are submitted to [forefy.com/skills/benchmarks](https://forefy.com/skills/benchmarks) and ranked on the leaderboard.
5. The benchmark author certifies results against a private held-out corpus to confirm they generalize.

## Benchmark structure

```
my-benchmark/
  program.md            single source of truth: frontmatter (name, description, model, temperature, competing_skills) + runner instructions
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

Competing skills are declared as registry URLs in `program.md` frontmatter and fetched live at run time - no local copies.

## Running a benchmark

Load `program.md` as your agent prompt in any agent environment with file and bash access (autoresearch, Claude Code, etc.). The agent reads `competing_skills` from the frontmatter, fetches each skill from the registry, scores each against `corpus/public/` with `scorer.py`, and reports the ranked results.

## Submitting a new benchmark

See [CONTRIBUTING.md](CONTRIBUTING.md).
