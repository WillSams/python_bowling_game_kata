#!/bin/bash

# Python File Renamer Kata
#
# Teaching focus: core Python syntax in a procedural style.
#   - variables and type hints
#   - loops (for / while) and conditionals (if / elif / else)
#   - data structures: list, dict, set, tuple
#   - functions (args, defaults, *args/**kwargs, return tuples)
#   - comprehensions (list / dict / set) and generators
#   - context managers (with ...) and decorators
#   - project organization: a reusable `renamer` package
#
# The kata builds a bulk file renamer: it scans a directory, plans a set of
# normalized, collision-free names, and applies them. We TDD it the whole way:
# write a failing spec, make it pass, commit.

#############################################
# 1 - Create a new repo                     #
#############################################

# 1.1 - Create the directory and initialize git
deactivate 2>/dev/null || true
rm -rf python-file-renamer-kata && mkdir python-file-renamer-kata && cd $_

git init .

# 1.2 - Ignore Python cruft
wget -O .gitignore https://raw.githubusercontent.com/github/gitignore/main/Python.gitignore

# 1.3 - Virtual environment
python -m venv .venv
source .venv/bin/activate  # for Windows: source .venv/Scripts/activate

# 1.4 - Dependencies (test + quality tooling)
python -m pip install --upgrade pip
pip install pytest pytest-cov black isort flake8 mypy pre-commit
pip freeze | grep -E "^(pytest==|pytest-cov==|black==|isort==|flake8==|mypy==|pre-commit==)" > requirements.txt

# 1.5 - pytest config (same BDD conventions as the bowling kata)
cat > pytest.ini << 'EOF'
[pytest]
testpaths = specs
python_files = when*.py
python_classes = Describe
python_functions = should_*
EOF

# 1.6 - Project layout: a reusable `renamer` package under src/
#       Organizing code as a package (a directory with __init__.py) lets us
#       split responsibilities across modules and import them cleanly.
mkdir -p src/renamer specs
touch src/__init__.py src/renamer/__init__.py

git add .
git commit -m "Create new file renamer kata"

#####################################################
# 2 - Slugify: variables, conditionals, strings     #
#####################################################

# 2.1 - Write it to fail. A spec for normalizing a single filename.
cat >| src/renamer/naming.py <<'EOF'
def slugify(name: str) -> str:
  pass
EOF

cat >| specs/when_normalizing_a_filename.py << 'EOF'
from src.renamer.naming import slugify


class DescribeSlugify:
    def should_lowercase_and_replace_spaces_with_hyphens(self) -> None:
        assert slugify("My Vacation Photo.JPG") == "my-vacation-photo.jpg"
EOF

python -m pytest  # fail - AssertionError: assert None == 'my-vacation-photo.jpg'

# 2.2 - Write it to pass.
#       `slugify` shows: variables, a conditional, string methods, and the
#       str.maketrans/translate idiom. Note the explicit return type hint.
cat >| src/renamer/naming.py << 'EOF'
import re

# A module-level constant (UPPER_SNAKE_CASE by convention) compiled once.
_INVALID = re.compile(r"[^a-z0-9.]+")


def slugify(name: str) -> str:
    # Variables are just names bound to values - no declaration keyword.
    lowered = name.strip().lower()

    # Collapse any run of "invalid" characters down to a single hyphen.
    slug = _INVALID.sub("-", lowered)

    # A conditional to trim stray hyphens off the ends.
    if slug.startswith("-"):
        slug = slug[1:]
    if slug.endswith("-"):
        slug = slug[:-1]

    return slug
EOF

python -m pytest  # 1 passed

git add .
git commit -m "Add slugify for single filename normalization"

#####################################################
# 3 - Split name + extension: tuples and unpacking   #
#####################################################

# 3.1 - Add a spec. We want to keep the extension intact while slugging.
#       Rewrite naming.py with a failing stub beside the existing slugify.
cat >| src/renamer/naming.py <<'EOF'
from __future__ import annotations  # builtin generics (tuple[...]) on Py3.8+

import re

# A module-level constant (UPPER_SNAKE_CASE by convention) compiled once.
_INVALID = re.compile(r"[^a-z0-9.]+")


def slugify(name: str) -> str:
    # Variables are just names bound to values - no declaration keyword.
    lowered = name.strip().lower()

    # Collapse any run of "invalid" characters down to a single hyphen.
    slug = _INVALID.sub("-", lowered)

    # A conditional to trim stray hyphens off the ends.
    if slug.startswith("-"):
        slug = slug[1:]
    if slug.endswith("-"):
        slug = slug[:-1]

    return slug


def split_extension(name: str) -> tuple[str, str]:
    pass
EOF

cat >> specs/when_normalizing_a_filename.py << 'EOF'


class DescribeSplitExtension:
    def should_return_stem_and_suffix_as_a_tuple(self) -> None:
        from src.renamer.naming import split_extension

        stem, suffix = split_extension("Report Final.PDF")
        assert stem == "Report Final"
        assert suffix == ".pdf"
EOF

python -m pytest  # 1 failed, 1 passed -  TypeError: cannot unpack non-iterable NoneType object

# 3.2 - Implement it. Functions can return multiple values as a tuple, which
#       the caller unpacks: `stem, suffix = split_extension(...)`.
cat >| src/renamer/naming.py << 'EOF'
from __future__ import annotations  # builtin generics (tuple[...]) on Py3.8+

import re

# A module-level constant (UPPER_SNAKE_CASE by convention) compiled once.
_INVALID = re.compile(r"[^a-z0-9.]+")


def slugify(name: str) -> str:
    # Variables are just names bound to values - no declaration keyword.
    lowered = name.strip().lower()

    # Collapse any run of "invalid" characters down to a single hyphen.
    slug = _INVALID.sub("-", lowered)

    # A conditional to trim stray hyphens off the ends.
    if slug.startswith("-"):
        slug = slug[1:]
    if slug.endswith("-"):
        slug = slug[:-1]

    return slug


def split_extension(name: str) -> tuple[str, str]:
    dot = name.rfind(".")
    if dot <= 0:  # no extension (or a dotfile like ".bashrc")
        return name, ""
    # Returning a tuple - parentheses are optional but shown for clarity.
    return (name[:dot], name[dot:].lower())
EOF

python -m pytest  # 2 passed

git add .
git commit -m "Add split_extension returning a (stem, suffix) tuple"

#####################################################
# 4 - Plan renames: dicts, sets, comprehensions      #
#####################################################

# 4.1 - The heart of the kata. Given a list of filenames, build a plan that
#       maps old -> new, guaranteeing the new names do not collide. A spare
#       collision gets a numeric suffix (-1, -2, ...).
cat > specs/when_planning_renames.py << 'EOF'
from src.renamer.plan import plan_renames


class DescribePlanRenames:
    def should_map_each_original_name_to_a_slugified_name(self) -> None:
        plan = plan_renames(["My File.TXT", "Another One.md"])
        assert plan == {
            "My File.TXT": "my-file.txt",
            "Another One.md": "another-one.md",
        }

    def should_disambiguate_colliding_target_names(self) -> None:
        # Both slug to "report.txt" - the second must be made unique.
        plan = plan_renames(["Report.txt", "REPORT.txt"])
        assert plan == {
            "Report.txt": "report.txt",
            "REPORT.txt": "report-1.txt",
        }
EOF

python -m pytest specs/when_planning_renames.py  # fail - module missing

# 4.2 - Implement it. This is where data structures shine:
#         - a dict for the old -> new plan
#         - a set to track names already taken (fast membership tests)
#         - a loop with conditionals to resolve collisions
cat > src/renamer/plan.py << 'EOF'
from __future__ import annotations  # builtin generics (list/dict[...]) on Py3.8+

from src.renamer.naming import slugify, split_extension


def plan_renames(filenames: list[str]) -> dict[str, str]:
    plan: dict[str, str] = {}
    taken: set[str] = set()  # sets give O(1) "in" checks and no duplicates

    for original in filenames:
        target = slugify(original)

        # If the slug is already taken, append -1, -2, ... before the suffix.
        if target in taken:
            stem, suffix = split_extension(target)
            counter = 1
            candidate = f"{stem}-{counter}{suffix}"
            while candidate in taken:  # a while-loop driven by a condition
                counter += 1
                candidate = f"{stem}-{counter}{suffix}"
            target = candidate

        plan[original] = target
        taken.add(target)

    return plan
EOF

python -m pytest  # all green

git add .
git commit -m "Add plan_renames using dict + set for collision-free planning"

#####################################################
# 5 - Walking a tree: a generator                    #
#####################################################

# 5.1 - Spec a generator that yields files lazily. Generators produce values
#       one at a time with `yield`, so we never hold the whole tree in memory.
cat > specs/when_scanning_a_directory.py << 'EOF'
import os

from src.renamer.scan import iter_files


class DescribeIterFiles:
    def should_yield_only_files_not_directories(self, tmp_path) -> None:
        (tmp_path / "a.txt").write_text("a")
        (tmp_path / "sub").mkdir()
        (tmp_path / "sub" / "b.txt").write_text("b")

        names = sorted(os.path.basename(p) for p in iter_files(str(tmp_path)))
        assert names == ["a.txt", "b.txt"]
EOF

python -m pytest specs/when_scanning_a_directory.py  # fail - module missing

# 5.2 - Implement the generator. Calling it returns a lazy iterator; the body
#       runs only as the caller iterates. Great for large directory trees.
cat > src/renamer/scan.py << 'EOF'
import os
from typing import Iterator


def iter_files(root: str) -> Iterator[str]:
    # os.walk itself is a generator; we re-yield the file paths from it.
    for dirpath, _dirnames, filenames in os.walk(root):
        for name in filenames:
            yield os.path.join(dirpath, name)
EOF

python -m pytest  # all green

git add .
git commit -m "Add iter_files generator for lazy directory scanning"

#####################################################
# 6 - Applying renames: context manager + decorator  #
#####################################################

# 6.1 - We want a dry-run mode and audit logging. Spec the behavior first.
cat > specs/when_applying_a_plan.py << 'EOF'
from src.renamer.apply import apply_plan


class DescribeApplyPlan:
    def should_rename_files_on_disk(self, tmp_path) -> None:
        original = tmp_path / "My File.TXT"
        original.write_text("hello")

        plan = {str(original): "my-file.txt"}
        apply_plan(plan, dry_run=False)

        assert not original.exists()
        assert (tmp_path / "my-file.txt").read_text() == "hello"

    def should_not_touch_disk_in_dry_run(self, tmp_path) -> None:
        original = tmp_path / "My File.TXT"
        original.write_text("hello")

        plan = {str(original): "my-file.txt"}
        applied = apply_plan(plan, dry_run=True)

        assert original.exists()              # untouched
        assert applied == [(str(original), "my-file.txt")]
EOF

python -m pytest specs/when_applying_a_plan.py  # fail - module missing

# 6.2 - Implement it using two new tools:
#         - a DECORATOR (`@audit`) that wraps the function to log call counts
#         - a CONTEXT MANAGER (`dry_run_guard`) built with @contextmanager
cat > src/renamer/apply.py << 'EOF'
from __future__ import annotations  # builtin generics (list/dict[...]) on Py3.8+

import functools
import os
from contextlib import contextmanager
from typing import Callable, Iterator, TypeVar

F = TypeVar("F", bound=Callable[..., object])


def audit(func: F) -> F:
    # A decorator is a function that takes a function and returns a wrapper.
    # functools.wraps copies the original name/docstring onto the wrapper.
    @functools.wraps(func)
    def wrapper(*args: object, **kwargs: object) -> object:
        result = func(*args, **kwargs)
        wrapper.calls += 1  # type: ignore[attr-defined]
        return result

    wrapper.calls = 0  # type: ignore[attr-defined]
    return wrapper  # type: ignore[return-value]


@contextmanager
def dry_run_guard(dry_run: bool) -> Iterator[None]:
    # Everything before `yield` is setup; after it is teardown. The caller's
    # `with` block runs in between. Here we simply announce the mode.
    mode = "DRY-RUN" if dry_run else "LIVE"
    print(f"[renamer] entering {mode} mode")
    try:
        yield
    finally:
        print(f"[renamer] leaving {mode} mode")


@audit
def apply_plan(
    plan: dict[str, str], dry_run: bool = True
) -> list[tuple[str, str]]:
    applied: list[tuple[str, str]] = []

    with dry_run_guard(dry_run):
        for old_path, new_name in plan.items():
            new_path = os.path.join(os.path.dirname(old_path), new_name)
            if not dry_run:
                os.rename(old_path, new_path)
            applied.append((old_path, new_name))

    return applied
EOF

python -m pytest  # all green

git add .
git commit -m "Apply renames with an @audit decorator and dry-run context manager"

#####################################################
# 7 - Tie it together: a reusable package API        #
#####################################################

# 7.1 - Expose a clean public API from the package __init__ so callers can do
#       `from src.renamer import rename_directory`. This is good package
#       hygiene - the package decides what is public.
cat > specs/when_renaming_a_directory.py << 'EOF'
import os

from src.renamer import rename_directory


class DescribeRenameDirectory:
    def should_normalize_every_file_in_a_directory(self, tmp_path) -> None:
        (tmp_path / "My File.TXT").write_text("x")
        (tmp_path / "Another One.MD").write_text("y")

        rename_directory(str(tmp_path), dry_run=False)

        names = sorted(os.listdir(str(tmp_path)))
        assert names == ["another-one.md", "my-file.txt"]
EOF

python -m pytest specs/when_renaming_a_directory.py  # fail - not wired up yet

# 7.2 - Implement the façade and re-export it from the package.
cat > src/renamer/facade.py << 'EOF'
from __future__ import annotations  # builtin generics (list/tuple[...]) on Py3.8+

import os

from src.renamer.apply import apply_plan
from src.renamer.plan import plan_renames
from src.renamer.scan import iter_files


def rename_directory(root: str, dry_run: bool = True) -> list[tuple[str, str]]:
    # Keep each file's real path (it may live in a subdirectory) so apply_plan
    # renames it in place; only the basename is slugified.
    paths = list(iter_files(root))
    name_to_target = plan_renames([os.path.basename(p) for p in paths])

    # Map every real path to its slugified basename via a dict comprehension.
    full_plan = {path: name_to_target[os.path.basename(path)] for path in paths}
    return apply_plan(full_plan, dry_run=dry_run)
EOF

cat > src/renamer/__init__.py << 'EOF'
from src.renamer.facade import rename_directory
from src.renamer.naming import slugify, split_extension
from src.renamer.plan import plan_renames

__all__ = ["rename_directory", "slugify", "split_extension", "plan_renames"]
EOF

python -m pytest  # all green

git add .
git commit -m "Expose rename_directory as the package public API"

#####################################################
# 8 - A runnable entry point: main.py                #
#####################################################

# 8.1 - An INTERACTIVE before/after demo of the renamer. It seeds a folder with
#       deliberately messy filenames, previews the clean, collision-free plan,
#       and (on confirmation) renames them on disk - so you can SEE the point:
#       "My Vacation Photo.JPG" becomes "my-vacation-photo.jpg".
#
#       All the prompting lives here in main.py; the tested `renamer` package is
#       reused as-is via its public rename_directory() API. Re-running resets the
#       demo folder so the transformation is always visible; a directory you name
#       yourself is operated on as-is (never reset).
cat > main.py << 'EOF'
import os
import shutil

from src.renamer import rename_directory

DEMO_DIR = "sample_files"
SAMPLE_FILES = [
    "My Vacation Photo.JPG",
    "Report Final.PDF",
    "report final.pdf",  # collides with the line above once slugified
    "Notes (draft) v2.TXT",
]


def reset_demo_dir() -> None:
    # Start every demo run from the same messy state so the rename is visible.
    if os.path.isdir(DEMO_DIR):
        shutil.rmtree(DEMO_DIR)
    os.makedirs(DEMO_DIR)
    for name in SAMPLE_FILES:
        with open(os.path.join(DEMO_DIR, name), "w") as handle:
            handle.write("demo")


def list_dir(label: str, path: str) -> None:
    print(label)
    for name in sorted(os.listdir(path)):
        print(f"  {name}")


def main() -> None:
    print("Renamer: turn messy filenames into clean, lowercase, hyphenated,")
    print("collision-free names.\n")

    target = input(f"Directory to tidy [{DEMO_DIR}]: ").strip() or DEMO_DIR
    if target == DEMO_DIR:
        reset_demo_dir()  # repeatable demo - refill with messy sample files

    list_dir(f"\nBefore - '{target}' contains:", target)

    plan = rename_directory(target, dry_run=True)

    # Keep only entries that actually change - a file already matching its slug
    # would otherwise show a pointless "name -> same-name" line.
    changes = [(old, new) for old, new in plan if os.path.basename(old) != new]
    if not changes:
        print("\nNothing to rename - everything is already tidy.")
        return

    print("\nProposed renames:")
    for old_path, new_name in changes:
        print(f"  {os.path.basename(old_path)} -> {new_name}")

    answer = input("\nApply these renames? [y/N]: ").strip().lower()
    if answer == "y":
        rename_directory(target, dry_run=False)
        list_dir(f"\nAfter - '{target}' contains:", target)
    else:
        print("Left untouched.")


if __name__ == "__main__":
    main()
EOF

# Run it interactively with `python main.py`. Here we accept the default
# directory and confirm the renames so the kata script stays non-interactive.
printf '\ny\n' | python main.py

git add .
git commit -m "Add runnable main.py entry point"

echo "Finis."
