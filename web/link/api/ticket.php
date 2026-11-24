<?php
// POST /api/ticket.php - an installation (the client) asks for a ticket
// to pair with another installation of the same account (the server)
// without the 6-digit code. It hands the ticket to the server on the
// local network; the server shows it to /api/check.php.
//
// Request (JSON):  install_id, key   the client and its secret
//                  server            the server's install id (the id it
//                                    announces on the local network)
// Answer (JSON):   ok true, ticket "...", expires_in (s) - once only
//                  ok false, error "..." (403: not one of this account's
//                  installations - also said when the client has no
//                  account; 429: too many tickets asked for).

declare(strict_types=1);
require dirname(__DIR__) . '/lib.php';

try {
    $in = ln_body();
    $client = ln_install($in);
    $serverId = ln_install_id($in['server'] ?? '');
    if ($serverId === '') {
        ln_refuse(400, 'server must be an install id (a UUID).');
    }
    $who = 'i' . $client['id'];
    if (ln_count('ticket', $who, 3600) >= LN_TICKETS_PER_HOUR) {
        ln_refuse(429, 'Too many tickets asked for. Try again in an hour.');
    }
    ln_note('ticket', $who);

    $db = ln_db();
    $server = false;
    if ($client['account_id'] !== null && $serverId !== $client['install_id']) {
        $q = $db->prepare('SELECT id FROM installs WHERE install_id = ? AND account_id = ?');
        $q->execute([$serverId, $client['account_id']]);
        $server = $q->fetch();
    }
    if (!$server) {
        ln_refuse(403, 'That is not one of this account\'s installations.');
    }
    $ticket = bin2hex(random_bytes(32));
    $db->prepare('INSERT INTO tickets (token_hash, client, server, created_at, expires_at) VALUES (?, ?, ?, ?, ?)')
       ->execute([ln_hash('ticket', $ticket), $client['id'], $server['id'], ln_now(), ln_now(LN_TICKET_SECONDS)]);
    ln_answer(200, ['ok' => true, 'ticket' => $ticket, 'expires_in' => LN_TICKET_SECONDS]);
} catch (Throwable $e) {
    error_log('link ticket: ' . $e->getMessage());
    ln_refuse(500, 'The link site could not do that.');
}
