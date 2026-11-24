<?php
// POST /api/claim.php - an installation WITHOUT a screen joins its owner's
// account with the one-time key the owner made on the site ("Add an
// install without a screen") and started the program with.
//
// Request (JSON):  install_id, key   the installation and its secret
//                  activation_key    the one-time key, as it was typed
//                                    (case and dashes do not count)
// Answer (JSON):   ok true, claimed true
//                  ok false, error "..." (403: the key is wrong, used or
//                  too old; 409: another account has the installation;
//                  429: too many wrong keys from here).

declare(strict_types=1);
require dirname(__DIR__) . '/lib.php';

try {
    $in = ln_body();
    $install = ln_install($in);
    $typed = ln_typed($in['activation_key'] ?? '');
    $sender = ln_sender();
    if (ln_count('wrongkey', $sender, 3600) >= LN_WRONG_PER_HOUR) {
        ln_refuse(429, 'Too many wrong keys from here. Try again in an hour.');
    }

    $db = ln_db();
    $row = false;
    if (strlen($typed) === 12) {
        $q = $db->prepare('SELECT * FROM activation_keys WHERE key_hash = ? AND used_at IS NULL AND expires_at > ?');
        $q->execute([ln_hash('activation', $typed), ln_now()]);
        $row = $q->fetch();
    }
    if (!$row) {
        ln_note('wrongkey', $sender);
        ln_refuse(403, 'That key is not known, was used already or is too old. Make a new one on the site.');
    }
    if ($install['account_id'] !== null && (int) $install['account_id'] !== (int) $row['account_id']) {
        ln_refuse(409, 'This installation belongs to another account. Release it there first.');
    }

    $db->beginTransaction();
    $q = $db->prepare('UPDATE activation_keys SET used_at = ? WHERE id = ? AND used_at IS NULL');
    $q->execute([ln_now(), $row['id']]);
    if ($q->rowCount() !== 1) {
        $db->rollBack();
        ln_refuse(403, 'That key was used a moment ago. Make a new one on the site.');
    }
    $why = ln_claim($install, (int) $row['account_id']);
    if ($why !== '') {
        $db->rollBack();
        ln_refuse(409, $why);
    }
    $db->commit();
    ln_answer(200, ['ok' => true, 'claimed' => true]);
} catch (Throwable $e) {
    if (isset($db) && $db->inTransaction()) {
        $db->rollBack();
    }
    error_log('link claim: ' . $e->getMessage());
    ln_refuse(500, 'The link site could not do that.');
}
