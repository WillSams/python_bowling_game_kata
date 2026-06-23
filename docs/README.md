# Python Katas - A Learning Progression

These katas are meant to be worked through **in order**. Each one is a self-contained
shell script that builds a small project from scratch, test-first (red → green →
commit), and each introduces new Python concepts while reinforcing the ones before it.

Every kata follows the same conventions:

- BDD-style specs in `specs/` (`when_*.py` files, `Describe` classes, `should_*` methods)
- Reusable code in a `src/` package
- `black`, `isort`, `flake8`, `mypy`, and `pytest` wired up the same way
- A runnable `main.py` at the end so you can *see* the project work

## The progression

### 1. [Bowling Game](./kata.sh) - TDD fundamentals

Start here. The classic Bob Martin kata teaches the **rhythm of test-driven
development**: write a failing spec, make it pass, refactor, commit. You build a
single `BowlingGame` class incrementally across the nine scoring specs.

**You learn:** the TDD loop, pytest + BDD conventions, basic classes and methods,
loops and conditionals, and how a good test suite lets you refactor fearlessly.

### 2. [File Renamer](./rename-files-kata.sh) - core syntax, procedural style

With the TDD rhythm under your belt, this kata broadens your **core Python syntax**
in a non-OOP (procedural) style. You build a bulk file renamer that normalizes messy
filenames into clean, collision-free slugs.

**You learn:** variables and type hints, loops and conditionals, the core data
structures (list, dict, set, tuple), functions and tuple-unpacking, comprehensions,
generators, context managers, and decorators - plus organizing code into a reusable
package.

### 3. [Soccer Text Adventure](./soccer-adventure-kata.sh) - object-oriented programming

Now apply the same TDD discipline to **OOP**. You model a tiny soccer match engine
(inspired by Captain Tsubasa): players with signature special moves, teams, and a
match that decides a winner.

**You learn:** classes and instance state, encapsulation via properties, inheritance
and polymorphism (a base `Player` with a specialised `Striker`), dunder methods,
dataclasses and enums, classmethods, and composition (a `Match` owns `Team`s that own
`Player`s). The `main.py` is a branching text adventure where your tactical choices
decide the result.

### 4. [Async Chat](./chat-app-kata.sh) - concurrency, asyncio, and the GIL

The capstone tackles **doing more than one thing at a time**. You build a small chat
room that fans messages out to subscribers, then add a threaded counter to make the
GIL trade-off concrete.

**You learn:** `async`/`await` and the event loop, `asyncio.Queue` and `asyncio.gather`,
async context managers and async generators, threading basics with a `Lock`, and a
practical discussion of the Global Interpreter Lock (when threads help and when they
don't). The `main.py` is an interactive chat where a background "peer" task replies to
you.

## How to practice a kata

A kata is practiced through **repetition**, not by running the script. The goal is to
sit at the command line and **type out the steps yourself** - building the project
command by command, writing each failing spec, making it pass, and committing - using
the script as your outline. Repeat the kata until you can do it from memory, with the
script only as a reference when you get stuck.

Becoming fluent in a single kata, able to work through it from memory, may take weeks
or months for new programmers, and days or weeks for those experienced in other
languages. That patience is the point: the repetition is what builds lasting instinct
for the language.

The flow for each kata:

1. Open the script and read it through once to understand the shape of the work.
2. At the command line, recreate the project step by step **by typing**, not copying.
3. Watch the tests go red, then green, at each step - just like the comments say.
4. When you stall, peek at the script (your "answer key"), then keep going.
5. Run it again another day. Fluency comes from doing it repeatedly.

The script is also fully runnable end-to-end if you just want to see the finished
worked example:

```bash
bash docs/rename-files-kata.sh   # for example
```

Each script creates its own project directory, virtual environment, and git history.
