#!/bin/bash

# Python Async Chat Kata (concurrency, asyncio, threading, the GIL)
#
# Teaching focus: doing more than one thing at a time in Python.
#   - async / await and the event loop (asyncio)
#   - asyncio.Queue for safe message hand-off between coroutines
#   - asyncio.gather to run many coroutines concurrently
#   - async context managers (async with) and async generators (async for)
#   - threading basics and a practical discussion of the GIL
#   - project organization: an importable `chat` package
#
# --------------------------------------------------------------------------
# A note on the GIL (Global Interpreter Lock)
# --------------------------------------------------------------------------
# CPython protects its memory with a single lock - the GIL - so only ONE
# thread executes Python bytecode at a time. Consequences:
#
#   * CPU-bound work (number crunching) does NOT speed up with threads, because
#     threads cannot run Python bytecode in parallel. Use multiprocessing or a
#     native/C extension that releases the GIL for those.
#   * I/O-bound work (network, disk, a chat server!) DOES benefit, because a
#     thread releases the GIL while it waits on I/O, letting others run.
#
# asyncio takes a different tack: a SINGLE thread cooperatively multitasks via
# await points - no GIL contention, no thread overhead - which is ideal for the
# many-slow-connections shape of a chat server. We build with asyncio, then add
# a tiny threading example to make the GIL trade-off concrete.
# --------------------------------------------------------------------------

#############################################
# 1 - Create a new repo                     #
#############################################
deactivate 2>/dev/null || true
rm -rf python-async-chat-kata && mkdir python-async-chat-kata && cd $_

git init .
wget -O .gitignore https://raw.githubusercontent.com/github/gitignore/main/Python.gitignore

python -m venv .venv
source .venv/bin/activate  # for Windows: source .venv/Scripts/activate

# pytest-asyncio is not strictly required - our specs drive coroutines with
# asyncio.run(...) - but we install the usual quality tooling.
python -m pip install --upgrade pip
pip install pytest pytest-cov black isort flake8 mypy pre-commit
pip freeze | grep -E "^(pytest==|pytest-cov==|black==|isort==|flake8==|mypy==|pre-commit==)" > requirements.txt

cat > pytest.ini << 'EOF'
[pytest]
testpaths = specs
python_files = when*.py
python_classes = Describe
python_functions = should_*
EOF

mkdir -p src/chat specs
touch src/__init__.py src/chat/__init__.py

git add .
git commit -m "Create new async chat kata"

#####################################################
# 2 - A Message value object                         #
#####################################################

# 2.1 - Every chat line is a (sender, text) pair. A frozen dataclass again.
cat > specs/when_formatting_a_message.py << 'EOF'
from src.chat.message import Message


class DescribeMessage:
    def should_render_as_sender_colon_text(self) -> None:
        msg = Message(sender="tsubasa", text="hello")
        assert str(msg) == "tsubasa: hello"
EOF

python -m pytest specs/when_formatting_a_message.py  # fail - module missing

# 2.2 - Implement it.
cat > src/chat/message.py << 'EOF'
from dataclasses import dataclass


@dataclass(frozen=True)
class Message:
    sender: str
    text: str

    def __str__(self) -> str:
        return f"{self.sender}: {self.text}"
EOF

python -m pytest  # green

git add .
git commit -m "Add Message value object"

#####################################################
# 3 - A Room: broadcasting via asyncio.Queue         #
#####################################################

# 3.1 - A Room holds one asyncio.Queue per subscriber. Publishing a message
#       fans it out to every subscriber's queue. Queues are the safe way to
#       move data between coroutines without races.
cat > specs/when_publishing_to_a_room.py << 'EOF'
from __future__ import annotations  # builtin generics (list[...]) on Py3.8+

import asyncio

from src.chat.message import Message
from src.chat.room import Room


class DescribeRoom:
    def should_deliver_a_published_message_to_a_subscriber(self) -> None:
        async def scenario() -> Message:
            room = Room()
            inbox = room.subscribe()
            await room.publish(Message("tsubasa", "hi"))
            return await inbox.get()

        # Each spec is a normal sync method that runs one coroutine to
        # completion via asyncio.run - no plugin configuration needed.
        delivered = asyncio.run(scenario())
        assert str(delivered) == "tsubasa: hi"

    def should_fan_out_to_every_subscriber(self) -> None:
        async def scenario() -> list[str]:
            room = Room()
            a = room.subscribe()
            b = room.subscribe()
            await room.publish(Message("ishizaki", "team!"))
            # gather awaits both reads concurrently.
            first, second = await asyncio.gather(a.get(), b.get())
            return [str(first), str(second)]

        results = asyncio.run(scenario())
        assert results == ["ishizaki: team!", "ishizaki: team!"]
EOF

python -m pytest specs/when_publishing_to_a_room.py  # fail - module missing

# 3.2 - Implement the Room.
cat > src/chat/room.py << 'EOF'
import asyncio

from src.chat.message import Message


class Room:
    def __init__(self) -> None:
        # One queue per subscriber. asyncio.Queue is coroutine-safe.
        self._subscribers: list[asyncio.Queue[Message]] = []

    def subscribe(self) -> "asyncio.Queue[Message]":
        inbox: asyncio.Queue[Message] = asyncio.Queue()
        self._subscribers.append(inbox)
        return inbox

    async def publish(self, message: Message) -> None:
        # await each put: with unbounded queues this returns immediately, but
        # awaiting keeps the coroutine well-behaved if a bound is added later.
        for inbox in self._subscribers:
            await inbox.put(message)
EOF

python -m pytest  # green

git add .
git commit -m "Add Room that fans out messages over asyncio queues"

#####################################################
# 4 - Concurrency: many clients sending at once      #
#####################################################

# 4.1 - Simulate several clients posting concurrently and assert the room
#       received every message. This exercises asyncio.gather scheduling many
#       coroutines on the single event-loop thread.
cat > specs/when_many_clients_send_concurrently.py << 'EOF'
import asyncio

from src.chat.message import Message
from src.chat.room import Room


class DescribeConcurrentClients:
    def should_receive_every_message_from_all_clients(self) -> None:
        async def client(room: Room, name: str, count: int) -> None:
            for i in range(count):
                await room.publish(Message(name, f"msg-{i}"))

        async def scenario() -> int:
            room = Room()
            inbox = room.subscribe()

            # Three clients, three messages each, all running concurrently.
            await asyncio.gather(
                client(room, "a", 3),
                client(room, "b", 3),
                client(room, "c", 3),
            )

            # Drain everything the subscriber received.
            received = 0
            while not inbox.empty():
                await inbox.get()
                received += 1
            return received

        assert asyncio.run(scenario()) == 9
EOF

python -m pytest  # green - no production change needed, just new behavior proven

git add .
git commit -m "Prove concurrent clients via asyncio.gather"

#####################################################
# 5 - Async context manager + async generator        #
#####################################################

# 5.1 - A Session is an `async with` resource: entering subscribes to the room,
#       exiting unsubscribes. It also offers `stream()`, an async generator you
#       consume with `async for`.
cat > specs/when_streaming_a_session.py << 'EOF'
from __future__ import annotations  # builtin generics (list[...]) on Py3.8+

import asyncio

from src.chat.message import Message
from src.chat.room import Room
from src.chat.session import Session


class DescribeSession:
    def should_stream_messages_until_closed(self) -> None:
        async def scenario() -> list[str]:
            room = Room()
            seen: list[str] = []

            async with Session(room) as session:
                await room.publish(Message("tsubasa", "one"))
                await room.publish(Message("tsubasa", "two"))
                await session.close_after(2)  # stop the stream after 2 reads

                async for message in session.stream():
                    seen.append(str(message))

            return seen

        assert asyncio.run(scenario()) == ["tsubasa: one", "tsubasa: two"]
EOF

python -m pytest specs/when_streaming_a_session.py  # fail - module missing

# 5.2 - Implement it. __aenter__/__aexit__ make it an async context manager;
#       `stream` is an async generator (async def + yield).
cat > src/chat/session.py << 'EOF'
from typing import AsyncIterator

from src.chat.message import Message
from src.chat.room import Room


class Session:
    def __init__(self, room: Room) -> None:
        self._room = room
        self._inbox: "object" = None
        self._remaining = 0

    async def __aenter__(self) -> "Session":
        # Setup on `async with` entry: join the room.
        self._inbox = self._room.subscribe()
        return self

    async def __aexit__(self, *exc: object) -> None:
        # Teardown on exit. A real client would deregister its queue here.
        self._inbox = None

    async def close_after(self, n: int) -> None:
        # Bound the stream so the async-for loop terminates deterministically.
        self._remaining = n

    async def stream(self) -> AsyncIterator[Message]:
        # An async generator: each `yield` hands a value to `async for`,
        # suspending until the consumer asks for the next one.
        for _ in range(self._remaining):
            message: Message = await self._inbox.get()  # type: ignore[union-attr]
            yield message
EOF

python -m pytest  # green

git add .
git commit -m "Add Session async context manager with an async generator stream"

#####################################################
# 6 - Threading + the GIL, made concrete             #
#####################################################

# 6.1 - A small, honest demonstration: run a CPU-bound counter across threads
#       and show the TOTAL work is correct (a threading.Lock prevents races),
#       while noting it is not actually faster due to the GIL.
cat > specs/when_counting_across_threads.py << 'EOF'
from src.chat.metrics import count_with_threads


class DescribeThreadedCounter:
    def should_total_correctly_when_guarded_by_a_lock(self) -> None:
        # 4 threads each increment 1000 times -> exactly 4000, because the
        # Lock serialises the read-modify-write. Without the lock this would
        # race even *with* the GIL, since the GIL can switch mid-operation.
        assert count_with_threads(workers=4, per_worker=1000) == 4000
EOF

python -m pytest specs/when_counting_across_threads.py  # fail - module missing

# 6.2 - Implement it. The Lock - not the GIL - is what makes the count exact.
cat > src/chat/metrics.py << 'EOF'
import threading


def count_with_threads(workers: int, per_worker: int) -> int:
    total = 0
    lock = threading.Lock()

    def worker() -> None:
        nonlocal total
        for _ in range(per_worker):
            # The GIL does NOT make `total += 1` atomic across threads, so we
            # guard the critical section explicitly. `with lock:` is itself a
            # context manager - acquire on enter, release on exit.
            with lock:
                total += 1

    threads = [threading.Thread(target=worker) for _ in range(workers)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()  # wait for every thread to finish before reading `total`

    return total
EOF

python -m pytest  # all green

git add .
git commit -m "Add threaded counter demonstrating the GIL and locking"

#####################################################
# 7 - Expose the package public API                  #
#####################################################

# 7.1 - Curate what the package exports.
cat > src/chat/__init__.py << 'EOF'
from src.chat.message import Message
from src.chat.metrics import count_with_threads
from src.chat.room import Room
from src.chat.session import Session

__all__ = ["Message", "Room", "Session", "count_with_threads"]
EOF

python -m pytest  # all green

git add .
git commit -m "Expose the chat package public API"

#####################################################
# 8 - A runnable entry point: main.py                #
#####################################################

# 8.1 - An INTERACTIVE chat: you type a message and the "other end" (a fake
#       peer running as a background task) replies. Run it with `python main.py`.
#       Everything reuses the tested `chat` package as-is - the interaction
#       logic lives only here in main.py.
#
#       Note how input() (which blocks) is run via loop.run_in_executor: it
#       runs on a worker THREAD so the event loop stays responsive. While that
#       thread waits on stdin it releases the GIL - the I/O-bound case the
#       header discussed - so the peer's coroutine keeps running meanwhile.
cat > main.py << 'EOF'
import asyncio
import random

from src.chat import Message, Room

ME = "you"
PEER = "Jane Doe"  # the team captain on the other end
REPLIES = [
    "Nice one!",
    "Haha, agreed.",
    "Tell me more.",
    "On my way.",
    "Pass it wide!",
    "Let's win this.",
]

random.seed(7)  # stable replies for the demo


async def peer_bot(room: Room, inbox: "asyncio.Queue[Message]") -> None:
    # The fake "other end". It listens on its own queue and fires back a reply
    # whenever it sees a message from someone other than itself.
    while True:
        msg = await inbox.get()
        if msg.sender == PEER:
            continue  # skip our own echoes (the room fans out to everyone)
        await asyncio.sleep(0.3)  # pretend the peer is typing
        await room.publish(Message(PEER, random.choice(REPLIES)))


async def read_line(prompt: str) -> str:
    # input() is blocking, so run it on a thread to keep the loop responsive.
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(None, input, prompt)


async def main() -> None:
    room = Room()
    my_inbox = room.subscribe()
    peer_inbox = room.subscribe()

    bot = asyncio.create_task(peer_bot(room, peer_inbox))

    print(f"Chatting with {PEER} (team captain). Type a message ('exit' to quit).")
    try:
        while True:
            try:
                text = (await read_line(f"{ME}> ")).strip()
            except EOFError:
                break
            if text.lower() in {"exit", "quit"}:
                break
            if not text:
                continue

            await room.publish(Message(ME, text))

            # Drain my inbox: skip my own echo, print the peer's reply.
            while True:
                incoming = await my_inbox.get()
                if incoming.sender != ME:
                    print(f"{incoming.sender}> {incoming.text}")
                    break
    finally:
        bot.cancel()


if __name__ == "__main__":
    asyncio.run(main())
EOF

# Run it interactively with `python main.py`. Here we feed two lines then exit
# so the kata script stays non-interactive.
printf 'hello\nhow is training\nexit\n' | python main.py

git add .
git commit -m "Add runnable main.py entry point"

echo "Finis."
