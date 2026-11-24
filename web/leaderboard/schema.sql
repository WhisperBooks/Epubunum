-- EpubUnum benchmark leaderboard - database schema, version 1 (2026-11-23)
-- For https://leaderboard.epubunum.com. Load once into an empty MySQL or
-- MariaDB database (Plesk: Databases > the database > Import Dump, or
-- phpMyAdmin > Import).
--
-- NOT RUN AGAINST MySQL when it was written: the PHP beside it was tested
-- with the same tables in SQLite. If the import stops, the message names
-- the statement - send it back.
--
-- What it is built around:
--   * A MACHINE is the unit that is ranked (Steam's own boards rank users:
--     one row each; here one person may have several machines).
--   * EVERY RUN is kept (runs); the board is each machine's best accepted
--     run of a benchmark (bests), so a board page is one indexed read.
--   * No computer name, user name or network address is stored. A machine
--     is known by a random id the program makes on first use; a sender only
--     by a salted hash, for rate limits.
--   * The PHP uses nothing MySQL-only (no ON DUPLICATE KEY, no window
--     functions), so the same statements run in the SQLite of its tests.

SET NAMES utf8mb4;

-- The four benchmarks (fixed rows; the names EpubBuilder and Steam use).
CREATE TABLE benchmarks (
  id          TINYINT UNSIGNED NOT NULL,
  slug        VARCHAR(40)  NOT NULL,           -- the Steam board's name
  name        VARCHAR(60)  NOT NULL,           -- as the program shows it
  book        VARCHAR(80)  NOT NULL,           -- the reference text
  model       VARCHAR(40)  NOT NULL,           -- the model file
  audio_ms    INT UNSIGNED NOT NULL,           -- chapter material timed, ms
  sort_order  TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_benchmarks_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO benchmarks (id, slug, name, book, model, audio_ms, sort_order) VALUES
  (1, 'benchmark_short_fast',     'Short Text, Fast Model',     'A Scandal in Bohemia', 'ggml-base.bin',            3202850, 1),
  (2, 'benchmark_short_detailed', 'Short Text, Detailed Model', 'A Scandal in Bohemia', 'ggml-large-v3-turbo.bin',  3202850, 2),
  (3, 'benchmark_long_fast',      'Long Text, Fast Model',      'A Christmas Carol',    'ggml-base.bin',           11169310, 3),
  (4, 'benchmark_long_detailed',  'Long Text, Detailed Model',  'A Christmas Carol',    'ggml-large-v3-turbo.bin', 11169310, 4);

-- A person: a Steam account, or someone without Steam who chose a name.
CREATE TABLE players (
  id            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  source        VARCHAR(8) NOT NULL,           -- 'steam' or 'site'
  steam_id      VARCHAR(20) NULL,              -- SteamID64; NULL for 'site'
  display_name  VARCHAR(64) NOT NULL,          -- Steam persona, or chosen
  banned        TINYINT NOT NULL DEFAULT 0,    -- every run of theirs hidden
  created_at    DATETIME NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_players_steam (steam_id)       -- many NULLs are allowed
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- A machine: one installation of EpubBuilder. install_id is a random UUID
-- the program makes on first use; key_hash is the SHA-256 of the secret the
-- site gave that installation when it registered (the secret itself is
-- never stored). label is what the owner calls it, never the computer's
-- own name.
CREATE TABLE machines (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  player_id   INT UNSIGNED NOT NULL,
  install_id  CHAR(36)     NOT NULL,
  key_hash    CHAR(64)     NOT NULL,
  label       VARCHAR(40)  NULL,
  os          VARCHAR(60)  NULL,               -- 'Windows 11', 'SteamOS'
  cpu         VARCHAR(100) NULL,               -- the processor's description
  memory_gb   SMALLINT UNSIGNED NULL,
  hidden      TINYINT NOT NULL DEFAULT 0,      -- taken off the boards
  sender_hash CHAR(64)     NULL,               -- who registered it (limits)
  created_at  DATETIME NOT NULL,
  last_seen   DATETIME NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_machines_install (install_id),
  KEY ix_machines_player (player_id),
  KEY ix_machines_sender (sender_hash, created_at),
  CONSTRAINT fk_machines_player FOREIGN KEY (player_id) REFERENCES players (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- What a benchmark ran on, as whisper.cpp names it: one row per distinct
-- description.
CREATE TABLE devices (
  id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  description  VARCHAR(120) NOT NULL,          -- 'NVIDIA GeForce RTX 5090 Laptop GPU'
  kind         VARCHAR(12) NOT NULL,           -- 'cpu', 'integrated', 'gpu'
  backend      VARCHAR(20) NOT NULL,           -- 'CPU', 'Vulkan', 'Metal', 'CUDA', 'ROCm'
  PRIMARY KEY (id),
  UNIQUE KEY uq_devices (description, kind, backend)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Every run received. The fields are benchmarks.csv's. score_ms is the
-- score: the time the transcription of the chapter material took.
-- status: 'ok' (on the board), 'pending' (kept, not shown: it looks too
-- good to be true and waits for a person), 'rejected' (with the reason).
CREATE TABLE runs (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  machine_id     INT UNSIGNED NOT NULL,
  benchmark_id   TINYINT UNSIGNED NOT NULL,
  device_id      INT UNSIGNED NOT NULL,
  score_ms       INT UNSIGNED NOT NULL,
  audio_ms       INT UNSIGNED NOT NULL,        -- as the client measured it
  words          INT UNSIGNED NOT NULL,        -- of the chapter material
  words_matched  INT UNSIGNED NOT NULL,        -- heard as the book has them
  avg_watts      SMALLINT UNSIGNED NULL,       -- the card's draw: the MEDIAN
  peak_watts     SMALLINT UNSIGNED NULL,       -- (where it can be read; NULL when
  limit_watts    SMALLINT UNSIGNED NULL,       -- not known) and its limit
  build          VARCHAR(40) NOT NULL,         -- '2026-11-23 02:34, 2ccbf89'
  whisper        VARCHAR(16) NOT NULL DEFAULT '1.9.5', -- whisper.cpp's version
  channel        VARCHAR(8) NOT NULL,          -- 'steam' or 'direct'
  ran_at         DATETIME NOT NULL,            -- the client's clock, UTC
  received_at    DATETIME NOT NULL,
  sender_hash    CHAR(64) NULL,                -- salted hash of the address
  verified       TINYINT NOT NULL DEFAULT 0,   -- e.g. a Steam ticket checked
  status         VARCHAR(10) NOT NULL,
  reject_reason  VARCHAR(120) NULL,
  PRIMARY KEY (id),
  KEY ix_runs_machine (machine_id, benchmark_id, status, score_ms),
  KEY ix_runs_machine_time (machine_id, received_at),
  KEY ix_runs_sender (sender_hash, received_at),
  CONSTRAINT fk_runs_machine   FOREIGN KEY (machine_id)   REFERENCES machines (id),
  CONSTRAINT fk_runs_benchmark FOREIGN KEY (benchmark_id) REFERENCES benchmarks (id),
  CONSTRAINT fk_runs_device    FOREIGN KEY (device_id)    REFERENCES devices (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- The boards: each machine's best accepted run of each benchmark UNDER EACH
-- VERSION OF whisper.cpp (a new version can be faster or slower on the
-- same machine, so their scores are not ranked together), kept up to date
-- by the endpoint when it accepts a run.
CREATE TABLE bests (
  machine_id    INT UNSIGNED NOT NULL,
  benchmark_id  TINYINT UNSIGNED NOT NULL,
  whisper       VARCHAR(16) NOT NULL DEFAULT '1.9.5',
  run_id        BIGINT UNSIGNED NOT NULL,
  score_ms      INT UNSIGNED NOT NULL,
  PRIMARY KEY (machine_id, benchmark_id, whisper),
  KEY ix_bests_board (benchmark_id, whisper, score_ms, run_id),
  CONSTRAINT fk_bests_machine   FOREIGN KEY (machine_id)   REFERENCES machines (id),
  CONSTRAINT fk_bests_benchmark FOREIGN KEY (benchmark_id) REFERENCES benchmarks (id),
  CONSTRAINT fk_bests_run       FOREIGN KEY (run_id)       REFERENCES runs (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- By hand, when a score turns out to be made up (the runs.id is on the
-- board's page as the row's number in the address bar is not - look it up):
--
--   UPDATE runs SET status = 'rejected', reject_reason = 'why' WHERE id = 123;
--   DELETE FROM bests WHERE run_id = 123;
--   -- then the machine's next best accepted run, if it has one:
--   INSERT INTO bests (machine_id, benchmark_id, whisper, run_id, score_ms)
--   SELECT machine_id, benchmark_id, whisper, id, score_ms FROM runs
--   WHERE machine_id = 45 AND benchmark_id = 1 AND whisper = '1.9.5' AND status = 'ok'
--   ORDER BY score_ms, id LIMIT 1;
--
-- A whole machine off the boards:  UPDATE machines SET hidden = 1 WHERE id = 45;
-- A person off the boards:         UPDATE players  SET banned = 1 WHERE id = 6;
-- A run waiting for a person:      SELECT * FROM runs WHERE status = 'pending';
--   accept it:  UPDATE runs SET status = 'ok' WHERE id = 123;  then put it in
--   bests if it is the machine's best (the INSERT above, after a DELETE of
--   that machine's row for the benchmark).
