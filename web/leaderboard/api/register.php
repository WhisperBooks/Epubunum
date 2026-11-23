<?php
// POST /api/register.php - an installation of EpubBuilder makes itself
// known, once, and is given the secret it sends with every score.
//
// Request (JSON):  install_id  a UUID the program made (required)
//                  name        the name to show (a Steam persona, or
//                              chosen; "Anonymous" when left out)
//                  steam_id    the SteamID64, when the build is Steam's
//                  label       what the owner calls the machine (optional;
//                              never the computer's own name)
//                  os, cpu, memory_gb   descriptions (optional)
// Answer (JSON):   ok true, key "..." - shown ONCE; only its hash is kept.
//                  ok false, error "..." (409: that id is registered).

declare(strict_types=1);
require dirname(__DIR__) . '/lib.php';

try {
    $in = lb_body();
    $installId = lb_install_id($in['install_id'] ?? '');
    if ($installId === '') {
        lb_refuse(400, 'install_id must be a UUID.');
    }
    $name = lb_text($in['name'] ?? '', LB_MAX_NAME);
    if ($name === '') {
        $name = 'Anonymous';
    }
    $steamId = lb_text($in['steam_id'] ?? '', 20);
    if ($steamId !== '' && !preg_match('/^\d{17}$/', $steamId)) {
        lb_refuse(400, 'steam_id must be a SteamID64.');
    }

    $db = lb_db();
    $sender = lb_sender();

    // one address cannot make machines without end
    $q = $db->prepare('SELECT COUNT(*) FROM machines WHERE sender_hash = ? AND created_at > ?');
    $q->execute([$sender, lb_now(-86400)]);
    if ((int) $q->fetchColumn() >= LB_REGISTRATIONS_PER_DAY) {
        lb_refuse(429, 'Too many installations registered from here today.');
    }

    $q = $db->prepare('SELECT 1 FROM machines WHERE install_id = ?');
    $q->execute([$installId]);
    if ($q->fetch()) {
        lb_refuse(409, 'That installation is already registered.');
    }

    $key = bin2hex(random_bytes(32));
    $now = lb_now();

    $db->beginTransaction();
    // the person: the Steam account when there is one (its machines are
    // then one person's), else a person of this machine's own
    $playerId = 0;
    if ($steamId !== '') {
        $q = $db->prepare('SELECT id FROM players WHERE steam_id = ?');
        $q->execute([$steamId]);
        $playerId = (int) $q->fetchColumn();
        if ($playerId > 0) {
            $db->prepare('UPDATE players SET display_name = ? WHERE id = ?')->execute([$name, $playerId]);
        }
    }
    if ($playerId === 0) {
        $db->prepare('INSERT INTO players (source, steam_id, display_name, banned, created_at)
                      VALUES (?, ?, ?, 0, ?)')
           ->execute([$steamId !== '' ? 'steam' : 'site', $steamId !== '' ? $steamId : null, $name, $now]);
        $playerId = (int) $db->lastInsertId();
    }
    $memory = lb_int($in['memory_gb'] ?? null);
    $db->prepare('INSERT INTO machines (player_id, install_id, key_hash, label, os, cpu, memory_gb, hidden,
                                        sender_hash, created_at, last_seen)
                  VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?)')
       ->execute([
           $playerId, $installId, hash('sha256', $key),
           lb_text($in['label'] ?? '', 40) ?: null,
           lb_text($in['os'] ?? '', 60) ?: null,
           lb_text($in['cpu'] ?? '', 100) ?: null,
           ($memory !== null && $memory > 0 && $memory < 65536) ? $memory : null,
           $sender, $now, $now,
       ]);
    $db->commit();

    lb_answer(200, ['ok' => true, 'key' => $key]);
} catch (Throwable $e) {
    if (isset($db) && $db->inTransaction()) {
        $db->rollBack();
    }
    error_log('leaderboard register: ' . $e->getMessage());
    lb_refuse(500, 'The leaderboard could not register the installation.');
}
