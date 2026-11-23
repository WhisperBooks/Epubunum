# The benchmark leaderboard - https://leaderboard.epubunum.com

PHP (7.4 or later, with PDO for MySQL) and a MySQL or MariaDB database.
Each row of a board is one **machine's** best run of a benchmark (Steam's
own boards keep one row for each user); every run sent is kept.

| File | What it is |
|---|---|
| `index.php` | the public page: the four boards |
| `api/register.php` | an installation makes itself known and gets its key |
| `api/submit.php` | a score |
| `api/board.php` | a page of a board, as JSON, for the programs |
| `lib.php` | what they share (the rules of version 1 are its constants) |
| `schema.sql` | the tables - load once |
| `config.sample.php` | the settings to copy and fill in |
| `.htaccess` | keeps visitors out of everything but the page and `api/` |

## Putting it up (Plesk)

1. **The database**: Databases > Add Database (note its name, user and
   password). Then Import Dump (or phpMyAdmin > Import) with `schema.sql`.
   It was not run against MySQL when written: if the import stops, the
   message names the statement.
2. **The settings**: copy `config.sample.php`, fill in the three database
   values and a long random `salt`, and upload it as
   `leaderboard-config.php` ONE FOLDER ABOVE the document root (beside
   `httpdocs`, not in it). If that folder cannot be written to, upload it
   as `config.php` beside `index.php` instead. Never put the filled-in
   file in the repository (`.gitignore` leaves `config.php` out).
3. **The files**: everything in this folder except `README.md` and
   `config.sample.php` into the document root, with the `api` folder;
   remove the default `index.html` there.
4. **Look**: the address shows "The benchmark leaderboard" with four empty
   boards. "The leaderboard is being set up" means the settings file was
   not found or the database refused the connection (the reason is in the
   domain's PHP error log, never on the page).

## Changes to a database already made

Run the statement BEFORE uploading the PHP files that need it (the newer
`submit.php` writes the new columns; without them every score fails).

- 2026-11-23, zip 274 - the power an NVIDIA card drew:

  ```sql
  ALTER TABLE runs
    ADD COLUMN avg_watts   SMALLINT UNSIGNED NULL AFTER words_matched,
    ADD COLUMN peak_watts  SMALLINT UNSIGNED NULL AFTER avg_watts,
    ADD COLUMN limit_watts SMALLINT UNSIGNED NULL AFTER peak_watts;
  ```

To empty the boards (never `benchmarks`: it is the list of boards):

```sql
DELETE FROM bests; DELETE FROM runs; DELETE FROM devices;
DELETE FROM machines; DELETE FROM players;
```

## What version 1 checks (owner, 2026-11-23: validation "TBD")

- An installation registers once with a random id and is given a key; a
  score needs both. Only the key's hash is kept.
- At most 20 scores an hour from a machine, 60 from an address, 10 new
  installations a day from an address.
- A score is **refused** (and kept with the reason) when it is not the
  benchmark's model or recording, when fewer than 90 % of the words were
  matched, or when the speed is not possible (under 0.05x or over 5000x).
- A score faster than 400x real time is **kept but not shown** (`pending`)
  until a person accepts it. The fastest machine known is about 120x.
- Nothing proves a time: the program that measures it is the sender's.
  `schema.sql` ends with the statements for taking a run, a machine or a
  person off the boards by hand.
- Not yet: checking a Steam ticket (`runs.verified` is there for it).

## Privacy

No computer name, account name or network address is stored. A machine is
its random id; a sender is a salted hash, used only to count. The name
shown is the one the program sends (a Steam name, or one the user chose;
"Anonymous" otherwise). There are no cookies and nothing from other sites.

## The endpoints

All answers are JSON: `{"ok": true, ...}` or `{"ok": false, "error": "..."}`
with a fitting HTTP status (400 not as expected, 401 unknown installation
or wrong key, 409 already registered, 422 score not accepted, 429 too
many, 500 the site's own trouble).

`POST /api/register.php` - body: `install_id` (a UUID), and optionally
`name`, `steam_id` (SteamID64: machines of one Steam account are one
person's), `label` (what the owner calls the machine), `os`, `cpu`,
`memory_gb`. Answer: `key` - given once.

`POST /api/submit.php` - body: `install_id`, `key`, `benchmark`
(`benchmark_short_fast`, `benchmark_short_detailed`, `benchmark_long_fast`,
`benchmark_long_detailed`), `score_ms`, `audio_ms`, `words`,
`words_matched`, `model`, `device`, `device_kind` (`cpu`, `integrated`,
`gpu`), `backend`, `build`, `channel` (`steam`, `direct`), `ran_at`
(`YYYY-MM-DD HH:MM:SS`, UTC), optionally `name`, `os` (the system now:
it replaces the registration's), and `avg_watts`,
`peak_watts`, `limit_watts` (what the card drew over the run - `avg_watts`
is the MEDIAN of the readings since EpubBuilder's zip 276, the mean in the
few runs before; the name stayed - and the limit it was held to; NVIDIA cards, and AMD's on Linux; a value outside 1 - 2000 is not
kept and the score still is). Answer: `status` (`ok`,
`pending`), `improved`, `place`, `best_ms`, `count`.

`GET /api/board.php?benchmark=...` - optionally `rows` (25; 100 at most),
`first` (the first row's place), `around=<install id>` (the page with that
machine in its middle, full at either end of the board), `install=<install
id>` (marks its rows). Answer: `benchmark`, `count`, `first`, `rows`
(`place`, `name`, `label`, `score_ms`, `score`, `device`, `backend`, `os`,
`avg_watts`, `peak_watts`, `limit_watts` - null when not known -, `me`),
`you` (`place`, `score_ms`) or null.

## Testing

`python3 tools/test_leaderboard.py` (from the repository's root; needs
`php` with SQLite) runs the site on a local port against a throw-away
SQLite database and checks registration, the refusals, the boards, the
page and the rate limit.
