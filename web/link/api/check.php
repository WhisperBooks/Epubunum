<?php
// POST /api/check.php - an installation (the server) shows the ticket a
// client handed it. When it is good, the client is one of the same
// account's installations and the server may give it its own token.
//
// Request (JSON):  install_id, key   the server and its secret
//                  ticket            what the client handed over
// Answer (JSON):   ok true, client (install_id, app, label, os)
//                  ok false, error "..." (403: the ticket is not for this
//                  installation, was used, is too old, or the two are no
//                  longer of one account).

declare(strict_types=1);
require dirname(__DIR__) . '/lib.php';

try {
    $in = ln_body();
    $server = ln_install($in);
    $ticket = is_string($in['ticket'] ?? null) ? $in['ticket'] : '';
    $refusal = 'That ticket is not good here: ask the other program to try again.';
    if (!preg_match('/^[0-9a-f]{64}$/', $ticket) || $server['account_id'] === null) {
        ln_refuse(403, $refusal);
    }
    $db = ln_db();
    $q = $db->prepare('SELECT t.id, c.install_id, c.app, c.label, c.os, c.account_id
                       FROM tickets t JOIN installs c ON c.id = t.client
                       WHERE t.token_hash = ? AND t.server = ? AND t.used_at IS NULL AND t.expires_at > ?');
    $q->execute([ln_hash('ticket', $ticket), $server['id'], ln_now()]);
    $row = $q->fetch();
    if (!$row || $row['account_id'] === null || (int) $row['account_id'] !== (int) $server['account_id']) {
        ln_refuse(403, $refusal);
    }
    $q = $db->prepare('UPDATE tickets SET used_at = ? WHERE id = ? AND used_at IS NULL');
    $q->execute([ln_now(), $row['id']]);
    if ($q->rowCount() !== 1) {
        ln_refuse(403, $refusal);
    }
    ln_answer(200, ['ok' => true, 'client' => ln_install_public($row)]);
} catch (Throwable $e) {
    error_log('link check: ' . $e->getMessage());
    ln_refuse(500, 'The link site could not do that.');
}
