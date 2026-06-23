#!/bin/bash

# Python Bowling Game Kata
# Based on the classic kata by Bob Martin

#############################################
# 1 - Create a new repo                     #
#############################################

# 1.1 - Create the directory on your local file system
source deactivate
mkdir python-bowling-kata && cd $_

git init .

# 1.2 - Add a .gitignore file to exclude unneeded files
wget -O .gitignore https://raw.githubusercontent.com/github/gitignore/main/Python.gitignore

# 1.3 - Create a virtual environment and activate it
python -m venv venv
source venv/bin/activate  # for Windows: source venv/Scripts/activate

# 1.4 - Install dependencies
pip install pytest pytest-cov black isort flake8 mypy pre-commit

# 1.5 - Pin versions to requirements.txt
pip freeze | grep -E "^(pytest==|pytest-cov==|black==|isort==|flake8==|mypy==|pre-commit==)" > requirements.txt

# 1.6 - Create pytest.ini
cat > pytest.ini << 'EOF'
[pytest]
testpaths = specs/**
python_files = when*.py
python_classes = Describe
python_functions = should_*
EOF

# 1.7 - Create scripts
mkdir scripts

cat > scripts/test.sh << 'EOF'
#!/bin/bash
set -e

export ENV=test
export PYTHONDONTWRITEBYTECODE=1

find . -name "__pycache__" -exec rm -r {} +
python -m pytest
EOF

cat > scripts/test-coverage.sh << 'EOF'
#!/bin/bash
set -e

export ENV=test
export PYTHONDONTWRITEBYTECODE=1

find . -name "__pycache__" -exec rm -r {} +
python -m pytest --cov=src --cov-report term
EOF

cat > scripts/format.sh << 'EOF'
#!/bin/bash
isort --line-length 88 .
black ./
EOF

cat > scripts/lint.sh << 'EOF'
#!/bin/bash
set -e
flake8 src/ specs/
python -m mypy src/
EOF

chmod +x scripts/*.sh

# 1.8 - Configure pre-commit hooks (format + lint on commit, tests on push)
cat > .pre-commit-config.yaml << 'EOF'
repos:
  - repo: https://github.com/pycqa/isort
    rev: 5.13.2
    hooks:
      - id: isort
        args: ["--line-length", "88"]

  - repo: https://github.com/psf/black
    rev: 24.8.0
    hooks:
      - id: black

  - repo: https://github.com/pycqa/flake8
    rev: 7.1.2
    hooks:
      - id: flake8
        files: ^(src|specs)/

  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.14.1
    hooks:
      - id: mypy
        files: ^src/
        pass_filenames: false
        args: ["src/"]

  - repo: local
    hooks:
      - id: pytest
        name: pytest
        entry: ./scripts/test.sh
        language: script
        stages: [pre-push]
        pass_filenames: false
        always_run: true
EOF

pre-commit install
pre-commit install --hook-type pre-push

# 1.9 - Create source and spec directories with initial BowlingGame stub
mkdir -p src specs

touch src/__init__.py

cat > src/bowling_game.py << 'EOF'
class BowlingGame:
    def roll(self, pins: int) -> None:
        pass

    def score(self) -> int:
        return -1
EOF

git add .
git commit -m "Create new bowling kata"

###################################################
# 2 - Write our "0" test - the sanity check       #
###################################################

# 2.1 - Write it to fail
cat > specs/when_bowling_game.py << 'EOF'
from src.bowling_game import BowlingGame


class DescribeBowlingGame:
    def should_be_instantiable(self) -> None:
        game = BowlingGame()
        assert game is None  # intentionally wrong
EOF

python -m pytest  # 1 failed, 1 total

# 2.2 - Write it to pass
sed -i 's/assert game is None/assert game is not None/' specs/when_bowling_game.py

python -m pytest  # 1 passed, 1 total

git add .
git commit -m "Perform the sanity check"

###################################################
# 3 - Spec 1: Scoring basics                      #
#     Gutter game scores zero                     #
###################################################

# 3.1 - Write it to fail
cat > specs/when_bowling_game.py << 'EOF'
from src.bowling_game import BowlingGame


class DescribeBowlingGame:
    def should_be_instantiable(self) -> None:
        game = BowlingGame()
        assert game is not None

    def should_score_zero_for_gutter_game(self) -> None:
        game = BowlingGame()
        for _ in range(20):
            game.roll(0)
        assert game.score() == 0
EOF

python -m pytest  # 1 failed, 1 passed, 2 total

# 3.2 - Write it to pass
cat > src/bowling_game.py << 'EOF'
class BowlingGame:
    def roll(self, pins: int) -> None:
        pass

    def score(self) -> int:
        return 0
EOF

python -m pytest  # 2 passed, 2 total

git add .
git commit -m "Spec 1 - Scoring basics, gutter game scores zero"

###################################################
# 4 - Spec 2: Basic scoring                       #
#     All ones scores twenty                      #
###################################################

# 4.1 - Write it to fail
cat > specs/when_bowling_game.py << 'EOF'
from src.bowling_game import BowlingGame


class DescribeBowlingGame:
    def should_be_instantiable(self) -> None:
        game = BowlingGame()
        assert game is not None

    def should_score_zero_for_gutter_game(self) -> None:
        game = BowlingGame()
        for _ in range(20):
            game.roll(0)
        assert game.score() == 0

    def should_score_twenty_for_all_ones(self) -> None:
        game = BowlingGame()
        for _ in range(20):
            game.roll(1)
        assert game.score() == 20
EOF

python -m pytest  # 1 failed, 2 passed, 3 total

# 4.2 - Write it to pass
cat > src/bowling_game.py << 'EOF'
from typing import List


class BowlingGame:
    def __init__(self) -> None:
        self._rolls: List[int] = []

    def roll(self, pins: int) -> None:
        self._rolls.append(pins)

    def score(self) -> int:
        return sum(self._rolls)
EOF

python -m pytest  # 3 passed, 3 total

git add .
git commit -m "Spec 2 - Basic scoring, all ones scores twenty"

###################################################
# 5 - Keep it DRY, let's refactor                 #
###################################################

# 5.1 - Three additions to reduce duplication:
#       5.1.a - Add setup_method() to create a new BowlingGame before each test
#       5.1.b - Add _roll_many() to handle repetitive roll() calls
#       5.1.c - Add _roll_spare() and _roll_strike() helpers
cat > specs/when_bowling_game.py << 'EOF'
from src.bowling_game import BowlingGame


class DescribeBowlingGame:
    def setup_method(self) -> None:
        self.game = BowlingGame()

    def _roll_many(self, n: int, pins: int) -> None:
        for _ in range(n):
            self.game.roll(pins)

    def _roll_spare(self) -> None:
        self.game.roll(5)
        self.game.roll(5)

    def _roll_strike(self) -> None:
        self.game.roll(10)

    def should_be_instantiable(self) -> None:
        assert self.game is not None

    def should_score_zero_for_gutter_game(self) -> None:
        self._roll_many(20, 0)
        assert self.game.score() == 0

    def should_score_twenty_for_all_ones(self) -> None:
        self._roll_many(20, 1)
        assert self.game.score() == 20
EOF

python -m pytest  # 3 passed, 3 total (no regression)

git add .
git commit -m "Refactor the tests"

###################################################
# 6 - Spec 6: Implement spare scoring             #
###################################################

# 6.1 - Write it to fail
cat > specs/when_bowling_game.py << 'EOF'
from src.bowling_game import BowlingGame


class DescribeBowlingGame:
    def setup_method(self) -> None:
        self.game = BowlingGame()

    def _roll_many(self, n: int, pins: int) -> None:
        for _ in range(n):
            self.game.roll(pins)

    def _roll_spare(self) -> None:
        self.game.roll(5)
        self.game.roll(5)

    def _roll_strike(self) -> None:
        self.game.roll(10)

    def should_be_instantiable(self) -> None:
        assert self.game is not None

    def should_score_zero_for_gutter_game(self) -> None:
        self._roll_many(20, 0)
        assert self.game.score() == 0

    def should_score_twenty_for_all_ones(self) -> None:
        self._roll_many(20, 1)
        assert self.game.score() == 20

    def should_score_spare_plus_next_roll_as_bonus(self) -> None:
        self._roll_spare()
        self.game.roll(3)
        self._roll_many(17, 0)
        assert self.game.score() == 16
EOF

python -m pytest  # 1 failed, 3 passed, 4 total

# 6.2 - Write it to pass
#       sum(self._rolls) returns 13 (5+5+3), not 16.
#       We need frame-based scoring with a spare bonus.
cat > src/bowling_game.py << 'EOF'
from typing import List


class BowlingGame:
    def __init__(self) -> None:
        self._rolls: List[int] = []

    def roll(self, pins: int) -> None:
        self._rolls.append(pins)

    def score(self) -> int:
        total = 0
        roll_index = 0
        for _ in range(10):
            if self._is_spare(roll_index):
                total += 10 + self._spare_bonus(roll_index)
                roll_index += 2
            else:
                total += self._frame_score(roll_index)
                roll_index += 2
        return total

    def _is_spare(self, roll_index: int) -> bool:
        return self._rolls[roll_index] + self._rolls[roll_index + 1] == 10

    def _spare_bonus(self, roll_index: int) -> int:
        return self._rolls[roll_index + 2]

    def _frame_score(self, roll_index: int) -> int:
        return self._rolls[roll_index] + self._rolls[roll_index + 1]
EOF

python -m pytest  # 4 passed, 4 total

git add .
git commit -m "Spec 6 - Implement spare scoring"

###################################################
# 7 - Spec 7/8: Scoring a strike                  #
###################################################

# 7.1 - Write it to fail
cat > specs/when_bowling_game.py << 'EOF'
from src.bowling_game import BowlingGame


class DescribeBowlingGame:
    def setup_method(self) -> None:
        self.game = BowlingGame()

    def _roll_many(self, n: int, pins: int) -> None:
        for _ in range(n):
            self.game.roll(pins)

    def _roll_spare(self) -> None:
        self.game.roll(5)
        self.game.roll(5)

    def _roll_strike(self) -> None:
        self.game.roll(10)

    def should_be_instantiable(self) -> None:
        assert self.game is not None

    def should_score_zero_for_gutter_game(self) -> None:
        self._roll_many(20, 0)
        assert self.game.score() == 0

    def should_score_twenty_for_all_ones(self) -> None:
        self._roll_many(20, 1)
        assert self.game.score() == 20

    def should_score_spare_plus_next_roll_as_bonus(self) -> None:
        self._roll_spare()
        self.game.roll(3)
        self._roll_many(17, 0)
        assert self.game.score() == 16

    def should_score_strike_plus_next_two_rolls_as_bonus(self) -> None:
        self._roll_strike()
        self.game.roll(3)
        self.game.roll(4)
        self._roll_many(16, 0)
        assert self.game.score() == 24
EOF

python -m pytest  # 1 failed, 4 passed, 5 total

# 7.2 - Write it to pass
#       A strike consumes only 1 roll in the frame index, not 2.
cat > src/bowling_game.py << 'EOF'
from typing import List


class BowlingGame:
    def __init__(self) -> None:
        self._rolls: List[int] = []

    def roll(self, pins: int) -> None:
        self._rolls.append(pins)

    def score(self) -> int:
        total = 0
        roll_index = 0
        for _ in range(10):
            if self._is_strike(roll_index):
                total += 10 + self._strike_bonus(roll_index)
                roll_index += 1
            elif self._is_spare(roll_index):
                total += 10 + self._spare_bonus(roll_index)
                roll_index += 2
            else:
                total += self._frame_score(roll_index)
                roll_index += 2
        return total

    def _is_strike(self, roll_index: int) -> bool:
        return self._rolls[roll_index] == 10

    def _is_spare(self, roll_index: int) -> bool:
        return self._rolls[roll_index] + self._rolls[roll_index + 1] == 10

    def _strike_bonus(self, roll_index: int) -> int:
        return self._rolls[roll_index + 1] + self._rolls[roll_index + 2]

    def _spare_bonus(self, roll_index: int) -> int:
        return self._rolls[roll_index + 2]

    def _frame_score(self, roll_index: int) -> int:
        return self._rolls[roll_index] + self._rolls[roll_index + 1]
EOF

python -m pytest  # 5 passed, 5 total

git add .
git commit -m "Spec 7/8 - Implement strike scoring"

###################################################
# 8 - Spec 9: 10th frame                          #
#     Spare or strike earns an extra ball         #
###################################################

# 8.1 - Add tests for 10th frame spare and strike.
#       Notice: no code changes needed!
#       The index-based frame scoring naturally handles the 10th frame.
cat > specs/when_bowling_game.py << 'EOF'
from src.bowling_game import BowlingGame


class DescribeBowlingGame:
    def setup_method(self) -> None:
        self.game = BowlingGame()

    def _roll_many(self, n: int, pins: int) -> None:
        for _ in range(n):
            self.game.roll(pins)

    def _roll_spare(self) -> None:
        self.game.roll(5)
        self.game.roll(5)

    def _roll_strike(self) -> None:
        self.game.roll(10)

    def should_be_instantiable(self) -> None:
        assert self.game is not None

    def should_score_zero_for_gutter_game(self) -> None:
        self._roll_many(20, 0)
        assert self.game.score() == 0

    def should_score_twenty_for_all_ones(self) -> None:
        self._roll_many(20, 1)
        assert self.game.score() == 20

    def should_score_spare_plus_next_roll_as_bonus(self) -> None:
        self._roll_spare()
        self.game.roll(3)
        self._roll_many(17, 0)
        assert self.game.score() == 16

    def should_score_strike_plus_next_two_rolls_as_bonus(self) -> None:
        self._roll_strike()
        self.game.roll(3)
        self.game.roll(4)
        self._roll_many(16, 0)
        assert self.game.score() == 24

    def should_award_extra_roll_in_tenth_frame_for_spare(self) -> None:
        self._roll_many(18, 0)
        self._roll_spare()
        self.game.roll(7)
        assert self.game.score() == 17

    def should_award_two_extra_rolls_in_tenth_frame_for_strike(self) -> None:
        self._roll_many(18, 0)
        self._roll_strike()
        self.game.roll(3)
        self.game.roll(4)
        assert self.game.score() == 17
EOF

python -m pytest  # 7 passed, 7 total

git add .
git commit -m "Spec 9 - 10th frame spare and strike"

###################################################
# 9 - Perfect game scores three hundred           #
###################################################

# 9.1 - Add the perfect game test.
#       This also already passes - the implementation is complete!
cat > specs/when_bowling_game.py << 'EOF'
from src.bowling_game import BowlingGame


class DescribeBowlingGame:
    def setup_method(self) -> None:
        self.game = BowlingGame()

    def _roll_many(self, n: int, pins: int) -> None:
        for _ in range(n):
            self.game.roll(pins)

    def _roll_spare(self) -> None:
        self.game.roll(5)
        self.game.roll(5)

    def _roll_strike(self) -> None:
        self.game.roll(10)

    def should_be_instantiable(self) -> None:
        assert self.game is not None

    def should_score_zero_for_gutter_game(self) -> None:
        self._roll_many(20, 0)
        assert self.game.score() == 0

    def should_score_twenty_for_all_ones(self) -> None:
        self._roll_many(20, 1)
        assert self.game.score() == 20

    def should_score_spare_plus_next_roll_as_bonus(self) -> None:
        self._roll_spare()
        self.game.roll(3)
        self._roll_many(17, 0)
        assert self.game.score() == 16

    def should_score_strike_plus_next_two_rolls_as_bonus(self) -> None:
        self._roll_strike()
        self.game.roll(3)
        self.game.roll(4)
        self._roll_many(16, 0)
        assert self.game.score() == 24

    def should_award_extra_roll_in_tenth_frame_for_spare(self) -> None:
        self._roll_many(18, 0)
        self._roll_spare()
        self.game.roll(7)
        assert self.game.score() == 17

    def should_award_two_extra_rolls_in_tenth_frame_for_strike(self) -> None:
        self._roll_many(18, 0)
        self._roll_strike()
        self.game.roll(3)
        self.game.roll(4)
        assert self.game.score() == 17

    def should_score_three_hundred_for_perfect_game(self) -> None:
        self._roll_many(12, 10)
        assert self.game.score() == 300
EOF

python -m pytest  # 8 passed, 8 total

git add .
git commit -m "Perfect game scores three hundred"

echo "Finis."
