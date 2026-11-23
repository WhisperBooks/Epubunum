-- EpubUnum benchmark leaderboard - database schema (draft 1, 2026-11-23)
-- TBD - A DRAFT, NOTHING DECIDED (owner, 2026-11-23: "Mark everything as
-- TBD - it'll take a while for the website to come up"). Not run against a
-- server. The site, its endpoint, the validation and this schema all wait.
--
-- For https://leaderboard.epubunum.com: scores POSTed by EpubBuilder (Steam
-- and non-Steam builds) to a PHP endpoint.
--
-- MySQL 8.0 or MariaDB 10.4+ (InnoDB, utf8mb4, window functions for ranks).
--
-- What it is built around:
--   * A MACHINE is the unit that is ranked (Steam's own boards rank users:
--     one row each; here one person may have several machines).
--   * EVERY RUN is kept (runs); the board is each machine's best run of a
--     benchmark (bests), so ranking never scans the whole history.
--   * No computer name, user name or raw network address is stored. A
--     machine is known by a random id the program makes on first use; a
--     person by a Steam id or by a name they chose.
--   * Validation is still to be decided: runs.status and runs.verified are
--     where its outcome goes, whatever it turns out to be.

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------------
-- The four benchmarks (fixed rows; the names EpubBuilder and Steam use).
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- A person: a Steam account, or someone without Steam who chose a name.
-- ---------------------------------------------------------------------------
CREATE TABLE players (
  id            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  source        ENUM('steam', 'site') NOT NULL,
  steam_id      BIGINT UNSIGNED NULL,          -- SteamID64; NULL for 'site'
  display_name  VARCHAR(64) NOT NULL,          -- Steam persona, or chosen
  banned        TINYINT(1) NOT NULL DEFAULT 0, -- every run of theirs hidden
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_players_steam (steam_id)       -- many NULLs are allowed
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- A machine: one installation of EpubBuilder. install_id is a random UUID
-- the program makes on first use and keeps in its settings; key_hash is the
-- hash of the secret the site gave that installation when it first
-- registered (the POST carries the secret, never stored in the clear).
-- label is what the owner calls it ("Living-room PC"), never the computer's
-- own name.
-- ---------------------------------------------------------------------------
CREATE TABLE machines (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  player_id   INT UNSIGNED NOT NULL,
  install_id  BINARY(16)   NOT NULL,           -- UUID, UUID_TO_BIN()
  key_hash    BINARY(32)   NOT NULL,           -- SHA-256 of its secret
  label       VARCHAR(40)  NULL,
  os          VARCHAR(60)  NULL,               -- 'Windows 11', 'SteamOS 3'
  cpu         VARCHAR(100) NULL,               -- the processor's description
  memory_gb   SMALLINT UNSIGNED NULL,
  hidden      TINYINT(1) NOT NULL DEFAULT 0,   -- taken off the boards
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_seen   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_machines_install (install_id),
  KEY ix_machines_player (player_id),
  CONSTRAINT fk_machines_player FOREIGN KEY (player_id) REFERENCES players (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- What a benchmark ran on, as whisper.cpp names it. One row per distinct
-- description, so boards can be filtered ("every RTX 5090") and a made-up
-- device stands out.
-- ---------------------------------------------------------------------------
CREATE TABLE devices (
  id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  description  VARCHAR(120) NOT NULL,          -- 'NVIDIA GeForce RTX 5090 Laptop GPU'
  kind         ENUM('cpu', 'integrated', 'gpu') NOT NULL,
  backend      VARCHAR(20) NOT NULL,           -- 'CPU', 'Vulkan', 'Metal', 'CUDA', 'ROCm'
  PRIMARY KEY (id),
  UNIQUE KEY uq_devices (description, kind, backend)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- Every run received. The fields are benchmarks.csv's. score_ms is the
-- score: the time the transcription of the chapter material took.
-- ---------------------------------------------------------------------------
CREATE TABLE runs (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  machine_id     INT UNSIGNED NOT NULL,
  benchmark_id   TINYINT UNSIGNED NOT NULL,
  device_id      INT UNSIGNED NOT NULL,
  score_ms       INT UNSIGNED NOT NULL,
  audio_ms       INT UNSIGNED NOT NULL,        -- as the client measured it
  words          INT UNSIGNED NOT NULL,        -- of the chapter material
  words_matched  INT UNSIGNED NOT NULL,        -- heard as the book has them
  build          VARCHAR(40) NOT NULL,         -- '2026-11-23 02:34, 2ccbf89'
  channel        ENUM('steam', 'direct') NOT NULL,  -- which build sent it
  ran_at         DATETIME NOT NULL,            -- the client's clock, UTC
  received_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  sender_hash    BINARY(32) NULL,              -- salted hash of the address:
                                               -- rate limits, not identity
  verified       TINYINT(1) NOT NULL DEFAULT 0, -- e.g. a Steam ticket checked
  status         ENUM('ok', 'pending', 'rejected') NOT NULL DEFAULT 'pending',
  reject_reason  VARCHAR(120) NULL,
  log_file       VARCHAR(120) NULL,            -- the run's log, if it was sent
  PRIMARY KEY (id),
  KEY ix_runs_machine (machine_id, benchmark_id, score_ms),
  KEY ix_runs_received (received_at),
  KEY ix_runs_sender (sender_hash, received_at),
  CONSTRAINT fk_runs_machine   FOREIGN KEY (machine_id)   REFERENCES machines (id),
  CONSTRAINT fk_runs_benchmark FOREIGN KEY (benchmark_id) REFERENCES benchmarks (id),
  CONSTRAINT fk_runs_device    FOREIGN KEY (device_id)    REFERENCES devices (id),
  CONSTRAINT ck_runs_score CHECK (score_ms > 0),
  CONSTRAINT ck_runs_words CHECK (words_matched <= words)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- The board: each machine's best accepted run of each benchmark. Kept up to
-- date by the endpoint when it accepts a run (the statement is below), so a
-- board page is one indexed range read.
-- ---------------------------------------------------------------------------
CREATE TABLE bests (
  machine_id    INT UNSIGNED NOT NULL,
  benchmark_id  TINYINT UNSIGNED NOT NULL,
  run_id        BIGINT UNSIGNED NOT NULL,
  score_ms      INT UNSIGNED NOT NULL,
  PRIMARY KEY (machine_id, benchmark_id),
  KEY ix_bests_board (benchmark_id, score_ms, run_id),
  CONSTRAINT fk_bests_machine   FOREIGN KEY (machine_id)   REFERENCES machines (id),
  CONSTRAINT fk_bests_benchmark FOREIGN KEY (benchmark_id) REFERENCES benchmarks (id),
  CONSTRAINT fk_bests_run       FOREIGN KEY (run_id)       REFERENCES runs (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===========================================================================
-- The statements the PHP endpoint and pages need (parameters as :name).
-- ===========================================================================

-- A run was accepted (status 'ok'): it becomes the machine's best when it is
-- the first or the faster one.
--
-- INSERT INTO bests (machine_id, benchmark_id, run_id, score_ms)
-- VALUES (:machine_id, :benchmark_id, :run_id, :score_ms)
-- ON DUPLICATE KEY UPDATE
--   run_id   = IF(VALUES(score_ms) < score_ms, VALUES(run_id), run_id),
--   score_ms = LEAST(score_ms, VALUES(score_ms));

-- A page of a board: :rows rows from place :first on (1 = the fastest).
-- Hidden machines and banned players are left out.
--
-- SELECT ranked.place, p.display_name, m.label, d.description AS device,
--        d.backend, ranked.score_ms, r.words, r.words_matched, r.ran_at
-- FROM (
--   SELECT b.machine_id, b.run_id, b.score_ms,
--          RANK() OVER (ORDER BY b.score_ms) AS place
--   FROM bests b
--   JOIN machines m ON m.id = b.machine_id AND m.hidden = 0
--   JOIN players  p ON p.id = m.player_id  AND p.banned = 0
--   WHERE b.benchmark_id = :benchmark_id
-- ) AS ranked
-- JOIN runs     r ON r.id = ranked.run_id
-- JOIN machines m ON m.id = ranked.machine_id
-- JOIN players  p ON p.id = m.player_id
-- JOIN devices  d ON d.id = r.device_id
-- WHERE ranked.place BETWEEN :first AND :first + :rows - 1
-- ORDER BY ranked.place, ranked.run_id;

-- One machine's place on a board, and the board's size (for "around you").
--
-- SELECT 1 + COUNT(*) AS place
-- FROM bests b
-- JOIN machines m ON m.id = b.machine_id AND m.hidden = 0
-- JOIN players  p ON p.id = m.player_id  AND p.banned = 0
-- WHERE b.benchmark_id = :benchmark_id
--   AND b.score_ms < (SELECT score_ms FROM bests
--                     WHERE machine_id = :machine_id AND benchmark_id = :benchmark_id);

-- Everything one person has: their machines and each one's bests.
--
-- SELECT m.label, bm.name, b.score_ms, d.description AS device
-- FROM machines m
-- JOIN bests b       ON b.machine_id = m.id
-- JOIN benchmarks bm ON bm.id = b.benchmark_id
-- JOIN runs r        ON r.id = b.run_id
-- JOIN devices d     ON d.id = r.device_id
-- WHERE m.player_id = :player_id
-- ORDER BY m.id, bm.sort_order;

-- A run is rejected after it was accepted (found to be made up): take it out
-- of bests and put the machine's next best accepted run back.
--
-- UPDATE runs SET status = 'rejected', reject_reason = :why WHERE id = :run_id;
-- DELETE FROM bests WHERE run_id = :run_id;
-- INSERT INTO bests (machine_id, benchmark_id, run_id, score_ms)
-- SELECT machine_id, benchmark_id, id, score_ms FROM runs
-- WHERE machine_id = :machine_id AND benchmark_id = :benchmark_id AND status = 'ok'
-- ORDER BY score_ms, id LIMIT 1;
