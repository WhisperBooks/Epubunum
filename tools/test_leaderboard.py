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
  model TEXT, cores INTEGER, perf_cores INTEGER, eff_cores INTEGER, threads INTEGER, gpu_cores INTEGER,
  hidden INTEGER NOT NULL DEFAULT 0, sender_hash TEXT, created_at TEXT NOT NULL, last_seen TEXT NOT NULL);
CREATE TABLE devices (id INTEGER PRIMARY KEY AUTOINCREMENT, description TEXT NOT NULL, kind TEXT NOT NULL,
  backend TEXT NOT NULL, UNIQUE (description, kind, backend));
CREATE TABLE runs (id INTEGER PRIMARY KEY AUTOINCREMENT, machine_id INTEGER NOT NULL REFERENCES machines(id),
  benchmark_id INTEGER NOT NULL REFERENCES benchmarks(id), device_id INTEGER NOT NULL REFERENCES devices(id),
  score_ms INTEGER NOT NULL, audio_ms INTEGER NOT NULL, words INTEGER NOT NULL, words_matched INTEGER NOT NULL,
  avg_watts INTEGER, peak_watts INTEGER, limit_watts INTEGER, device_memory_mb INTEGER,
  build TEXT NOT NULL, whisper TEXT NOT NULL DEFAULT '1.9.5', channel TEXT NOT NULL, ran_at TEXT NOT NULL, received_at TEXT NOT NULL, sender_hash TEXT,
  verified INTEGER NOT NULL DEFAULT 0, status TEXT NOT NULL, reject_reason TEXT);
CREATE TABLE bests (machine_id INTEGER NOT NULL REFERENCES machines(id),
  benchmark_id INTEGER NOT NULL REFERENCES benchmarks(id), whisper TEXT NOT NULL DEFAULT '1.9.5',
  run_id INTEGER NOT NULL REFERENCES runs(id),
  score_ms INTEGER NOT NULL, PRIMARY KEY (machine_id, benchmark_id, whisper));
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
        st, a = run(base, mid[0], mid[1], 248000, os="macOS (Version 26.1.0)", backend="Metal + Core ML")
        st, c = call(base, "/api/board.php?benchmark=benchmark_long_fast&rows=7")
        check("a Mac's version comes out of the bracket; Core ML is part of the backend", st == 200 and
              c["rows"][3]["os"] == "macOS 26.1" and c["rows"][3]["backend"] == "Metal + Core ML", c)
        st, a = run(base, mid[0], mid[1], 247000, os="macOS 26.1 (25B78)", avg_watts=48, limit_watts=50)
        st, c = call(base, "/api/board.php?benchmark=benchmark_long_fast&rows=7")
        check("a Mac's system that has its version is left as it is", c["rows"][3]["os"] == "macOS 26.1", c)
        st, a = run(base, mid[0], mid[1], 249000, os="SteamOS 3.8.2")
        st, c = call(base, "/api/board.php?benchmark=benchmark_long_fast&rows=7")
        check("a machine that said nothing of itself is Unknown", c["rows"][0]["machine"] == "Unknown", c["rows"][0])
        st, a = run(base, mid[0], mid[1], 260000, machine_model="Mac mini", cpu="Apple M4", memory_gb=16, cores=10,
                    perf_cores=4, eff_cores=6, threads=10, gpu_cores=10, device="Apple M4")
        st, a = run(base, mid[0], mid[1], 246000, device="Apple M4", avg_watts=48, limit_watts=50,
                    device_memory_mb=24166)
        st, c = call(base, "/api/board.php?benchmark=benchmark_long_fast&rows=7")
        check("a Mac's model, cores, graphics cores and memory; the chip is not said twice; a score without them "
              "leaves them", c["rows"][3]["machine"] == "Mac mini \u00b7 10 cores (4P + 6E) \u00b7 10-core GPU \u00b7 16 GB",
              c["rows"][3])
        st, a = run(base, installs[0][0], installs[0][1], 150000, device="NVIDIA GeForce RTX 5090 Laptop GPU", device_memory_mb=24166)
        st, c2 = call(base, "/api/board.php?benchmark=benchmark_long_fast&rows=7")
        check("a best run made before the memory was sent shows what a later run on the same device said",
              c2["rows"][0]["score_ms"] == 119437 and c2["rows"][0]["device_memory_mb"] == 24166, c2["rows"][0])
        check("the device's own memory is kept with the run", c["rows"][3]["device_memory_mb"] == 24166 and
              c["rows"][1]["device_memory_mb"] is None, c["rows"][3])
        st, a = run(base, last[0], last[1], 1700000, machine_model="ROG Ally RC71L", cpu="AMD Ryzen Z1 Extreme", cores=8,
                    threads=16, memory_gb=16, gpu_cores=0, perf_cores="x")
        st, c = call(base, "/api/board.php?benchmark=benchmark_long_fast&rows=7")
        check("a PC: the processor is named when the run was on something else; what is not a number is left out",
              c["rows"][6]["machine"] == "ROG Ally RC71L \u00b7 AMD Ryzen Z1 Extreme \u00b7 8 cores \u00b7 16 GB",
              c["rows"][6])
        st, a = call(base, "/api/board.php?benchmark=benchmark_short_fast")
        check("an empty board", st == 200 and a.get("count") == 0 and a.get("rows") == [], a)
        st, a = call(base, "/api/board.php?benchmark=nothing")
        check("an unknown board is refused (400)", st == 400, (st, a))

        print("versions of whisper.cpp")
        html = urllib.request.urlopen(base + "/index.php?b=benchmark_long_fast", timeout=10).read().decode()
        check("one version: the page has no version links", 'class="versions"' not in html and
              html.count("<td class=\"place\">") == 7 and "(whisper.cpp 1.9.5)" in html)
        top = installs[0]
        st, a = run(base, top[0], top[1], 130000, whisper="1.9.6")
        check("a slower run under a new version is that version's best", st == 200 and a.get("improved") is True and
              a.get("place") == 1 and a.get("count") == 1 and a.get("best_ms") == 130000 and
              a.get("whisper") == "1.9.6", (st, a))
        st, a = call(base, "/api/board.php?benchmark=benchmark_long_fast&whisper=1.9.6&install=" + top[0])
        check("the new version's board has that run alone", st == 200 and a.get("count") == 1 and
              [r["score_ms"] for r in a.get("rows", [])] == [130000] and a.get("whisper") == "1.9.6" and
              a.get("whispers") == ["1.9.6", "1.9.5"] and a.get("you") == {"place": 1, "score_ms": 130000}, a)
        st, a = call(base, "/api/board.php?benchmark=benchmark_long_fast&rows=7&install=" + top[0])
        check("a program that names no version has the first one's board, as it was", st == 200 and
              a.get("count") == 7 and a.get("whisper") == "1.9.5" and a["rows"][0]["score_ms"] == 119437 and
              a.get("you") == {"place": 1, "score_ms": 119437}, a)
        st, a = run(base, last[0], last[1], 1500000, whisper="v1.9.6-dev")
        check("the answer names the machine and the run, for the page's address", isinstance(a.get("machine"), int) and
              a["machine"] > 0 and isinstance(a.get("run"), int) and a["run"] > 0, a)
        mine = a["machine"]
        html = urllib.request.urlopen(base + "/index.php?b=benchmark_long_fast&w=1.9.5&m=%d" % mine,
                                      timeout=10).read().decode()
        check("?m= marks that machine's row and says its place", html.count('<tr id="you" class="you">') == 1 and
              "Your computer is in place 7, marked below." in html and
              ("b=benchmark_short_fast&amp;w=1.9.5&amp;m=%d" % mine) in html, html[html.find("<main"):][:1200])
        html = urllib.request.urlopen(base + "/index.php?b=benchmark_short_fast&m=%d" % mine, timeout=10).read().decode()
        check("?m= on a board the machine is not on says so", 'class="you"' not in html and
              "Your computer has no score on this board yet." in html)
        html = urllib.request.urlopen(base + "/index.php?b=benchmark_long_fast&m=x%22%3E", timeout=10).read().decode()
        check("an m that is not a number marks nothing", 'class="you"' not in html and "Your computer" not in html)
        check("'v1.9.6-dev' is 1.9.6", st == 200 and a.get("whisper") == "1.9.6" and a.get("place") == 2 and
              a.get("count") == 2, (st, a))
        st, a = run(base, last[0], last[1], 1500000, whisper="newest")
        check("what is not a version is refused (400)", st == 400, (st, a))
        st, a = call(base, "/api/board.php?benchmark=benchmark_long_fast&whisper=1.10.0")
        check("a version with no scores: an empty board, the versions that have one named", st == 200 and
              a.get("count") == 0 and a.get("whispers") == ["1.9.6", "1.9.5"], a)
        html = urllib.request.urlopen(base + "/index.php?b=benchmark_long_fast", timeout=10).read().decode()
        check("the page opens on the newest version, with links to both", html.count("<td class=\"place\">") == 2 and
              "0:02:10.000" in html and 'w=1.9.5">1.9.5</a>' in html and
              'w=1.9.6" aria-current="true">1.9.6</a>' in html, html[html.find("<main"):][:1500])
        html = urllib.request.urlopen(base + "/index.php?b=benchmark_short_fast&w=1.9.5", timeout=10).read().decode()
        check("the other boards' links keep the version chosen", "b=benchmark_long_fast&amp;w=1.9.5" in html and
              "No scores yet with whisper.cpp 1.9.5" in html)

        print("page")
        html = urllib.request.urlopen(base + "/index.php?b=benchmark_long_fast&w=1.9.5", timeout=10).read().decode()
        check("the page lists the seven", html.count("<td class=\"place\">") == 7 and "0:01:59.437" in html and
              "Player seven" in html and "94x" in html and "<td class=\"num wpm\">14,227</td>" in html and "<span>Vulkan, 24 GB</span>" in html and "48 W of 50" in html and
              html.count("<td class=\"os\">Test OS</td>") == 6)
        con = sqlite3.connect(dbfile)
        con.execute("UPDATE players SET display_name = '<script>alert(1)</script>' WHERE id = 1")
        con.commit()
        html = urllib.request.urlopen(base + "/index.php?b=benchmark_long_fast&w=1.9.5", timeout=10).read().decode()
        check("a name is shown as text, never as markup", "<script>alert(1)</script>" not in html and
              "&lt;script&gt;" in html)
        con.execute("UPDATE machines SET hidden = 1 WHERE id = 1")
        con.commit()
        st, a = call(base, "/api/board.php?benchmark=benchmark_long_fast&rows=3")
        check("a hidden machine is off the board", a.get("count") == 6 and a["rows"][0]["score_ms"] == 155096, a)
        n = con.execute("SELECT COUNT(*) FROM runs").fetchone()[0]
        k = con.execute("SELECT COUNT(*) FROM runs WHERE status = 'rejected'").fetchone()[0]
        v = dict(con.execute("SELECT whisper, COUNT(*) FROM runs GROUP BY whisper").fetchall())
        con.close()
        check("every run was kept, the refused ones with their reason", n == 25 and k == 4, (n, k))
        check("each run has its whisper.cpp version", v == {"1.9.5": 23, "1.9.6": 2}, v)

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
