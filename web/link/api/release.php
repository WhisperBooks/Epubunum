<?php
// POST /api/release.php - an installation leaves its account (the
// program's own "Sign out of the link site"). It stays registered and can
// be claimed again.
//
// Request (JSON):  install_id, key
// Answer (JSON):   ok true, claimed false

declare(strict_types=1);
require dirname(__DIR__) . '/lib.php';

try {
    $in = ln_body();
    $install = ln_install($in);
    ln_release((int) $install['id']);
    ln_answer(200, ['ok' => true, 'claimed' => false]);
} catch (Throwable $e) {
    error_log('link release: ' . $e->getMessage());
    ln_refuse(500, 'The link site could not do that.');
}
