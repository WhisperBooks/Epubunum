<?php
// epubunum link - what the page and the endpoints share.
// PHP 7.4 or later. Nothing is printed by this file.

declare(strict_types=1);

/** The rules of version 1. */
const LN_SIGNIN_MINUTES = 15;        // a mailed sign-in link works this long, once
const LN_SESSION_DAYS = 30;          // a browser stays signed in this long
const LN_KEY_MINUTES = 60;           // a one-time activation key
const LN_CODE_MINUTES = 10;          // a code shown on an install's screen
const LN_TICKET_SECONDS = 120;       // a pairing ticket
const LN_POLL_SECONDS = 5;           // how often an install showing a code asks
const LN_MAX_INSTALLS = 50;          // installs of one account
const LN_MAILS_PER_ADDRESS = 3;      // sign-in mails an hour to one address
const LN_MAILS_PER_SENDER = 10;      // sign-in mails an hour asked from one place
const LN_REGISTRATIONS_PER_DAY = 10; // installs registered from one place
const LN_WRONG_PER_HOUR = 10;        // wrong keys / codes from one place or account
const LN_KEYS_PER_HOUR = 10;         // activation keys an account makes
const LN_CODES_PER_HOUR = 6;         // codes an install asks for
const LN_TICKETS_PER_HOUR = 30;      // tickets an install asks for
const LN_COOKIE = 'link_session';
/** The letters of keys and codes: none that is taken for another (no I, L, O, U, 0, 1). */
const LN_ALPHABET = 'ABCDEFGHJKMNPQRSTVWXYZ23456789';

/**
 * The settings: an array from a PHP file that is NOT in the repository.
 * Looked for in: the path in the environment's LN_CONFIG (tests), a
 * link-config.php one folder above the site (outside the web root), a
 * config.php beside this file (kept from visitors by .htaccess).
 */
function ln_config(): array
{
    static $config = null;
    if ($config !== null) {
        return $config;
    }
    $places = [];
    $env = getenv('LN_CONFIG');
    if (is_string($env) && $env !== '') {
        $places[] = $env;
    }
    $places[] = dirname(__DIR__) . '/link-config.php';
    $places[] = __DIR__ . '/config.php';
    foreach ($places as $place) {
        if (is_file($place)) {
            $config = require $place;
            if (!is_array($config) || empty($config['dsn']) || empty($config['salt']) || empty($config['site'])) {
                throw new RuntimeException('The link settings are incomplete.');
            }
            $config['site'] = rtrim((string) $config['site'], '/');
            return $config;
        }
    }
    throw new RuntimeException('The link site is not set up yet (no settings file).');
}

/** The database. */
function ln_db(): PDO
{
    static $db = null;
    if ($db === null) {
        $c = ln_config();
        $db = new PDO($c['dsn'], $c['user'] ?? null, $c['password'] ?? null, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]);
    }
    return $db;
}

/** Now, UTC, as the tables keep it. */
function ln_now(int $offsetSeconds = 0): string
{
    return gmdate('Y-m-d H:i:s', time() + $offsetSeconds);
}

/** What is kept of a secret (an address, a key, a code, a token): its salted hash. */
function ln_hash(string $kind, string $value): string
{
    return hash_hmac('sha256', $kind . '|' . $value, (string) ln_config()['salt']);
}

/** Who is asking, as a salted hash: for rate limits, never shown, not an address. */
function ln_sender(): string
{
    return ln_hash('sender', (string) ($_SERVER['REMOTE_ADDR'] ?? 'unknown'));
}

/** How often $who did $kind in the last $seconds. */
function ln_count(string $kind, string $who, int $seconds): int
{
    $q = ln_db()->prepare('SELECT COUNT(*) FROM attempts WHERE kind = ? AND who = ? AND created_at > ?');
    $q->execute([$kind, $who, ln_now(-$seconds)]);
    return (int) $q->fetchColumn();
}

/** Notes that $who did $kind now. */
function ln_note(string $kind, string $who): void
{
    ln_db()->prepare('INSERT INTO attempts (kind, who, created_at) VALUES (?, ?, ?)')
           ->execute([$kind, $who, ln_now()]);
}

/** Removes what no longer works (called now and then). */
function ln_tidy(): void
{
    $db = ln_db();
    $now = ln_now();
    $db->prepare('DELETE FROM attempts WHERE created_at < ?')->execute([ln_now(-86400)]);
    foreach (['signins', 'sessions', 'activation_keys', 'codes', 'tickets'] as $table) {
        $db->prepare('DELETE FROM ' . $table . ' WHERE expires_at < ?')->execute([$now]);
    }
}

/** A random text of $length letters of LN_ALPHABET. */
function ln_letters(int $length): string
{
    $out = '';
    $last = strlen(LN_ALPHABET) - 1;
    for ($i = 0; $i < $length; $i++) {
        $out .= LN_ALPHABET[random_int(0, $last)];
    }
    return $out;
}

/** A key or code as it is shown: in fours, 'ABCD-EFGH'. */
function ln_grouped(string $letters): string
{
    return implode('-', str_split($letters, 4));
}

/** A key or code as it was typed, without what does not count: upper case, the alphabet's letters only. */
function ln_typed($value): string
{
    if (!is_string($value)) {
        return '';
    }
    $text = strtoupper(substr($value, 0, 64));
    return preg_replace('/[^' . LN_ALPHABET . ']/', '', $text) ?? '';
}

/** Answers with JSON and ends. */
function ln_answer(int $status, array $body): void
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    header('X-Content-Type-Options: nosniff');
    echo json_encode($body, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

/** Answers that something was wrong with the request, and ends. */
function ln_refuse(int $status, string $why): void
{
    ln_answer($status, ['ok' => false, 'error' => $why]);
}

/** The JSON object a POST carries (64 KB at most). */
function ln_body(): array
{
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        ln_refuse(405, 'This address takes a POST.');
    }
    $raw = file_get_contents('php://input', false, null, 0, 65537);
    if ($raw === false || strlen($raw) > 65536) {
        ln_refuse(413, 'The request is too large.');
    }
    $data = json_decode($raw, true);
    if (!is_array($data)) {
        ln_refuse(400, 'The request is not a JSON object.');
    }
    return $data;
}

/** A text field: trimmed, no control characters, cut to $max characters. */
function ln_text($value, int $max): string
{
    if (!is_string($value) && !is_int($value)) {
        return '';
    }
    $text = preg_replace('/[\x00-\x1F\x7F]+/u', ' ', (string) $value);
    if ($text === null) {
        return '';
    }
    $text = trim(preg_replace('/\s+/u', ' ', $text) ?? '');
    return mb_substr($text, 0, $max);
}

/** An install id: a UUID, lower case; '' when it is not one. */
function ln_install_id($value): string
{
    $id = strtolower(trim((string) (is_string($value) ? $value : ''), "{} \t\r\n"));
    return preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/', $id) ? $id : '';
}

/**
 * The install a request's install_id and key belong to. Ends the request
 * with 400 or 401 when there is none.
 */
function ln_install(array $in): array
{
    $installId = ln_install_id($in['install_id'] ?? '');
    $key = is_string($in['key'] ?? null) ? $in['key'] : '';
    if ($installId === '' || $key === '') {
        ln_refuse(400, 'install_id (a UUID) and key are needed.');
    }
    $q = ln_db()->prepare('SELECT * FROM installs WHERE install_id = ?');
    $q->execute([$installId]);
    $install = $q->fetch();
    if (!$install || !hash_equals($install['key_hash'], ln_hash('install', $key))) {
        ln_refuse(401, 'Unknown installation or wrong key.');
    }
    ln_db()->prepare('UPDATE installs SET last_seen = ? WHERE id = ?')->execute([ln_now(), $install['id']]);
    return $install;
}

/** An install as the programs and the page are told of it. */
function ln_install_public(array $install): array
{
    return [
        'install_id' => $install['install_id'],
        'app' => $install['app'],
        'label' => $install['label'],
        'os' => $install['os'],
    ];
}

/** The installs of an account, the oldest claim first. */
function ln_installs_of(int $accountId): array
{
    $q = ln_db()->prepare('SELECT * FROM installs WHERE account_id = ? ORDER BY claimed_at, id');
    $q->execute([$accountId]);
    return $q->fetchAll();
}

/**
 * Gives an install to an account. Returns '' when done, else why not.
 * An install of the same account already is left as it is.
 */
function ln_claim(array $install, int $accountId): string
{
    if ($install['account_id'] !== null) {
        return (int) $install['account_id'] === $accountId ? '' :
            'That installation belongs to another account. Release it there first.';
    }
    $db = ln_db();
    $q = $db->prepare('SELECT COUNT(*) FROM installs WHERE account_id = ?');
    $q->execute([$accountId]);
    if ((int) $q->fetchColumn() >= LN_MAX_INSTALLS) {
        return 'This account has as many installations as it can hold. Remove one first.';
    }
    $q = $db->prepare('UPDATE installs SET account_id = ?, claimed_at = ? WHERE id = ? AND account_id IS NULL');
    $q->execute([$accountId, ln_now(), $install['id']]);
    return $q->rowCount() === 1 ? '' : 'That installation was claimed a moment ago.';
}

/** Takes an install off its account, with what it was waiting for. */
function ln_release(int $installRow): void
{
    $db = ln_db();
    $db->prepare('DELETE FROM tickets WHERE client = ? OR server = ?')->execute([$installRow, $installRow]);
    $db->prepare('DELETE FROM codes WHERE install = ?')->execute([$installRow]);
    $db->prepare('UPDATE installs SET account_id = NULL, claimed_at = NULL WHERE id = ?')->execute([$installRow]);
}

/** A mail address as it is compared: trimmed, lower case; '' when it is not one. */
function ln_email($value): string
{
    if (!is_string($value)) {
        return '';
    }
    $email = strtolower(trim($value));
    if (strlen($email) > 254 || filter_var($email, FILTER_VALIDATE_EMAIL) === false) {
        return '';
    }
    return $email;
}

/**
 * Sends a plain-text mail. With 'mail_file' in the settings (tests) the
 * mail is written there as a line of JSON and nothing is sent.
 */
function ln_mail(string $to, string $subject, string $body): bool
{
    $c = ln_config();
    if (!empty($c['mail_file'])) {
        $line = json_encode(['to' => $to, 'subject' => $subject, 'body' => $body], JSON_UNESCAPED_SLASHES);
        return file_put_contents((string) $c['mail_file'], $line . "\n", FILE_APPEND | LOCK_EX) !== false;
    }
    $from = (string) ($c['mail_from'] ?? '');
    $headers = "MIME-Version: 1.0\r\nContent-Type: text/plain; charset=utf-8\r\n";
    if ($from !== '') {
        $headers .= 'From: ' . $from . "\r\n";
    }
    return mail($to, $subject, $body, $headers);
}

/** The request came by HTTPS (the session's cookie is then for HTTPS only). */
function ln_https(): bool
{
    return (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
        || strtolower((string) ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '')) === 'https';
}

/** Sets or (with '') takes away the session's cookie. */
function ln_cookie(string $token): void
{
    setcookie(LN_COOKIE, $token, [
        'expires' => $token === '' ? 1 : time() + LN_SESSION_DAYS * 86400,
        'path' => '/',
        'secure' => ln_https(),
        'httponly' => true,
        'samesite' => 'Lax',
    ]);
}

/**
 * The browser's session: ['account_id' => n, 'token' => '...'], or null
 * when it is not signed in.
 */
function ln_session(): ?array
{
    $token = $_COOKIE[LN_COOKIE] ?? '';
    if (!is_string($token) || !preg_match('/^[0-9a-f]{64}$/', $token)) {
        return null;
    }
    $q = ln_db()->prepare('SELECT account_id FROM sessions WHERE token_hash = ? AND expires_at > ?');
    $q->execute([ln_hash('session', $token), ln_now()]);
    $accountId = $q->fetchColumn();
    if ($accountId === false) {
        return null;
    }
    return ['account_id' => (int) $accountId, 'token' => $token];
}

/** What a signed-in form must carry (it is the session's, and no other site can know it). */
function ln_csrf(array $session): string
{
    return ln_hash('csrf', $session['token']);
}

/** For HTML. */
function ln_h(?string $text): string
{
    return htmlspecialchars((string) $text, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}
