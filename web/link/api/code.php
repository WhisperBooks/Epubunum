<?php
// POST /api/code.php - an installation WITH a screen asks for a code to
// show. Its owner types the code on the site, signed in; the installation
// asks /api/status.php every `interval` seconds until `claimed` is true.
//
// Request (JSON):  install_id, key
// Answer (JSON):   ok true, code "ABCD-EFGH", url (the site, with the
//                  code in it - for a QR code), site (to show beside the
//                  code), expires_in (s), interval (s)
//                  ok false, error "..." (409: it has an account already;
//                  429: too many codes asked for).

declare(strict_types=1);
require dirname(__DIR__) . '/lib.php';

try {
    $in = ln_body();
    $install = ln_install($in);
    if ($install['account_id'] !== null) {
        ln_refuse(409, 'This installation has an account already.');
    }
    $who = 'i' . $install['id'];
    if (ln_count('code', $who, 3600) >= LN_CODES_PER_HOUR) {
        ln_refuse(429, 'Too many codes asked for. Try again in an hour.');
    }
    ln_note('code', $who);

    $db = ln_db();
    // a new code ends the one before
    $db->prepare('DELETE FROM codes WHERE install = ?')->execute([$install['id']]);
    $code = '';
    for ($try = 0; $try < 5 && $code === ''; $try++) {
        $letters = ln_letters(8);
        $q = $db->prepare('SELECT 1 FROM codes WHERE code_hash = ?');
        $q->execute([ln_hash('code', $letters)]);
        if (!$q->fetch()) {
            $code = $letters;
        }
    }
    if ($code === '') {
        throw new RuntimeException('no free code');
    }
    $db->prepare('INSERT INTO codes (install, code_hash, created_at, expires_at) VALUES (?, ?, ?, ?)')
       ->execute([$install['id'], ln_hash('code', $code), ln_now(), ln_now(LN_CODE_MINUTES * 60)]);

    $site = ln_config()['site'];
    $shown = ln_grouped($code);
    ln_answer(200, [
        'ok' => true,
        'code' => $shown,
        'url' => $site . '/?code=' . $shown,
        'site' => preg_replace('#^https?://#', '', $site),
        'expires_in' => LN_CODE_MINUTES * 60,
        'interval' => LN_POLL_SECONDS,
    ]);
} catch (Throwable $e) {
    error_log('link code: ' . $e->getMessage());
    ln_refuse(500, 'The link site could not do that.');
}
