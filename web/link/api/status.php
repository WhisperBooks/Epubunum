<?php
// POST /api/status.php - an installation asks where it stands.
//
// Request (JSON):  install_id, key
// Answer (JSON):   ok true, claimed (true when an account has it),
//                  installs - when claimed, the OTHER installations of the
//                  account (install_id, app, label, os): those it may ask
//                  a ticket for, or take one from.

declare(strict_types=1);
require dirname(__DIR__) . '/lib.php';

try {
    $in = ln_body();
    $install = ln_install($in);
    $others = [];
    if ($install['account_id'] !== null) {
        foreach (ln_installs_of((int) $install['account_id']) as $other) {
            if ((int) $other['id'] !== (int) $install['id']) {
                $others[] = ln_install_public($other);
            }
        }
    }
    ln_answer(200, ['ok' => true, 'claimed' => $install['account_id'] !== null, 'installs' => $others]);
} catch (Throwable $e) {
    error_log('link status: ' . $e->getMessage());
    ln_refuse(500, 'The link site could not do that.');
}
