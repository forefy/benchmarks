# forefy/benchmarks

Community benchmark definitions for the [forefy.com](https://forefy.com) auditor skill registry.

Each subdirectory is a self-contained benchmark that targets a specific skill category. Benchmarks define the evaluation protocol used to score auditor skills on forefy.com.

## How it works

1. An auditor publishes a benchmark by opening a PR adding a new subdirectory.
2. The community runs the benchmark against their fork of a skill to optimize it.
3. Results (diff, score, model used) are submitted to forefy.com for certification.
4. The auditor certifies results using a private held-out corpus.

## Benchmark structure

```
my-benchmark/
  SKILL.md        skill definition (category: benchmark)
  program.md      natural language instructions for the optimization agent
  expected.json   25 public test cases with ground truth
  scorer.py       deterministic Python scorer (no LLM calls)
  config.json     benchmark metadata and output schema
```

## Running a benchmark

Any agent environment works (Claude Code, Gemini CLI, autoresearch, manual):

1. Read `program.md` for instructions.
2. Run the skill against each case in `expected.json`.
3. Collect skill outputs as JSON matching the schema in `config.json`.
4. Score your run: `python scorer.py --cases expected.json --skill your_skill.md`
5. Submit the diff + score at forefy.com/benchmarks.

## Submitting a new benchmark

See [CONTRIBUTING.md](CONTRIBUTING.md).
