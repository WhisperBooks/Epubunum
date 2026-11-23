<?php
// EpubUnum leaderboard - what the pages and the endpoints share.
// PHP 7.4 or later. Nothing is printed by this file.

declare(strict_types=1);

/** The rules of version 1 (owner, 2026-11-23: validation "TBD" - these are the minimum to start with). */
const LB_MAX_NAME = 32;            // a display name's characters
const LB_RUNS_PER_HOUR = 20;       // one machine
const LB_SENDER_RUNS_PER_HOUR = 60; // one address, all its machines
const LB_REGISTRATIONS_PER_DAY = 10; // one address
const LB_AUDIO_TOLERANCE = 0.01;   // the audio's length against the benchmark's
const LB_MIN_MATCHED = 0.90;       // words matched, of the words
const LB_SLOWEST = 0.05;           // times real time: slower is refused
const LB_FASTEST_SHOWN = 400.0;    // faster waits for a person ('pending')
const LB_FASTEST = 5000.0;         // faster is refused
const LB_PAGE_MAX = 100;           // rows of a board in one answer

/**
 * The settings: an array from a PHP file that is NOT in the repository.
 * Looked for in: the path in the environment's LB_CONFIG (tests), a
 * leaderboard-config.php one folder above the site (outside the web
 * root), a config.php beside this file (kept from visitors by .htaccess).
 */
function lb_config(): array
{
    static $config = null;
    if ($config !== null) {
        return $config;
    }
    $places = [];
    $env = getenv('LB_CONFIG');
    if (is_string($env) && $env !== '') {
        $places[] = $env;
    }
    $places[] = dirname(__DIR__) . '/leaderboard-config.php';
    $places[] = __DIR__ . '/config.php';
    foreach ($places as $place) {
        if (is_file($place)) {
            $config = require $place;
            if (!is_array($config) || empty($config['dsn']) || empty($config['salt'])) {
                throw new RuntimeException('The leaderboard settings are incomplete.');
            }
            return $config;
        }
    }
    throw new RuntimeException('The leaderboard is not set up yet (no settings file).');
}

/** The database. */
function lb_db(): PDO
{
    static $db = null;
    if ($db === null) {
        $c = lb_config();
        $db = new PDO($c['dsn'], $c['user'] ?? null, $c['password'] ?? null, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]);
    }
    return $db;
}

/** Now, UTC, as the tables keep it. */
function lb_now(int $offsetSeconds = 0): string
{
    return gmdate('Y-m-d H:i:s', time() + $offsetSeconds);
}

/** Who is asking, as a salted hash: for rate limits, never shown, not an address. */
function lb_sender(): string
{
    $address = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
    return hash('sha256', lb_config()['salt'] . '|' . $address);
}

/** Answers with JSON and ends. */
function lb_answer(int $status, array $body): void
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    header('X-Content-Type-Options: nosniff');
    echo json_encode($body, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

/** Answers that something was wrong with the request, and ends. */
function lb_refuse(int $status, string $why): void
{
    lb_answer($status, ['ok' => false, 'error' => $why]);
}

/** The JSON object a POST carries (64 KB at most). */
function lb_body(): array
{
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        lb_refuse(405, 'This address takes a POST.');
    }
    $raw = file_get_contents('php://input', false, null, 0, 65537);
    if ($raw === false || strlen($raw) > 65536) {
        lb_refuse(413, 'The request is too large.');
    }
    $data = json_decode($raw, true);
    if (!is_array($data)) {
        lb_refuse(400, 'The request is not a JSON object.');
    }
    return $data;
}

/** A text field: trimmed, no control characters, cut to $max characters. */
function lb_text($value, int $max): string
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

/** A whole number field, or null when it is not one. */
function lb_int($value): ?int
{
    if (is_int($value)) {
        return $value;
    }
    if (is_string($value) && preg_match('/^\d{1,12}$/', $value)) {
        return (int) $value;
    }
    return null;
}

/** An install id: a UUID, lower case; '' when it is not one. */
function lb_install_id($value): string
{
    $id = strtolower(trim((string) (is_string($value) ? $value : ''), "{} \t\r\n"));
    return preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/', $id) ? $id : '';
}

/** The machine an install id and its secret belong to, or null. */
function lb_machine(string $installId, string $key): ?array
{
    if ($installId === '' || $key === '') {
        return null;
    }
    $q = lb_db()->prepare('SELECT m.*, p.banned FROM machines m JOIN players p ON p.id = m.player_id
                           WHERE m.install_id = ?');
    $q->execute([$installId]);
    $machine = $q->fetch();
    if (!$machine || !hash_equals($machine['key_hash'], hash('sha256', $key))) {
        return null;
    }
    return $machine;
}

/** The benchmark with that slug, or null. */
function lb_benchmark(string $slug): ?array
{
    $q = lb_db()->prepare('SELECT * FROM benchmarks WHERE slug = ?');
    $q->execute([$slug]);
    $row = $q->fetch();
    return $row ?: null;
}

/** All four, in order. */
function lb_benchmarks(): array
{
    return lb_db()->query('SELECT * FROM benchmarks ORDER BY sort_order')->fetchAll();
}

/** How many machines a board shows. */
function lb_board_count(int $benchmarkId): int
{
    $q = lb_db()->prepare('SELECT COUNT(*) FROM bests b
                           JOIN machines m ON m.id = b.machine_id AND m.hidden = 0
                           JOIN players p ON p.id = m.player_id AND p.banned = 0
                           WHERE b.benchmark_id = ?');
    $q->execute([$benchmarkId]);
    return (int) $q->fetchColumn();
}

/**
 * A machine's place on a board (1 = the fastest) and its best score, or
 * null when it has no row there. Equal scores: the earlier run is ahead.
 */
function lb_place(int $benchmarkId, int $machineId): ?array
{
    $db = lb_db();
    $q = $db->prepare('SELECT b.score_ms, b.run_id FROM bests b
                       JOIN machines m ON m.id = b.machine_id AND m.hidden = 0
                       JOIN players p ON p.id = m.player_id AND p.banned = 0
                       WHERE b.benchmark_id = ? AND b.machine_id = ?');
    $q->execute([$benchmarkId, $machineId]);
    $mine = $q->fetch();
    if (!$mine) {
        return null;
    }
    $q = $db->prepare('SELECT COUNT(*) FROM bests b
                       JOIN machines m ON m.id = b.machine_id AND m.hidden = 0
                       JOIN players p ON p.id = m.player_id AND p.banned = 0
                       WHERE b.benchmark_id = ?
                         AND (b.score_ms < ? OR (b.score_ms = ? AND b.run_id < ?))');
    $q->execute([$benchmarkId, $mine['score_ms'], $mine['score_ms'], $mine['run_id']]);
    return ['place' => 1 + (int) $q->fetchColumn(), 'score_ms' => (int) $mine['score_ms']];
}

/** A page of a board: $rows rows from place $first on. */
function lb_page(int $benchmarkId, int $first, int $rows): array
{
    $first = max(1, $first);
    $rows = max(1, min(LB_PAGE_MAX, $rows));
    $q = lb_db()->prepare(
        'SELECT b.machine_id, b.score_ms, p.display_name, m.label, d.description AS device, d.backend,
                r.words, r.words_matched, r.ran_at, r.verified, r.avg_watts, r.peak_watts, r.limit_watts
         FROM bests b
         JOIN machines m ON m.id = b.machine_id AND m.hidden = 0
         JOIN players p ON p.id = m.player_id AND p.banned = 0
         JOIN runs r ON r.id = b.run_id
         JOIN devices d ON d.id = r.device_id
         WHERE b.benchmark_id = ?
         ORDER BY b.score_ms, b.run_id
         LIMIT ' . $rows . ' OFFSET ' . ($first - 1)
    );
    $q->execute([$benchmarkId]);
    $out = [];
    $place = $first;
    foreach ($q->fetchAll() as $row) {
        $row['place'] = $place++;
        $out[] = $row;
    }
    return $out;
}

/** A score in ms as H:MM:SS.mmm, as EpubBuilder writes it. */
function lb_score(int $ms): string
{
    return sprintf('%d:%02d:%02d.%03d', intdiv($ms, 3600000), intdiv($ms, 60000) % 60, intdiv($ms, 1000) % 60,
        $ms % 1000);
}

/** For HTML. */
function lb_h(?string $text): string
{
    return htmlspecialchars((string) $text, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}
