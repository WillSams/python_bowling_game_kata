# Bowling Game - A Python TDD Story

The now classic bowling game kata by Bob Martin.  This is a great kata to practice TDD and BDD.  The kata is described in detail within the [Agile Principles, Patterns, and Practices in C#][1] book and a slide deck can be found on [Bob Martin's web site][2].

## Specification

Before we write a single line of code, let's write our "specs".  What are we attempting to design?

    1) Scoring basics - 10 frames, 10 pins used for scoring, minimum score is 0 and a max is 300.
    2) Implement basic scoring - 10 frames of 2 rolls each.  Normal rolls are 1 point per pin.
    3) Strikes and spare strikes - 1 roll to knock all 10 are strikes (X), 2 rolls to knock all 10 are spares (/).
    4) Scoring strikes - If first throw, (10+a).  If spare, 10 + a.  Max 30 for first, max 20 for second.
    5) Focus on frames for scoring - score is a sum of individual frames.  Note: strikes causes frame crossover.
    6) Implement spare scoring - Spare scoring crossing frames still count for that frame.
    7) Scoring a strike - Finish implementing logic from #3.
    8) Implement scoring considering strikes - Strike scoring crossing frames still count for that frame.
    9) 10th Frame - If strike or spare is rolled, bowler gets extra ball.  This should make it 21 or less rolls.

**Table of Contents**:

* [Prerequisites](#prerequisites)
* [Getting Started](#getting-started)
* [Scripts](#scripts)
* [More Katas](#more-katas)
* [CI](#ci)
* [License](#license)

## Prerequisites

* [Python 3](https://www.python.org/)
* [pip](https://pip.pypa.io/en/stable/)

## Getting Started

Execute the following in your terminal:

```bash
python -m venv venv
source venv/bin/activate  # for Windows, source venv/Scripts/activate
python -m pip install --upgrade pip
pip install -r requirements.txt
```

## Scripts

The project includes BDD-style tests organized for improved readability and comprehension.  Tests live in the `specs/` directory and follow RSpec-inspired conventions: spec files are named `when_*.py`, test classes are named `Describe`, and test methods are named `should_*`.

To run the tests: `./scripts/test.sh`

To run tests with coverage: `./scripts/test-coverage.sh`

To format code: `./scripts/format.sh`

To lint: `./scripts/lint.sh`

Note: formatting and linting will occur whenever you commit code via the [pre-commit](https://pypi.org/project/pre-commit/) package.  You can also run these scripts manually to check for issues before committing. There is also configuration to run tests on pre-push in [.pre-commit-config.yaml](./.pre-commit-config.yaml) to block pushes remotely if tests fail locally.

## More Katas

The Bowling Game is the first step in a larger learning progression. The [`docs/`](./docs/README.md) folder contains a series of additional katas, each a self-contained shell script that builds a small project test-first while introducing new Python concepts:

1. [Bowling Game](./docs/kata.sh) — TDD fundamentals (this kata)
2. [File Renamer](./docs/additional_katas/rename-files-kata.sh) — core syntax in a procedural style
3. [Soccer Text Adventure](./docs/additional_katas/soccer-adventure-kata.sh) — object-oriented programming
4. [Async Chat](./docs/additional_katas/chat-app-kata.sh) — concurrency, asyncio, and the GIL

See [docs/README.md](./docs/README.md) for the full progression and how to practice a kata.

## CI

The project uses GitHub Actions for continuous integration.

- **[pr-validate.yml](./.github/workflows/pr-validate.yml)** — runs on every push and pull request to `main`: installs dependencies, lints with Flake8, and runs the full test suite
- **[branch-name-check.yml](./.github/workflows/branch-name-check.yml)** — enforces semantic branch naming on pull requests (e.g. `feat/`, `fix/`, `chore/`)
- **[dependabot.yml](./.github/dependabot.yml)** — automatically opens weekly PRs to keep pip dependencies up to date

## License

License information can be found in [LICENSE.md](./LICENSE.md)

[1]: https://www.goodreads.com/book/show/84983.Agile_Principles_Patterns_and_Practices_in_C_
[2]: http://butunclebob.com/ArticleS.UncleBob.TheBowlingGameKata
