<?php
// GET /api/board.php - a page of a board, for the programs.
//
//   benchmark   'benchmark_short_fast' ... (required)
//   rows        how many rows (25 when left out, 100 at most)
//   first       the place of the first row (1 when left out), or
//   around      an install id: the page with that machine in its middle,
//               moved where the board ends so that it is full (the top
//               when the machine has no row)
//   install     an install id: its rows are marked "me" and its own place
//               comes back in "you" (around does the same)
//
// Answer (JSON): ok, benchmark {slug, name}, count, first,
//                rows [{place, name, label, score_ms, score, device,
//                       backend, os, avg_watts, peak_watts, limit_watts
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
    $rows = lb_int($_GET['rows'] ?? null) ?? 25;
    $rows = max(1, min(LB_PAGE_MAX, $rows));
    $first = max(1, lb_int($_GET['first'] ?? null) ?? 1);
    $count = lb_board_count($benchmarkId);

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
            $you = lb_place($benchmarkId, $mineId);
        }
    }
    if ($around !== '' && $you !== null) {
        $first = max(1, min($you['place'] - intdiv($rows, 2), max(1, $count - $rows + 1)));
    }

    $out = [];
    foreach (lb_page($benchmarkId, $first, $rows) as $row) {
        $out[] = [
            'place' => $row['place'],
            'name' => $row['display_name'],
            'label' => $row['label'],
            'score_ms' => (int) $row['score_ms'],
            'score' => lb_score((int) $row['score_ms']),
            'device' => $row['device'],
            'backend' => $row['backend'],
            'os' => lb_os($row['os']),
            'avg_watts' => $row['avg_watts'] === null ? null : (int) $row['avg_watts'],
            'peak_watts' => $row['peak_watts'] === null ? null : (int) $row['peak_watts'],
            'limit_watts' => $row['limit_watts'] === null ? null : (int) $row['limit_watts'],
            'me' => $mineId > 0 && (int) $row['machine_id'] === $mineId,
        ];
    }
    lb_answer(200, [
        'ok' => true,
        'benchmark' => ['slug' => $benchmark['slug'], 'name' => $benchmark['name']],
        'count' => $count,
        'first' => $first,
        'rows' => $out,
        'you' => $you,
    ]);
} catch (Throwable $e) {
    error_log('leaderboard board: ' . $e->getMessage());
    lb_refuse(500, 'The leaderboard could not be read.');
}
