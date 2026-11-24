-- epubunum link - database schema, version 1 (2026-11-24)
-- For https://link.epubunum.com. Load once into an empty MySQL or MariaDB
-- database (Plesk: Databases > the database > Import Dump, or phpMyAdmin >
-- Import). A database of its own, or the leaderboard's: no table name is
-- shared with it.
--
-- NOT RUN AGAINST MySQL when it was written: the PHP beside it was tested
-- with the same tables in SQLite (tools/test_link.py). If the import
-- stops, the message names the statement - send it back.
--
-- What it is built around:
--   * An ACCOUNT is a person, known only by the salted hash of the mail
--     address they sign in with. The address itself is NOT stored: it is
--     typed at every sign-in and the link is mailed to what was typed.
--   * An INSTALL is one installation of a program (BookServer,
--     BookManager, EpubBuilder, a reader): a random id it made, and the
--     hash of the secret the site gave it. An account CLAIMS it.
--   * Installs of one account trust each other: a TICKET the site gives
--     one of them is taken by the other in place of the 6-digit code.
--   * Every key, code, ticket, session and sign-in link is kept as a
--     salted hash, works once and for a short time.
--   * No computer name, user name or network address is stored. A sender
--     is a salted hash, for rate limits.
--   * The PHP uses nothing MySQL-only (no ON DUPLICATE KEY, no window
--     functions), so the same statements run in the SQLite of its tests.

SET NAMES utf8mb4;

-- A person.
CREATE TABLE accounts (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  email_hash  CHAR(64) NOT NULL,               -- salted hash of the address
  created_at  DATETIME NOT NULL,
  last_seen   DATETIME NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_accounts_email (email_hash)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- A sign-in link that was mailed (15 minutes, once).
CREATE TABLE signins (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  email_hash  CHAR(64) NOT NULL,
  token_hash  CHAR(64) NOT NULL,
  created_at  DATETIME NOT NULL,
  expires_at  DATETIME NOT NULL,
  used_at     DATETIME NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_signins_token (token_hash),
  KEY ix_signins_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- A browser that is signed in (30 days).
CREATE TABLE sessions (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  account_id  INT UNSIGNED NOT NULL,
  token_hash  CHAR(64) NOT NULL,
  created_at  DATETIME NOT NULL,
  expires_at  DATETIME NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_sessions_token (token_hash),
  KEY ix_sessions_account (account_id),
  CONSTRAINT fk_sessions_account FOREIGN KEY (account_id) REFERENCES accounts (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- An installation of a program. install_id is a random UUID the program
-- made (the id it announces on the local network); key_hash is the hash of
-- the secret the site gave it when it registered. account_id is NULL until
-- an account claims it. label is what the owner calls it, never the
-- computer's own name.
CREATE TABLE installs (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  install_id  CHAR(36)    NOT NULL,
  key_hash    CHAR(64)    NOT NULL,
  app         VARCHAR(32) NOT NULL,            -- 'BookServer', 'BookManager' ...
  label       VARCHAR(40) NULL,
  os          VARCHAR(60) NULL,
  account_id  INT UNSIGNED NULL,
  claimed_at  DATETIME NULL,
  sender_hash CHAR(64)    NULL,                -- who registered it (limits)
  created_at  DATETIME NOT NULL,
  last_seen   DATETIME NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_installs_install (install_id),
  KEY ix_installs_account (account_id),
  KEY ix_installs_sender (sender_hash, created_at),
  CONSTRAINT fk_installs_account FOREIGN KEY (account_id) REFERENCES accounts (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- A one-time key an account made for an install WITHOUT a screen: the
-- program is started with it once (an hour, once).
CREATE TABLE activation_keys (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  account_id  INT UNSIGNED NOT NULL,
  key_hash    CHAR(64) NOT NULL,
  created_at  DATETIME NOT NULL,
  expires_at  DATETIME NOT NULL,
  used_at     DATETIME NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_activation_keys_key (key_hash),
  KEY ix_activation_keys_account (account_id, created_at),
  CONSTRAINT fk_activation_keys_account FOREIGN KEY (account_id) REFERENCES accounts (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- A code an install WITH a screen shows, to be typed on the site by its
-- owner, signed in (10 minutes, once; a new one ends the one before).
CREATE TABLE codes (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  install     INT UNSIGNED NOT NULL,           -- installs.id
  code_hash   CHAR(64) NOT NULL,
  created_at  DATETIME NOT NULL,
  expires_at  DATETIME NOT NULL,
  used_at     DATETIME NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_codes_code (code_hash),
  KEY ix_codes_install (install, created_at),
  CONSTRAINT fk_codes_install FOREIGN KEY (install) REFERENCES installs (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- A ticket: install `client` may pair with install `server` (both of one
-- account) without the 6-digit code (2 minutes, once).
CREATE TABLE tickets (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  token_hash  CHAR(64) NOT NULL,
  client      INT UNSIGNED NOT NULL,           -- installs.id
  server      INT UNSIGNED NOT NULL,           -- installs.id
  created_at  DATETIME NOT NULL,
  expires_at  DATETIME NOT NULL,
  used_at     DATETIME NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tickets_token (token_hash),
  KEY ix_tickets_client (client, created_at),
  CONSTRAINT fk_tickets_client FOREIGN KEY (client) REFERENCES installs (id),
  CONSTRAINT fk_tickets_server FOREIGN KEY (server) REFERENCES installs (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- What is counted for the rate limits: who (a salted hash, or 'a' + an
-- account's id, or 'i' + an install's id) did what, when. Rows older than
-- a day are removed as the site is used.
CREATE TABLE attempts (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  kind        VARCHAR(12) NOT NULL,
  who         VARCHAR(64) NOT NULL,
  created_at  DATETIME NOT NULL,
  PRIMARY KEY (id),
  KEY ix_attempts (kind, who, created_at),
  KEY ix_attempts_time (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- By hand (phpMyAdmin), when needed:
--   an install off its account:
--     UPDATE installs SET account_id = NULL, claimed_at = NULL WHERE install_id = '...';
--   everything, for a clean slate (in this order):
--     DELETE FROM tickets; DELETE FROM codes; DELETE FROM activation_keys;
--     DELETE FROM sessions; DELETE FROM signins; DELETE FROM attempts;
--     DELETE FROM installs; DELETE FROM accounts;
