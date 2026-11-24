<?php
// GET /api/board.php - a page of a board, for the programs.
//
//   benchmark   'benchmark_short_fast' ... (required)
//   whisper     whisper.cpp's version, as 1.9.6: a board is the benchmark
//               under one version (left out: 1.9.5, the programs made
//               before they said which)
//   rows        how many rows (25 when left out, 100 at most)
//   first       the place of the first row (1 when left out), or
//   around      an install id: the page with that machine in its middle,
//               moved where the board ends so that it is full (the top
//               when the machine has no row)
//   install     an install id: its rows are marked "me" and its own place
//               comes back in "you" (around does the same)
//
// Answer (JSON): ok, benchmark {slug, name}, whisper, whispers (the
//                versions this benchmark has a board for, newest first),
//                count, first,
//                rows [{place, name, label, score_ms, score, device,
//                       backend, os, machine (the model, cores and
//                       memory in a few words, or "Unknown"), avg_watts, peak_watts, limit_watts
//                       (null when not known), me}],
//                you {place, score_ms} or null.
// An install id says which machine, not who may see: a board is public.

declare(strict_types=1);
require dirname(__DIR__) . '/lib.php';

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
        lb_refuse(405, 'This address takes a GET.');
    }
    $benchmark = lb_benchmark(lb_text($_GET['benchmark'] ?? '', 40));
    if ($benchmark === null) {
        lb_refuse(400, 'There is no such benchmark.');
    }
    $benchmarkId = (int) $benchmark['id'];
    $whisper = lb_whisper($_GET['whisper'] ?? null);
    if ($whisper === '') {
        lb_refuse(400, 'whisper must be whisper.cpp\'s version, as 1.9.6.');
    }
    $rows = lb_int($_GET['rows'] ?? null) ?? 25;
    $rows = max(1, min(LB_PAGE_MAX, $rows));
    $first = max(1, lb_int($_GET['first'] ?? null) ?? 1);
    $count = lb_board_count($benchmarkId, $whisper);

    // whose rows are "me"
    $mineId = 0;
    $you = null;
    $around = lb_install_id($_GET['around'] ?? '');
    $install = $around !== '' ? $around : lb_install_id($_GET['install'] ?? '');
    if ($install !== '') {
        $q = lb_db()->prepare('SELECT id FROM machines WHERE install_id = ?');
        $q->execute([$install]);
        $mineId = (int) $q->fetchColumn();
        if ($mineId > 0) {
            $you = lb_place($benchmarkId, $whisper, $mineId);
        }
    }
    if ($around !== '' && $you !== null) {
        $first = max(1, min($you['place'] - intdiv($rows, 2), max(1, $count - $rows + 1)));
    }

    $out = [];
    foreach (lb_page($benchmarkId, $whisper, $first, $rows) as $row) {
        $out[] = [
            'place' => $row['place'],
            'name' => $row['display_name'],
            'label' => $row['label'],
            'score_ms' => (int) $row['score_ms'],
            'score' => lb_score((int) $row['score_ms']),
            'device' => $row['device'],
            'backend' => $row['backend'],
            'os' => lb_os($row['os']),
            'machine' => lb_machine_text($row),
            'device_memory_mb' => $row['device_memory_mb'] === null ? null : (int) $row['device_memory_mb'],
            'avg_watts' => $row['avg_watts'] === null ? null : (int) $row['avg_watts'],
            'peak_watts' => $row['peak_watts'] === null ? null : (int) $row['peak_watts'],
            'limit_watts' => $row['limit_watts'] === null ? null : (int) $row['limit_watts'],
            'me' => $mineId > 0 && (int) $row['machine_id'] === $mineId,
        ];
    }
    lb_answer(200, [
        'ok' => true,
        'benchmark' => ['slug' => $benchmark['slug'], 'name' => $benchmark['name']],
        'whisper' => $whisper,
        'whispers' => lb_whispers($benchmarkId),
        'count' => $count,
        'first' => $first,
        'rows' => $out,
        'you' => $you,
    ]);
} catch (Throwable $e) {
    error_log('leaderboard board: ' . $e->getMessage());
    lb_refuse(500, 'The leaderboard could not be read.');
}
