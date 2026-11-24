#!/usr/bin/env python3
"""Exercises web/leaderboard against a throw-away SQLite database.

    python3 tools/test_leaderboard.py

Needs php (with pdo_sqlite) on the path. Starts PHP's own web server on a
free local port with LB_CONFIG pointing at a temporary settings file,
registers machines, sends scores, reads boards, and checks the answers.
The tables are the ones of web/leaderboard/schema.sql in SQLite's words
(the PHP uses nothing that differs between the two); what this cannot
show is whether schema.sql itself loads into MySQL.
"""
import json
import os
import socket
import sqlite3
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SITE = os.path.join(ROOT, "web", "leaderboard")

SQLITE_SCHEMA = """
CREATE TABLE benchmarks (id INTEGER PRIMARY KEY, slug TEXT UNIQUE NOT NULL, name TEXT NOT NULL,
  book TEXT NOT NULL, model TEXT NOT NULL, audio_ms INTEGER NOT NULL, sort_order INTEGER NOT NULL);
INSERT INTO benchmarks VALUES
  (1, 'benchmark_short_fast', 'Short Text, Fast Model', 'A Scandal in Bohemia', 'ggml-base.bin', 3202850, 1),
  (2, 'benchmark_short_detailed', 'Short Text, Detailed Model', 'A Scandal in Bohemia', 'ggml-large-v3-turbo.bin', 3202850, 2),
  (3, 'benchmark_long_fast', 'Long Text, Fast Model', 'A Christmas Carol', 'ggml-base.bin', 11169310, 3),
  (4, 'benchmark_long_detailed', 'Long Text, Detailed Model', 'A Christmas Carol', 'ggml-large-v3-turbo.bin', 11169310, 4);
CREATE TABLE players (id INTEGER PRIMARY KEY AUTOINCREMENT, source TEXT NOT NULL, steam_id TEXT UNIQUE,
  display_name TEXT NOT NULL, banned INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL);
CREATE TABLE machines (id INTEGER PRIMARY KEY AUTOINCREMENT, player_id INTEGER NOT NULL REFERENCES players(id),
  install_id TEXT UNIQUE NOT NULL, key_hash TEXT NOT NULL, label TEXT, os TEXT, cpu TEXT, memory_gb INTEGER,
  hidden INTEGER NOT NULL DEFAULT 0, sender_hash TEXT, created_at TEXT NOT NULL, last_seen TEXT NOT NULL);
CREATE TABLE devices (id INTEGER PRIMARY KEY AUTOINCREMENT, description TEXT NOT NULL, kind TEXT NOT NULL,
  backend TEXT NOT NULL, UNIQUE (description, kind, backend));
CREATE TABLE runs (id INTEGER PRIMARY KEY AUTOINCREMENT, machine_id INTEGER NOT NULL REFERENCES machines(id),
  benchmark_id INTEGER NOT NULL REFERENCES benchmarks(id), device_id INTEGER NOT NULL REFERENCES devices(id),
  score_ms INTEGER NOT NULL, audio_ms INTEGER NOT NULL, words INTEGER NOT NULL, words_matched INTEGER NOT NULL,
  avg_watts INTEGER, peak_watts INTEGER, limit_watts INTEGER,
  build TEXT NOT NULL, channel TEXT NOT NULL, ran_at TEXT NOT NULL, received_at TEXT NOT NULL, sender_hash TEXT,
  verified INTEGER NOT NULL DEFAULT 0, status TEXT NOT NULL, reject_reason TEXT);
CREATE TABLE bests (machine_id INTEGER NOT NULL REFERENCES machines(id),
  benchmark_id INTEGER NOT NULL REFERENCES benchmarks(id), run_id INTEGER NOT NULL REFERENCES runs(id),
  score_ms INTEGER NOT NULL, PRIMARY KEY (machine_id, benchmark_id));
"""

# The owner's seven machines on Long Text, Fast Model (the Steam board of 2026-11-23).
MACHINES = [
    ("Player one", "NVIDIA GeForce RTX 5090 Laptop GPU", "gpu", "Vulkan", 119437),
    ("Player two", "Apple M4", "integrated", "Metal", 155096),
    ("Player three", "AMD Steam Machine (RADV NAVI33)", "gpu", "Vulkan", 179967),
    ("Player four", "NVIDIA GeForce GTX 1650", "gpu", "Vulkan", 252000),
    ("Player five", "AMD Ryzen Z1 Extreme (RADV PHOENIX)", "integrated", "Vulkan", 304946),
    ("Player six", "AMD Custom GPU 0405 (RADV VANGOGH)", "integrated", "Vulkan", 539618),
    ("Player seven", "Intel(R) UHD Graphics 620", "integrated", "Vulkan", 1693595),
]

failures = []


def check(what, ok, detail=""):
    print(("  ok    " if ok else "  FAIL  ") + what + ((" - " + str(detail)) if detail and not ok else ""))
    if not ok:
        failures.append(what)


def call(base, path, body=None):
    """POSTs body as JSON (or GETs when it is None); the status and the JSON answer."""
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(base + path, data=data, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        text = e.read().decode()
        try:
            return e.code, json.loads(text)
        except ValueError:
            return e.code, {"raw": text}


def run(base, install, key, score, **over):
    body = {
        "install_id": install, "key": key, "benchmark": "benchmark_long_fast", "score_ms": score,
        "audio_ms": 11169310, "words": 28320, "words_matched": 27786, "model": "ggml-base.bin",
        "device": "Test device", "device_kind": "gpu", "backend": "Vulkan",
        "build": "2026-11-23 02:34, 2ccbf89", "channel": "steam", "ran_at": "2026-11-23 13:00:00",
    }
    body.update(over)
    return call(base, "/api/submit.php", body)


def main():
    tmp = tempfile.mkdtemp(prefix="lbtest-")
    dbfile = os.path.join(tmp, "lb.sqlite")
    con = sqlite3.connect(dbfile)
    con.executescript(SQLITE_SCHEMA)
    con.commit()
    con.close()
    config = os.path.join(tmp, "config.php")
    with open(config, "w") as f:
        f.write("<?php return ['dsn' => 'sqlite:%s', 'salt' => 'test-salt'];\n" % dbfile)

    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    port = s.getsockname()[1]
    s.close()
    env = dict(os.environ, LB_CONFIG=config)
    server = subprocess.Popen(["php", "-S", "127.0.0.1:%d" % port, "-t", SITE], env=env,
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    base = "http://127.0.0.1:%d" % port
    try:
        for _ in range(50):
            try:
                urllib.request.urlopen(base + "/index.php", timeout=1).read()
                break
            except Exception:
                time.sleep(0.1)

        print("register")
        installs = []
        for name, device, kind, backend, score in MACHINES:
            install = str(uuid.uuid4())
            st, a = call(base, "/api/register.php", {"install_id": install, "name": name,
                                                     "os": "Test OS (Version 1.2, 64-bit)"})
            check("register " + name, st == 200 and a.get("ok") and len(a.get("key", "")) == 64, (st, a))
            installs.append((install, a.get("key", ""), name, device, kind, backend, score))
        st, a = call(base, "/api/register.php", {"install_id": installs[0][0], "name": "Again"})
        check("the same id twice is refused (409)", st == 409, (st, a))
        st, a = call(base, "/api/register.php", {"install_id": "not-a-uuid"})
        check("a bad id is refused (400)", st == 400, (st, a))

        print("submit")
        # slowest first, so that places change as faster ones arrive
        for install, key, name, device, kind, backend, score in reversed(installs):
            st, a = run(base, install, key, score, device=device, device_kind=kind, backend=backend)
            check("score of " + name, st == 200 and a.get("status") == "ok" and a.get("place") == 1 and
                  a.get("improved") is True, (st, a))
        first = installs[0]
        st, a = run(base, first[0], first[1], 125000)
        check("a slower run is kept but is not the best", st == 200 and a.get("improved") is False and
              a.get("best_ms") == 119437 and a.get("place") == 1 and a.get("count") == 7, (st, a))
        st, a = run(base, first[0], "0" * 64, 100000)
        check("a wrong key is refused (401)", st == 401, (st, a))
        st, a = run(base, first[0], first[1], 100000, model="ggml-large-v3-turbo.bin")
        check("another model is refused (422)", st == 422, (st, a))
        st, a = run(base, first[0], first[1], 100000, audio_ms=3202850)
        check("another recording is refused (422)", st == 422, (st, a))
        st, a = run(base, first[0], first[1], 100000, words_matched=1000)
        check("too few words matched is refused (422)", st == 422, (st, a))
        st, a = run(base, first[0], first[1], 1000)
        check("an impossible speed is refused (422)", st == 422, (st, a))
        st, a = run(base, first[0], first[1], 20000)
        check("a too-good run waits for a person (pending, the place unchanged)", st == 200 and
              a.get("status") == "pending" and a.get("best_ms") == 119437, (st, a))
        st, a = run(base, first[0], first[1], "abc")
        check("a score that is not a number is refused (400)", st == 400, (st, a))
        st, a = call(base, "/api/submit.php")
        check("a GET to submit is refused (405)", st == 405, (st, a))

        print("board")
        st, a = call(base, "/api/board.php?benchmark=benchmark_long_fast&rows=5")
        rows = a.get("rows", [])
        check("the top five, fastest first", st == 200 and a.get("count") == 7 and len(rows) == 5 and
              [r["score_ms"] for r in rows] == [119437, 155096, 179967, 252000, 304946] and
              rows[0]["place"] == 1 and rows[0]["score"] == "0:01:59.437" and
              rows[0]["device"] == "NVIDIA GeForce RTX 5090 Laptop GPU", a)
        last = installs[-1]
        st, a = call(base, "/api/board.php?benchmark=benchmark_long_fast&rows=3&around=" + last[0])
        rows = a.get("rows", [])
        check("around the last: a full page ending with it", st == 200 and a.get("first") == 5 and
              len(rows) == 3 and rows[-1]["me"] is True and a.get("you") == {"place": 7, "score_ms": 1693595}, a)
        mid = installs[3]
        st, a = call(base, "/api/board.php?benchmark=benchmark_long_fast&rows=3&around=" + mid[0])
        rows = a.get("rows", [])
        check("around the fourth: it is in the middle", st == 200 and a.get("first") == 3 and
              [r["place"] for r in rows] == [3, 4, 5] and rows[1]["me"] is True, a)
        st, a = run(base, mid[0], mid[1], 250000, avg_watts=48, peak_watts=55, limit_watts=50)
        st2, b = run(base, last[0], last[1], 1600000, avg_watts=99999, peak_watts="x")
        st3, c = call(base, "/api/board.php?benchmark=benchmark_long_fast&rows=7")
        rows = c.get("rows", [])
        check("watts are kept with a run and shown; unbelievable ones are dropped, the run kept",
              st == 200 and st2 == 200 and len(rows) == 7 and rows[3]["avg_watts"] == 48 and
              rows[3]["peak_watts"] == 55 and rows[3]["limit_watts"] == 50 and rows[6]["score_ms"] == 1600000 and
              rows[6]["avg_watts"] is None and rows[0]["avg_watts"] is None, (st, st2, c))
        st, a = run(base, mid[0], mid[1], 249000, os="SteamOS 3.8.2", avg_watts=48, limit_watts=50)
        st, c = call(base, "/api/board.php?benchmark=benchmark_long_fast&rows=7")
        check("a score's os replaces the registration's", st == 200 and c["rows"][3]["os"] == "SteamOS 3.8.2" and
              c["rows"][0]["os"] == "Test OS", c)
        st, a = call(base, "/api/board.php?benchmark=benchmark_short_fast")
        check("an empty board", st == 200 and a.get("count") == 0 and a.get("rows") == [], a)
        st, a = call(base, "/api/board.php?benchmark=nothing")
        check("an unknown board is refused (400)", st == 400, (st, a))

        print("page")
        html = urllib.request.urlopen(base + "/index.php?b=benchmark_long_fast", timeout=10).read().decode()
        check("the page lists the seven", html.count("<td class=\"place\">") == 7 and "0:01:59.437" in html and
              "Player seven" in html and "94x" in html and "<td class=\"num wpm\">14,227</td>" in html and "48 W of 50" in html and
              html.count("<td class=\"os\">Test OS</td>") == 6)
        con = sqlite3.connect(dbfile)
        con.execute("UPDATE players SET display_name = '<script>alert(1)</script>' WHERE id = 1")
        con.commit()
        html = urllib.request.urlopen(base + "/index.php?b=benchmark_long_fast", timeout=10).read().decode()
        check("a name is shown as text, never as markup", "<script>alert(1)</script>" not in html and
              "&lt;script&gt;" in html)
        con.execute("UPDATE machines SET hidden = 1 WHERE id = 1")
        con.commit()
        st, a = call(base, "/api/board.php?benchmark=benchmark_long_fast&rows=3")
        check("a hidden machine is off the board", a.get("count") == 6 and a["rows"][0]["score_ms"] == 155096, a)
        n = con.execute("SELECT COUNT(*) FROM runs").fetchone()[0]
        k = con.execute("SELECT COUNT(*) FROM runs WHERE status = 'rejected'").fetchone()[0]
        con.close()
        check("every run was kept, the refused ones with their reason", n == 16 and k == 4, (n, k))

        print("rate limit")
        spare = str(uuid.uuid4())
        st, a = call(base, "/api/register.php", {"install_id": spare})
        key = a.get("key", "")
        codes = [run(base, spare, key, 300000 + i)[0] for i in range(22)]
        check("the 21st score in an hour from one machine is refused (429)", codes[:20] == [200] * 20 and
              codes[20] == 429, codes)
    finally:
        server.terminate()

    print()
    if failures:
        print("%d FAILED: %s" % (len(failures), "; ".join(failures)))
        return 1
    print("all passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
