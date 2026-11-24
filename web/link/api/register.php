<?php
// POST /api/register.php - an installation makes itself known, once, and
// is given the secret it sends with every other call.
//
// Request (JSON):  install_id  a UUID the program made (required; the id
//                              it announces on the local network)
//                  app         'BookServer', 'BookManager', 'EpubBuilder'
//                              ... (required)
//                  label       what the owner calls it (optional; never
//                              the computer's own name unless the owner
//                              chose it)
//                  os          the system, as a description (optional)
// Answer (JSON):   ok true, key "..." - given ONCE; only its hash is kept.
//                  ok false, error "..." (409: that id is registered).

declare(strict_types=1);
require dirname(__DIR__) . '/lib.php';

try {
    $in = ln_body();
    $installId = ln_install_id($in['install_id'] ?? '');
    if ($installId === '') {
        ln_refuse(400, 'install_id must be a UUID.');
    }
    $app = ln_text($in['app'] ?? '', 32);
    if ($app === '') {
        ln_refuse(400, 'app is needed.');
    }

    $db = ln_db();
    $sender = ln_sender();
    $q = $db->prepare('SELECT COUNT(*) FROM installs WHERE sender_hash = ? AND created_at > ?');
    $q->execute([$sender, ln_now(-86400)]);
    if ((int) $q->fetchColumn() >= LN_REGISTRATIONS_PER_DAY) {
        ln_refuse(429, 'Too many installations registered from here today.');
    }
    $q = $db->prepare('SELECT 1 FROM installs WHERE install_id = ?');
    $q->execute([$installId]);
    if ($q->fetch()) {
        ln_refuse(409, 'That installation is already registered.');
    }

    $key = bin2hex(random_bytes(32));
    $now = ln_now();
    $db->prepare('INSERT INTO installs (install_id, key_hash, app, label, os, sender_hash, created_at, last_seen)
                  VALUES (?, ?, ?, ?, ?, ?, ?, ?)')
       ->execute([
           $installId, ln_hash('install', $key), $app,
           ln_text($in['label'] ?? '', 40) ?: null,
           ln_text($in['os'] ?? '', 60) ?: null,
           $sender, $now, $now,
       ]);
    ln_answer(200, ['ok' => true, 'key' => $key]);
} catch (Throwable $e) {
    error_log('link register: ' . $e->getMessage());
    ln_refuse(500, 'The link site could not register the installation.');
}
