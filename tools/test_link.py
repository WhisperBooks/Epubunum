#!/usr/bin/env python3
"""Exercises web/link against a throw-away SQLite database.

    python3 tools/test_link.py

Needs php (with pdo_sqlite) on the path. Starts PHP's own web server on a
free local port with LN_CONFIG pointing at a temporary settings file whose
'mail_file' takes the sign-in mails (nothing is sent), then signs in,
registers installations, claims them both ways (a one-time key, a code
from a screen), passes a ticket from one to the other, and checks the
refusals. The tables are the ones of web/link/schema.sql in SQLite's
words (the PHP uses nothing that differs between the two); what this
cannot show is whether schema.sql itself loads into MySQL, or whether the
host sends mail.
"""
import http.cookiejar
import json
import os
import re
import socket
import sqlite3
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SITE = os.path.join(ROOT, "web", "link")

SQLITE_SCHEMA = """
CREATE TABLE accounts (id INTEGER PRIMARY KEY AUTOINCREMENT, email_hash TEXT UNIQUE NOT NULL,
  created_at TEXT NOT NULL, last_seen TEXT NOT NULL);
CREATE TABLE signins (id INTEGER PRIMARY KEY AUTOINCREMENT, email_hash TEXT NOT NULL,
  token_hash TEXT UNIQUE NOT NULL, created_at TEXT NOT NULL, expires_at TEXT NOT NULL, used_at TEXT);
CREATE TABLE sessions (id INTEGER PRIMARY KEY AUTOINCREMENT, account_id INTEGER NOT NULL REFERENCES accounts(id),
  token_hash TEXT UNIQUE NOT NULL, created_at TEXT NOT NULL, expires_at TEXT NOT NULL);
CREATE TABLE installs (id INTEGER PRIMARY KEY AUTOINCREMENT, install_id TEXT UNIQUE NOT NULL,
  key_hash TEXT NOT NULL, app TEXT NOT NULL, label TEXT, os TEXT, account_id INTEGER REFERENCES accounts(id),
  claimed_at TEXT, sender_hash TEXT, created_at TEXT NOT NULL, last_seen TEXT NOT NULL);
CREATE TABLE activation_keys (id INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id INTEGER NOT NULL REFERENCES accounts(id), key_hash TEXT UNIQUE NOT NULL, created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL, used_at TEXT);
CREATE TABLE codes (id INTEGER PRIMARY KEY AUTOINCREMENT, install INTEGER NOT NULL REFERENCES installs(id),
  code_hash TEXT UNIQUE NOT NULL, created_at TEXT NOT NULL, expires_at TEXT NOT NULL, used_at TEXT);
CREATE TABLE tickets (id INTEGER PRIMARY KEY AUTOINCREMENT, token_hash TEXT UNIQUE NOT NULL,
  client INTEGER NOT NULL REFERENCES installs(id), server INTEGER NOT NULL REFERENCES installs(id),
  created_at TEXT NOT NULL, expires_at TEXT NOT NULL, used_at TEXT);
CREATE TABLE attempts (id INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL, who TEXT NOT NULL,
  created_at TEXT NOT NULL);
"""

failures = []


def check(what, ok, detail=""):
    print(("  ok    " if ok else "  FAIL  ") + what + ((" - " + str(detail)[:400]) if detail and not ok else ""))
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


class Browser:
    """A browser with its own cookies: reads the page, sends its forms."""

    def __init__(self, base):
        self.base = base
        self.opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))

    def get(self, path="/"):
        return self.opener.open(self.base + path, timeout=10).read().decode()

    def post(self, **fields):
        data = urllib.parse.urlencode(fields).encode()
        return self.opener.open(self.base + "/", data=data, timeout=10).read().decode()

    def csrf(self):
        found = re.search(r'name="csrf" value="([0-9a-f]{64})"', self.get())
        return found.group(1) if found else ""


def last_mail(mail_file):
    with open(mail_file) as f:
        return json.loads(f.read().strip().split("\n")[-1])


def sign_in(base, mail_file, address):
    """A browser signed in as address (the link from the mail, then its button)."""
    b = Browser(base)
    b.post(action="signin", email=address)
    mail = last_mail(mail_file)
    token = re.search(r"\?t=([0-9a-f]{64})", mail["body"]).group(1)
    b.get("/?t=" + token)
    page = b.post(action="confirm", t=token)
    return b, page, token, mail


def register(base, app, label=None):
    install = str(uuid.uuid4())
    body = {"install_id": install, "app": app, "os": "Test OS 1"}
    if label:
        body["label"] = label
    st, a = call(base, "/api/register.php", body)
    return install, a.get("key", ""), st, a


def main():
    tmp = tempfile.mkdtemp(prefix="lntest-")
    dbfile = os.path.join(tmp, "link.sqlite")
    mail_file = os.path.join(tmp, "mail.jsonl")
    con = sqlite3.connect(dbfile)
    con.executescript(SQLITE_SCHEMA)
    con.commit()
    con.close()

    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    port = s.getsockname()[1]
    s.close()
    base = "http://127.0.0.1:%d" % port
    config = os.path.join(tmp, "config.php")
    with open(config, "w") as f:
        f.write("<?php return ['dsn' => 'sqlite:%s', 'salt' => 'test-salt', 'site' => '%s', 'mail_file' => '%s'];\n"
                % (dbfile, base, mail_file))
    env = dict(os.environ, LN_CONFIG=config)
    server = subprocess.Popen(["php", "-S", "127.0.0.1:%d" % port, "-t", SITE], env=env,
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        for _ in range(50):
            try:
                urllib.request.urlopen(base + "/index.php", timeout=1).read()
                break
            except Exception:
                time.sleep(0.1)

        print("sign in")
        page = Browser(base).get()
        check("signed out, the page asks for a mail address", 'name="email"' in page and "Your installations" not in page)
        page = Browser(base).post(action="signin", email="not an address")
        check("what is not an address is refused, nothing mailed", "does not look like" in page and
              not os.path.exists(mail_file))
        alice, page, token, mail = sign_in(base, mail_file, "Alice@Example.org ")
        check("the mail goes to the address typed, with a link to this site", mail["to"] == "alice@example.org" and
              (base + "/?t=") in mail["body"], mail)
        check("the link's button signs the browser in", "Your installations" in page and "None yet" in page, page)
        other = Browser(base)
        page = other.post(action="confirm", t=token)
        check("a sign-in link works once", "used already" in page and "Your installations" not in page)
        page = Browser(base).post(action="confirm", t="0" * 64)
        check("an unknown sign-in link is refused", "used already" in page)
        con = sqlite3.connect(dbfile)
        kept = " ".join(str(v) for row in con.execute("SELECT * FROM accounts").fetchall() +
                        con.execute("SELECT * FROM signins").fetchall() for v in row)
        check("the address is not in the database", "alice" not in kept.lower() and "example.org" not in kept)
        check("one account was made", con.execute("SELECT COUNT(*) FROM accounts").fetchone()[0] == 1)
        con.close()
        again, page, _, _ = sign_in(base, mail_file, "alice@example.org")
        con = sqlite3.connect(dbfile)
        check("the same address, written otherwise, is the same account",
              con.execute("SELECT COUNT(*) FROM accounts").fetchone()[0] == 1)
        con.close()

        print("register")
        srv, srv_key, st, a = register(base, "BookServer", "Attic server")
        check("an installation registers and gets its key", st == 200 and a.get("ok") and len(srv_key) == 64, (st, a))
        st, a = call(base, "/api/register.php", {"install_id": srv, "app": "BookServer"})
        check("the same id twice is refused (409)", st == 409, (st, a))
        st, a = call(base, "/api/register.php", {"install_id": "not-a-uuid", "app": "BookServer"})
        check("a bad id is refused (400)", st == 400, (st, a))
        st, a = call(base, "/api/register.php", {"install_id": str(uuid.uuid4())})
        check("no app is refused (400)", st == 400, (st, a))
        st, a = call(base, "/api/status.php", {"install_id": srv, "key": srv_key})
        check("a new installation has no account", st == 200 and a.get("claimed") is False and a.get("installs") == [],
              (st, a))
        st, a = call(base, "/api/status.php", {"install_id": srv, "key": "0" * 64})
        check("a wrong key is refused (401)", st == 401, (st, a))
        st, a = call(base, "/api/status.php")
        check("a GET to an endpoint is refused (405)", st == 405, (st, a))

        print("without a screen: the one-time key")
        page = alice.post(action="addkey", csrf=alice.csrf())
        found = re.search(r'<p class="key">([A-Z0-9-]{14})</p>', page)
        check("the account makes a key, shown once", bool(found), page)
        key = found.group(1) if found else ""
        check("the key is not shown again", key not in alice.get())
        st, a = call(base, "/api/claim.php", {"install_id": srv, "key": srv_key, "activation_key": "AAAA-BBBB-CCCC"})
        check("a wrong key is refused (403)", st == 403, (st, a))
        st, a = call(base, "/api/claim.php", {"install_id": srv, "key": srv_key,
                                              "activation_key": " " + key.lower().replace("-", " ")})
        check("the key claims the installation (case and dashes do not count)", st == 200 and a.get("claimed") is True,
              (st, a))
        page = alice.get()
        check("the page lists it under its label", "Attic server" in page and "BookServer, Test OS 1" in page, page)
        spare, spare_key, _, _ = register(base, "BookServer")
        st, a = call(base, "/api/claim.php", {"install_id": spare, "key": spare_key, "activation_key": key})
        check("a key works once (403)", st == 403, (st, a))

        print("with a screen: the code")
        tv, tv_key, _, _ = register(base, "BookManager", "<b>Den</b>")
        st, a = call(base, "/api/code.php", {"install_id": tv, "key": tv_key})
        code = a.get("code", "")
        check("an installation gets a code to show", st == 200 and re.fullmatch(r"[A-Z2-9]{4}-[A-Z2-9]{4}", code) and
              a.get("url") == base + "/?code=" + code and a.get("interval") == 5, (st, a))
        st, a2 = call(base, "/api/code.php", {"install_id": tv, "key": tv_key})
        code2 = a2.get("code", "")
        page = alice.post(action="code", code=code, csrf=alice.csrf())
        check("a new code ends the one before", "not known" in page and code2 != code, page)
        page = alice.post(action="code", code=code2, csrf="0" * 64)
        check("a form without the session's mark does nothing", "too old" in page)
        st, a = call(base, "/api/status.php", {"install_id": tv, "key": tv_key})
        check("... and the installation is still unclaimed", a.get("claimed") is False, a)
        page = Browser(base).get("/?code=" + code2)
        check("signed out, the code in the address is kept for after", code2 in page and 'name="email"' in page)
        page = alice.post(action="code", code=code2.lower(), csrf=alice.csrf())
        check("the code typed on the site claims it", "is now one of your installations" in page, page)
        check("a label is shown as text, never as markup", "<b>Den</b>" not in page and "&lt;b&gt;Den&lt;/b&gt;" in page)
        st, a = call(base, "/api/status.php", {"install_id": tv, "key": tv_key})
        check("the installation learns it, and of the other one", st == 200 and a.get("claimed") is True and
              [i["install_id"] for i in a.get("installs", [])] == [srv] and a["installs"][0]["label"] == "Attic server",
              (st, a))
        st, a = call(base, "/api/code.php", {"install_id": tv, "key": tv_key})
        check("a claimed installation gets no code (409)", st == 409, (st, a))

        print("tickets")
        st, a = call(base, "/api/ticket.php", {"install_id": tv, "key": tv_key, "server": srv})
        ticket = a.get("ticket", "")
        check("a client gets a ticket for a server of its account", st == 200 and len(ticket) == 64, (st, a))
        st, a = call(base, "/api/check.php", {"install_id": spare, "key": spare_key, "ticket": ticket})
        check("another installation cannot use it (403)", st == 403, (st, a))
        st, a = call(base, "/api/check.php", {"install_id": tv, "key": tv_key, "ticket": ticket})
        check("nor the client itself (403)", st == 403, (st, a))
        st, a = call(base, "/api/check.php", {"install_id": srv, "key": srv_key, "ticket": ticket})
        check("the server it was made for is told who the client is", st == 200 and
              a.get("client", {}).get("install_id") == tv and a["client"]["app"] == "BookManager", (st, a))
        st, a = call(base, "/api/check.php", {"install_id": srv, "key": srv_key, "ticket": ticket})
        check("a ticket works once (403)", st == 403, (st, a))
        st, a = call(base, "/api/ticket.php", {"install_id": spare, "key": spare_key, "server": srv})
        check("an installation without an account gets no ticket (403)", st == 403, (st, a))
        st, a = call(base, "/api/ticket.php", {"install_id": tv, "key": tv_key, "server": tv})
        check("no ticket for itself (403)", st == 403, (st, a))

        bob, page, _, _ = sign_in(base, mail_file, "bob@example.org")
        page = bob.post(action="addkey", csrf=bob.csrf())
        bob_key = re.search(r'<p class="key">([A-Z0-9-]{14})</p>', page).group(1)
        st, a = call(base, "/api/claim.php", {"install_id": spare, "key": spare_key, "activation_key": bob_key})
        check("a second account claims its own installation", st == 200, (st, a))
        check("an account sees only its own", "Attic server" not in bob.get() and "BookServer" in bob.get())
        st, a = call(base, "/api/ticket.php", {"install_id": spare, "key": spare_key, "server": srv})
        check("no ticket for another account's server (403)", st == 403, (st, a))
        page = bob.post(action="addkey", csrf=bob.csrf())
        bob_key2 = re.search(r'<p class="key">([A-Z0-9-]{14})</p>', page).group(1)
        st, a = call(base, "/api/claim.php", {"install_id": srv, "key": srv_key, "activation_key": bob_key2})
        check("an installation with an account is not taken by another (409)", st == 409, (st, a))
        page = bob.post(action="remove", install=srv, csrf=bob.csrf())
        st, a = call(base, "/api/status.php", {"install_id": srv, "key": srv_key})
        check("nor removed by another", a.get("claimed") is True, a)

        print("leaving")
        st, a = call(base, "/api/ticket.php", {"install_id": tv, "key": tv_key, "server": srv})
        ticket = a.get("ticket", "")
        page = alice.post(action="remove", install=tv, csrf=alice.csrf())
        check("the account removes an installation", "Removed" in page and "&lt;b&gt;Den" not in page, page)
        st, a = call(base, "/api/check.php", {"install_id": srv, "key": srv_key, "ticket": ticket})
        check("its waiting ticket is gone with it (403)", st == 403, (st, a))
        st, a = call(base, "/api/release.php", {"install_id": srv, "key": srv_key})
        st2, a2 = call(base, "/api/status.php", {"install_id": srv, "key": srv_key})
        check("an installation releases itself", st == 200 and a2.get("claimed") is False, (a, a2))
        page = alice.post(action="delete", csrf=alice.csrf())
        check("deleting the account needs the box ticked", "Tick the box" in page)
        page = bob.post(action="signout", csrf=bob.csrf())
        check("signing out", 'name="email"' in page and "Your installations" not in bob.get())
        page = alice.post(action="delete", sure="yes", csrf=alice.csrf())
        con = sqlite3.connect(dbfile)
        left = con.execute("SELECT COUNT(*) FROM accounts").fetchone()[0]
        mine = con.execute("SELECT COUNT(*) FROM sessions WHERE account_id = 1").fetchone()[0]
        con.close()
        check("deleting the account: it and its sessions are gone, the browser signed out",
              left == 1 and mine == 0 and 'name="email"' in page and "Your installations" not in again.get(), (left, mine))

        print("limits")
        con = sqlite3.connect(dbfile)
        con.execute("UPDATE signins SET expires_at = '2000-01-01 00:00:00' WHERE used_at IS NULL")
        con.commit()
        con.close()
        carol = Browser(base)
        carol.post(action="signin", email="carol@example.org")
        old = re.search(r"\?t=([0-9a-f]{64})", last_mail(mail_file)["body"]).group(1)
        con = sqlite3.connect(dbfile)
        con.execute("UPDATE signins SET expires_at = '2000-01-01 00:00:00' WHERE used_at IS NULL")
        con.commit()
        con.close()
        check("a sign-in link too old is refused", "used already" in carol.post(action="confirm", t=old))
        pages = [carol.post(action="signin", email="carol@example.org") for _ in range(3)]
        check("the 4th sign-in mail in an hour to one address is refused", "Look at your mail" in pages[1] and
              "Too many sign-in mails" in pages[2], [p[-900:-600] for p in pages])
        codes = [call(base, "/api/claim.php", {"install_id": tv, "key": tv_key, "activation_key": "AAAA-BBBB-CC%02d" % i})[0]
                 for i in range(10)]
        check("wrong keys: refused, then no more tries from there (429)", codes[:8] == [403] * 8 and codes[9] == 429,
              codes)
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
