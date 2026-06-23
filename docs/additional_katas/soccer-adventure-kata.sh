#!/bin/bash

# Python Soccer Text Adventure Kata (OOP)
#
# Teaching focus: object-oriented programming in Python.
#   - classes, instances, __init__, and instance state
#   - encapsulation via properties and "private" (_underscore) attributes
#   - inheritance and polymorphism (a base Player with specialised subclasses)
#   - dunder methods (__str__, __repr__, __eq__)
#   - dataclasses and enums for clean value objects
#   - classmethods / staticmethods as alternative constructors and helpers
#   - composition (a Match owns Teams; a Team owns Players)
#   - project organization: a `pitch` package split by responsibility
#
# Inspired by Captain Tsubasa: players have signature "special moves" and a
# stamina cost. We TDD a tiny match engine: write a failing spec, pass, commit.

#############################################
# 1 - Create a new repo                     #
#############################################

source deactivate
rm -rf python-soccer-adventure-kata && mkdir python-soccer-adventure-kata && cd $_

git init .
wget -O .gitignore https://raw.githubusercontent.com/github/gitignore/main/Python.gitignore

python -m venv .venv
source .venv/bin/activate  # for Windows: source .venv/Scripts/activate

# Skip writing .pyc files. With `testpaths = specs/**`, a stale __pycache__
# would otherwise get globbed by pytest on repeated runs and break collection.
export PYTHONDONTWRITEBYTECODE=1

# faker generates the demo player names/countries used by main.py
python -m pip install --upgrade pip
pip install pytest pytest-cov black isort flake8 mypy pre-commit faker
pip freeze | grep -E "^(pytest==|pytest-cov==|black==|isort==|flake8==|mypy==|pre-commit==|[Ff]aker==)" > requirements.txt

cat > pytest.ini << 'EOF'
[pytest]
testpaths = specs/**
python_files = when*.py
python_classes = Describe
python_functions = should_*
EOF

# Package layout: `pitch` holds the domain model, split into modules.
mkdir -p src/pitch specs
touch src/__init__.py src/pitch/__init__.py

git add .
git commit -m "Create new soccer adventure kata"

#####################################################
# 2 - Value objects: enums and dataclasses           #
#####################################################

# 2.1 - Positions are a fixed set, so model them with an Enum. A SpecialMove is
#       an immutable value object, perfect for a frozen dataclass.
cat > specs/when_creating_value_objects.py << 'EOF'
from src.pitch.types import Position, SpecialMove


class DescribePosition:
    def should_expose_named_positions(self) -> None:
        assert Position.FORWARD.value == "FW"
        assert Position.GOALKEEPER.value == "GK"


class DescribeSpecialMove:
    def should_be_immutable_and_comparable(self) -> None:
        drive = SpecialMove(name="Drive Shot", power=9, stamina_cost=4)
        same = SpecialMove(name="Drive Shot", power=9, stamina_cost=4)
        # Frozen dataclasses get __eq__ and __hash__ for free.
        assert drive == same
EOF

python -m pytest specs/when_creating_value_objects.py  # fail - module missing

# 2.2 - Implement them.
cat > src/pitch/types.py << 'EOF'
from dataclasses import dataclass
from enum import Enum


class Position(Enum):
    # An Enum gives named, singleton members - no magic strings scattered about.
    FORWARD = "FW"
    MIDFIELDER = "MF"
    DEFENDER = "DF"
    GOALKEEPER = "GK"


@dataclass(frozen=True)
class SpecialMove:
    # frozen=True makes instances immutable and hashable; the decorator also
    # generates __init__, __repr__, and __eq__ for us.
    name: str
    power: int
    stamina_cost: int
EOF

python -m pytest  # green

git add .
git commit -m "Add Position enum and SpecialMove dataclass"

#####################################################
# 3 - The Player base class: state + properties      #
#####################################################

# 3.1 - A Player has a name, position, and stamina. Stamina is encapsulated:
#       you can read it via a property but only change it through methods.
cat > specs/when_a_player_exerts_effort.py << 'EOF'
from src.pitch.types import Position
from src.pitch.player import Player


class DescribePlayer:
    def should_start_with_full_stamina(self) -> None:
        tsubasa = Player("Tsubasa", Position.FORWARD)
        assert tsubasa.stamina == 100

    def should_tire_when_exerting_effort(self) -> None:
        tsubasa = Player("Tsubasa", Position.FORWARD)
        tsubasa.exert(30)
        assert tsubasa.stamina == 70

    def should_never_drop_below_zero_stamina(self) -> None:
        tsubasa = Player("Tsubasa", Position.FORWARD)
        tsubasa.exert(250)
        assert tsubasa.stamina == 0

    def should_render_readably(self) -> None:
        tsubasa = Player("Tsubasa", Position.FORWARD)
        assert str(tsubasa) == "Tsubasa (FW) - 100 stamina"
EOF

python -m pytest specs/when_a_player_exerts_effort.py  # fail - module missing

# 3.2 - Implement the base class. Note the "_stamina" private attribute guarded
#       by a read-only @property, and the __str__ dunder for friendly output.
cat > src/pitch/player.py << 'EOF'
from src.pitch.types import Position


class Player:
    def __init__(self, name: str, position: Position) -> None:
        self.name = name
        self.position = position
        # A leading underscore signals "internal" - touch via methods/property.
        self._stamina = 100

    @property
    def stamina(self) -> int:
        # A property exposes _stamina for reading without a method call,
        # while keeping the setter logic under our control.
        return self._stamina

    def exert(self, cost: int) -> None:
        # max(...) clamps stamina so it never goes negative.
        self._stamina = max(0, self._stamina - cost)

    def shoot(self) -> int:
        # Base shot is a plain effort. Subclasses will override (polymorphism).
        self.exert(5)
        return 5

    def __str__(self) -> str:
        return f"{self.name} ({self.position.value}) - {self.stamina} stamina"

    def __repr__(self) -> str:
        return f"Player(name={self.name!r}, position={self.position!r})"
EOF

python -m pytest  # green

git add .
git commit -m "Add Player base class with encapsulated stamina"

#####################################################
# 4 - Inheritance + polymorphism: the Striker         #
#####################################################

# 4.1 - A Striker knows a SpecialMove and can unleash it for extra power, at a
#       stamina cost. It overrides shoot(), demonstrating polymorphism: code
#       that calls player.shoot() behaves differently per subclass.
cat > specs/when_a_striker_shoots.py << 'EOF'
from src.pitch.types import Position, SpecialMove
from src.pitch.player import Player
from src.pitch.striker import Striker


class DescribeStriker:
    def should_be_a_player(self) -> None:
        drive = SpecialMove("Drive Shot", power=9, stamina_cost=4)
        tsubasa = Striker("Tsubasa", drive)
        # A Striker *is a* Player (Liskov substitution).
        assert isinstance(tsubasa, Player)
        assert tsubasa.position == Position.FORWARD

    def should_shoot_harder_than_a_base_player(self) -> None:
        drive = SpecialMove("Drive Shot", power=9, stamina_cost=4)
        tsubasa = Striker("Tsubasa", drive)
        assert tsubasa.shoot() == 9
        assert tsubasa.stamina == 96  # paid the special move's stamina cost

    def should_fall_back_to_a_weak_shot_when_exhausted(self) -> None:
        drive = SpecialMove("Drive Shot", power=9, stamina_cost=4)
        tsubasa = Striker("Tsubasa", drive)
        tsubasa.exert(100)  # fully drained
        assert tsubasa.shoot() == 1  # no stamina for the special move
EOF

python -m pytest specs/when_a_striker_shoots.py  # fail - module missing

# 4.2 - Implement the subclass. `super().__init__` chains to the base; the
#       overridden shoot() adds behavior while reusing exert() from Player.
cat > src/pitch/striker.py << 'EOF'
from src.pitch.player import Player
from src.pitch.types import Position, SpecialMove


class Striker(Player):
    def __init__(self, name: str, special_move: SpecialMove) -> None:
        # Call the parent constructor, then add Striker-specific state.
        super().__init__(name, Position.FORWARD)
        self.special_move = special_move

    def shoot(self) -> int:
        # Polymorphism: same method name, specialised behavior.
        if self.stamina >= self.special_move.stamina_cost:
            self.exert(self.special_move.stamina_cost)
            return self.special_move.power
        # Too tired for heroics - a feeble tap-in.
        self.exert(1)
        return 1
EOF

python -m pytest  # green

git add .
git commit -m "Add Striker subclass overriding shoot (inheritance + polymorphism)"

#####################################################
# 5 - Composition: a Team owns Players               #
#####################################################

# 5.1 - A Team has a name and a roster. It can total its attacking power and be
#       built from a list of players via a classmethod alternative constructor.
cat > specs/when_building_a_team.py << 'EOF'
from src.pitch.types import SpecialMove
from src.pitch.player import Player
from src.pitch.types import Position
from src.pitch.striker import Striker
from src.pitch.team import Team


class DescribeTeam:
    def should_sum_the_shot_power_of_its_roster(self) -> None:
        drive = SpecialMove("Drive Shot", power=9, stamina_cost=4)
        team = Team.of(
            "Nankatsu",
            Striker("Tsubasa", drive),
            Player("Ishizaki", Position.MIDFIELDER),
        )
        # 9 (striker) + 5 (base player) = 14
        assert team.attack_power() == 14

    def should_report_its_size(self) -> None:
        team = Team("Nankatsu")
        team.add(Player("Ishizaki", Position.MIDFIELDER))
        assert len(team) == 1
EOF

python -m pytest specs/when_building_a_team.py  # fail - module missing

# 5.2 - Implement Team. It *composes* players (has-a), unlike Striker which
#       *inherits* from Player (is-a). __len__ lets len(team) work naturally.
cat > src/pitch/team.py << 'EOF'
from __future__ import annotations

from src.pitch.player import Player


class Team:
    def __init__(self, name: str) -> None:
        self.name = name
        self._roster: list[Player] = []

    @classmethod
    def of(cls, name: str, *players: Player) -> Team:
        # An alternative constructor: Team.of("X", p1, p2). *players collects
        # any number of positional args into a tuple.
        team = cls(name)
        for player in players:
            team.add(player)
        return team

    def add(self, player: Player) -> None:
        self._roster.append(player)

    def attack_power(self) -> int:
        # A generator expression fed straight into sum() - no temp list.
        return sum(player.shoot() for player in self._roster)

    def __len__(self) -> int:
        return len(self._roster)
EOF

python -m pytest  # green

git add .
git commit -m "Add Team that composes players with a classmethod constructor"

#####################################################
# 6 - The Match engine ties the model together       #
#####################################################

# 6.1 - A Match pits two teams; the side with more attack power wins, else draw.
cat > specs/when_playing_a_match.py << 'EOF'
from src.pitch.types import Position, SpecialMove
from src.pitch.player import Player
from src.pitch.striker import Striker
from src.pitch.team import Team
from src.pitch.match import Match


class DescribeMatch:
    def should_declare_the_stronger_team_the_winner(self) -> None:
        drive = SpecialMove("Drive Shot", power=9, stamina_cost=4)
        home = Team.of("Nankatsu", Striker("Tsubasa", drive))
        away = Team.of("Shutetsu", Player("Generic", Position.FORWARD))

        result = Match(home, away).play()
        assert result == "Nankatsu wins"

    def should_declare_a_draw_when_evenly_matched(self) -> None:
        home = Team.of("A", Player("p1", Position.FORWARD))
        away = Team.of("B", Player("p2", Position.FORWARD))

        result = Match(home, away).play()
        assert result == "Draw"
EOF

python -m pytest specs/when_playing_a_match.py  # fail - module missing

# 6.2 - Implement the engine and re-export the public API from the package.
cat > src/pitch/match.py << 'EOF'
from src.pitch.team import Team


class Match:
    def __init__(self, home: Team, away: Team) -> None:
        self.home = home
        self.away = away

    def play(self) -> str:
        home_score = self.home.attack_power()
        away_score = self.away.attack_power()

        if home_score > away_score:
            return f"{self.home.name} wins"
        elif away_score > home_score:
            return f"{self.away.name} wins"
        else:
            return "Draw"
EOF

cat > src/pitch/__init__.py << 'EOF'
from src.pitch.match import Match
from src.pitch.player import Player
from src.pitch.striker import Striker
from src.pitch.team import Team
from src.pitch.types import Position, SpecialMove

__all__ = [
    "Match",
    "Player",
    "Striker",
    "Team",
    "Position",
    "SpecialMove",
]
EOF

python -m pytest  # all green

git add .
git commit -m "Add Match engine and expose the pitch package public API"

#####################################################
# 7 - A runnable entry point: main.py                #
#####################################################

# 7.1 - A program that fields two fully-populated teams and plays the match.
#       The rosters are generated from FORMATIONS using Faker for names and
#       country codes - all here in main.py, so the tested `pitch` package is
#       reused as-is with no production code changes. Forwards get a signature
#       special move (the Striker subclass); everyone else is a base Player.
cat > main.py << 'EOF'
from __future__ import annotations  # builtin generics (list[...]) on Py3.8+

import math
import random
from dataclasses import dataclass

from faker import Faker

from src.pitch import Match, Player, Position, SpecialMove, Striker, Team

fake = Faker()
Faker.seed(42)  # deterministic names so the demo output is stable
random.seed(42)  # deterministic nationality shuffle


@dataclass(frozen=True)
class Slot:
    # A formation slot: how to label it on the team sheet, and which
    # Position enum from the package it maps to.
    label: str
    position: Position


# Strikers FC line up 3-5-2 (1 GK + 3 DEF + 5 MID + 2 FWD = 11 players)
STRIKERS_FC = [
    Slot("GK", Position.GOALKEEPER),
    Slot("LCB", Position.DEFENDER), 
    Slot("CB", Position.DEFENDER),
    Slot("RCB", Position.DEFENDER), 
    Slot("LM", Position.MIDFIELDER),
    Slot("LCM", Position.MIDFIELDER),
    Slot("CM", Position.MIDFIELDER),
    Slot("RCM", Position.MIDFIELDER),
    Slot("RM", Position.MIDFIELDER),
    Slot("LS", Position.FORWARD),
    Slot("RS", Position.FORWARD),
]

# Deportivo Carolinas line up 5-1-3-1 (1 GK + 5 DEF + 4 MID + 1 FWD = 11 players)
DEPORTIVO_CAROLINAS = [
    Slot("GK", Position.GOALKEEPER),
    Slot("LWB", Position.DEFENDER),
    Slot("LCB", Position.DEFENDER),
    Slot("CB", Position.DEFENDER),
    Slot("RCB", Position.DEFENDER),
    Slot("RWB", Position.DEFENDER),
    Slot("DM", Position.MIDFIELDER),
    Slot("LCM", Position.MIDFIELDER),
    Slot("RCM", Position.MIDFIELDER),
    Slot("AM", Position.MIDFIELDER), 
    Slot("ST", Position.FORWARD), 
]


def country_codes(n: int) -> list[str]:
    # It's a USA league, so at least half of each XI must be American. Fill the
    # rest with random nationalities, then shuffle so the USA players are not
    # all clustered at the top of the team sheet.
    usa = math.ceil(n / 2)
    codes = ["USA"] * usa
    codes += [fake.country_code(representation="alpha-3") for _ in range(n - usa)]
    random.shuffle(codes)
    return codes


@dataclass
class Selection:
    # A picked player: their formation slot, the Player/Striker object the kata
    # package gave us, and their nationality. Mutable so the adventure can swap
    # a player out (e.g. rest the captain) before kickoff.
    slot: Slot
    player: Player
    country: str


def build_squad(
    formation: list[Slot], striker_power: int
) -> list[Selection]:
    # Forwards become Strikers (the subclass) with a signature move whose power
    # reflects the chosen mentality; everyone else is a base Player. We keep the
    # Selection list so the story can tweak players before the match.
    squad: list[Selection] = []
    for slot, country in zip(formation, country_codes(len(formation))):
        name = f"{fake.first_name_female()} {fake.last_name()}"
        if slot.position == Position.FORWARD:
            move = SpecialMove(f"{name.split()[0]}'s Strike", striker_power, 4)
            player: Player = Striker(name, move)
        else:
            player = Player(name, slot.position)
        squad.append(Selection(slot, player, country))
    return squad


def print_sheet(team_name: str, formation: str, squad: list[Selection]) -> None:
    print(f"{team_name} ({formation})")
    for s in squad:
        print(f"  {s.slot.label:<4} {s.player.name} ({s.country})")


def to_team(name: str, squad: list[Selection]) -> Team:
    team = Team(name)
    for s in squad:
        team.add(s.player)
    return team


def forwards(squad: list[Selection]) -> list[Selection]:
    return [s for s in squad if s.slot.position == Position.FORWARD]


def choose(prompt: str, options: list[tuple[str, str]]) -> str:
    print(f"\n{prompt}")
    for key, desc in options:
        print(f"  [{key}] {desc}")
    valid = {key for key, _ in options}
    while True:
        pick = input("> ").strip()
        if pick in valid:
            return pick
        print("  Pick one of:", ", ".join(sorted(valid)))


def main() -> None:
    print("=== STRIKERS FC: Matchday ===\n")
    print(
        "You are the new head coach of Strikers FC. Today you host the league\n"
        "leaders, Deportivo Carolinas.\n"
    )
    print(
        "SCOUT REPORT: Deportivo park the bus - five at the back behind a lone\n"
        "striker. Out-gun them up top, and DON'T burn your legs chasing shadows.\n"
    )

    # --- Decision 1: mentality sets your strikers' shooting power -----------
    mentality = choose(
        "Team talk - how do you set them up?",
        [
            ("1", "All-out attack  (strikers shoot hardest)"),
            ("2", "Balanced"),
            ("3", "Cautious        (sit and absorb)"),
        ],
    )
    striker_power = {"1": 9, "2": 7, "3": 5}[mentality]

    home_squad = build_squad(STRIKERS_FC, striker_power)
    away_squad = build_squad(DEPORTIVO_CAROLINAS, 9)

    print()
    print_sheet("Strikers FC", "3-5-2", home_squad)
    print()
    print_sheet("Deportivo Carolinas", "5-1-3-1", away_squad)

    # --- Decision 2: rest the injured captain? ------------------------------
    captain = forwards(home_squad)[0]
    start = choose(
        f"Your captain {captain.player.name} is carrying a knock. Start her?",
        [("1", "Start the captain"), ("2", "Rest her - bring on a rookie")],
    )
    if start == "2":
        rookie = f"{fake.first_name_female()} {fake.last_name()}"
        captain.player = Player(rookie, Position.FORWARD)  # a weaker base player
        print(f"  {rookie} comes in up top for the injured captain.")

    # --- Decision 3: match tactic -------------------------------------------
    tactic = choose(
        "Kickoff approaches. What's the instruction?",
        [
            ("1", "High press - hound them all over the pitch"),
            ("2", "Hold shape - sit deep and pick your moments"),
        ],
    )
    if tactic == "1":
        # A 90-minute press tires the chasers AND the chased. Their lone striker
        # fades (little gained) while BOTH your forwards end up running on empty.
        for s in forwards(away_squad) + forwards(home_squad):
            s.player.exert(100)
        print("  You press high - legs everywhere, lungs burning.")

    # --- Kickoff ------------------------------------------------------------
    input("\nPress Enter to kick off...")

    home = to_team("Strikers FC", home_squad)
    away = to_team("Deportivo Carolinas", away_squad)

    print(
        f"\nAttacking output - Strikers FC: {home.attack_power()}"
        f" | Deportivo: {away.attack_power()}"
    )
    result = Match(home, away).play()
    print(f"Full time: {result}\n")

    if result == "Strikers FC wins":
        print("The crowd erupts - you out-shot the bus and took the points!")
    elif result == "Draw":
        print("A share of the spoils - one more spark and it was yours.")
    else:
        print("Deportivo nick it. The scout warned you - rethink the approach.")


if __name__ == "__main__":
    main()
EOF

# Run it interactively with `python main.py`. Here we feed the winning line -
# all-out attack, start the captain, hold shape (don't waste legs pressing).
printf '1\n1\n2\n\n' | python main.py

git add .
git commit -m "Add runnable main.py entry point"

echo "Finis."
