<?php
// POST /api/submit.php - a benchmark's score from a registered installation.
//
// Request (JSON):  install_id, key        from /api/register.php
//                  benchmark              'benchmark_short_fast' ...
//                  score_ms               the transcription's time, ms
//                  audio_ms               the chapter material's length, ms
//                  words, words_matched   of the chapter material
//                  model                  the model file ('ggml-base.bin')
//                  device                 its description (no machine name)
//                  device_kind            'cpu', 'integrated' or 'gpu'
//                  backend                'CPU', 'Vulkan', 'Metal', ...
//                  build                  EpubBuilder's build stamp
//                  whisper                whisper.cpp's version ('1.9.6');
//                                         left out: 1.9.5 (the programs
//                                         made before it was sent)
//                  channel                'steam' or 'direct'
//                  ran_at                 'YYYY-MM-DD HH:MM:SS', UTC
//                  name                   the name to show now (optional)
//                  os                     the system now (optional)
//                  machine_model, cpu, memory_gb, cores, perf_cores,
//                  eff_cores, threads, gpu_cores
//                                         what the machine is (optional,
//                                         each: what is left out stays as
//                                         it was; never the computer's or
//                                         the user's name)
//                  avg_watts, peak_watts, limit_watts
//                                         what the card drew over the run
//                                         and the limit it was held to, W
//                                         (optional: where it can be read)
//                  device_memory_mb       the memory of the device the run
//                                         was on, MB (optional: a graphics
//                                         card's own, as whisper.cpp says)
// Answer (JSON):   ok true, status 'ok' | 'pending', improved, place,
//                  count, best_ms, whisper, machine, run (place is 0
//                  while the run is pending and the machine has no row on
//                  the board yet). machine is the machine's number, for
//                  the page's address (?m=N marks its row and shows the
//                  part of the board it is in); run is this run's.
//                  A board is the benchmark under that whisper.cpp
//                  version: place, count and best_ms are that board's.
//                  ok false, error "..." - a refused run is still kept,
//                  with the reason, when the machine is known.

declare(strict_types=1);
require dirname(__DIR__) . '/lib.php';

try {
    $in = lb_body();
    $machine = lb_machine(lb_install_id($in['install_id'] ?? ''), lb_text($in['key'] ?? '', 128));
    if ($machine === null) {
        lb_refuse(401, 'The installation is not registered, or its key is wrong.');
    }
    $db = lb_db();
    $sender = lb_sender();
    $now = lb_now();
    $machineId = (int) $machine['id'];

    // not too many, from this machine or from this address
    $q = $db->prepare('SELECT COUNT(*) FROM runs WHERE machine_id = ? AND received_at > ?');
    $q->execute([$machineId, lb_now(-3600)]);
    if ((int) $q->fetchColumn() >= LB_RUNS_PER_HOUR) {
        lb_refuse(429, 'Too many scores from this installation in the last hour.');
    }
    $q = $db->prepare('SELECT COUNT(*) FROM runs WHERE sender_hash = ? AND received_at > ?');
    $q->execute([$sender, lb_now(-3600)]);
    if ((int) $q->fetchColumn() >= LB_SENDER_RUNS_PER_HOUR) {
        lb_refuse(429, 'Too many scores from here in the last hour.');
    }

    $benchmark = lb_benchmark(lb_text($in['benchmark'] ?? '', 40));
    if ($benchmark === null) {
        lb_refuse(400, 'There is no such benchmark.');
    }

    $score = lb_int($in['score_ms'] ?? null);
    $audio = lb_int($in['audio_ms'] ?? null);
    $words = lb_int($in['words'] ?? null);
    $matched = lb_int($in['words_matched'] ?? null);
    $device = lb_text($in['device'] ?? '', 120);
    $kind = strtolower(lb_text($in['device_kind'] ?? '', 12));
    $backend = lb_text($in['backend'] ?? '', 20);
    $build = lb_text($in['build'] ?? '', 40);
    $channel = strtolower(lb_text($in['channel'] ?? '', 8));
    $model = lb_text($in['model'] ?? '', 40);
    $ranAt = lb_text($in['ran_at'] ?? '', 19);
    $whisper = lb_whisper($in['whisper'] ?? null);
    // optional, and never a reason to refuse: not a believable number
    // of watts is simply not kept
    $watts = [];
    foreach (['avg_watts', 'peak_watts', 'limit_watts'] as $field) {
        $w = lb_int($in[$field] ?? null);
        $watts[] = ($w !== null && $w >= 1 && $w <= 2000) ? $w : null;
    }

    // the memory of the device the run was on (a graphics card's own), MB
    $deviceMemory = lb_int($in['device_memory_mb'] ?? null);
    if ($deviceMemory === null || $deviceMemory < 64 || $deviceMemory > 4194304) {
        $deviceMemory = null;
    }

    // what must be there at all: without these nothing is kept
    if ($score === null || $audio === null || $words === null || $matched === null || $score <= 0 ||
        $score > 2000000000 || $audio > 2000000000 || $words > 100000000 || $matched > 100000000) {
        lb_refuse(400, 'score_ms, audio_ms, words and words_matched must be whole numbers.');
    }
    if ($whisper === '') {
        lb_refuse(400, 'whisper must be whisper.cpp\'s version, as 1.9.6.');
    }
    if ($device === '' || $backend === '' || $build === '' ||
        !in_array($kind, ['cpu', 'integrated', 'gpu'], true) ||
        !in_array($channel, ['steam', 'direct'], true) ||
        !preg_match('/^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$/', $ranAt)) {
        lb_refuse(400, 'device, device_kind, backend, build, channel or ran_at is missing or not as expected.');
    }

    // is it a run of this benchmark, and can it be true?
    $status = 'ok';
    $reason = null;
    $speed = $audio / $score;   // times real time
    if ($machine['banned'] || $machine['hidden']) {
        $status = 'rejected';
        $reason = 'the installation is not on the boards';
    } elseif ($model !== $benchmark['model']) {
        $status = 'rejected';
        $reason = 'not the benchmark\'s model';
    } elseif (abs($audio - (int) $benchmark['audio_ms']) > LB_AUDIO_TOLERANCE * (int) $benchmark['audio_ms']) {
        $status = 'rejected';
        $reason = 'not the benchmark\'s recording';
    } elseif ($words <= 0 || $matched > $words || $matched < LB_MIN_MATCHED * $words) {
        $status = 'rejected';
        $reason = 'too few words matched';
    } elseif ($speed < LB_SLOWEST || $speed > LB_FASTEST) {
        $status = 'rejected';
        $reason = 'not a possible speed';
    } elseif ($speed > LB_FASTEST_SHOWN) {
        // kept, not shown: a person looks first
        $status = 'pending';
        $reason = 'faster than any machine known';
    }

    $db->beginTransaction();

    $q = $db->prepare('SELECT id FROM devices WHERE description = ? AND kind = ? AND backend = ?');
    $q->execute([$device, $kind, $backend]);
    $deviceId = (int) $q->fetchColumn();
    if ($deviceId === 0) {
        $db->prepare('INSERT INTO devices (description, kind, backend) VALUES (?, ?, ?)')
           ->execute([$device, $kind, $backend]);
        $deviceId = (int) $db->lastInsertId();
    }

    $db->prepare('INSERT INTO runs (machine_id, benchmark_id, device_id, score_ms, audio_ms, words, words_matched,
                                    avg_watts, peak_watts, limit_watts, device_memory_mb,
                                    build, whisper, channel, ran_at, received_at, sender_hash, verified,
                                    status, reject_reason)
                  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)')
       ->execute([$machineId, $benchmark['id'], $deviceId, $score, $audio, $words, $matched,
                  $watts[0], $watts[1], $watts[2], $deviceMemory, $build, $whisper, $channel,
                  $ranAt, $now, $sender, $status, $reason]);
    $runId = (int) $db->lastInsertId();

    $db->prepare('UPDATE machines SET last_seen = ? WHERE id = ?')->execute([$now, $machineId]);
    // the system as it is now (an upgrade; and a first registration from
    // inside Steam's container said 'Steam Runtime 3')
    $os = lb_text($in['os'] ?? '', 60);
    if ($os !== '') {
        $db->prepare('UPDATE machines SET os = ? WHERE id = ?')->execute([$os, $machineId]);
    }

    // what the machine is, as far as the program could tell
    foreach (lb_machine_facts($in) as $column => $value) {
        $db->prepare('UPDATE machines SET ' . $column . ' = ? WHERE id = ?')->execute([$value, $machineId]);
    }

    // the name shown follows the latest one sent
    $name = lb_text($in['name'] ?? '', LB_MAX_NAME);
    if ($name !== '') {
        $db->prepare('UPDATE players SET display_name = ? WHERE id = ?')->execute([$name, $machine['player_id']]);
    }

    // the board - the benchmark under this whisper.cpp version - keeps
    // the machine's best accepted run
    $improved = false;
    if ($status === 'ok') {
        $q = $db->prepare('SELECT score_ms FROM bests WHERE machine_id = ? AND benchmark_id = ? AND whisper = ?');
        $q->execute([$machineId, $benchmark['id'], $whisper]);
        $best = $q->fetchColumn();
        if ($best === false) {
            $db->prepare('INSERT INTO bests (machine_id, benchmark_id, whisper, run_id, score_ms)
                          VALUES (?, ?, ?, ?, ?)')
               ->execute([$machineId, $benchmark['id'], $whisper, $runId, $score]);
            $improved = true;
        } elseif ($score < (int) $best) {
            $db->prepare('UPDATE bests SET run_id = ?, score_ms = ?
                          WHERE machine_id = ? AND benchmark_id = ? AND whisper = ?')
               ->execute([$runId, $score, $machineId, $benchmark['id'], $whisper]);
            $improved = true;
        }
    }
    $db->commit();

    if ($status === 'rejected') {
        lb_refuse(422, 'The score was not accepted: ' . $reason . '.');
    }
    $place = lb_place((int) $benchmark['id'], $whisper, $machineId);
    lb_answer(200, [
        'ok' => true,
        'status' => $status,
        'improved' => $improved,
        'place' => $place ? $place['place'] : 0,
        'best_ms' => $place ? $place['score_ms'] : 0,
        'count' => lb_board_count((int) $benchmark['id'], $whisper),
        'whisper' => $whisper,
        // for the page's address (?m=): which row is this machine's
        'machine' => $machineId,
        'run' => $runId,
    ]);
} catch (Throwable $e) {
    if (isset($db) && $db->inTransaction()) {
        $db->rollBack();
    }
    error_log('leaderboard submit: ' . $e->getMessage());
    lb_refuse(500, 'The leaderboard could not take the score.');
}
