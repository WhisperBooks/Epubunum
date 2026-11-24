<?php
// The public page: the four boards, one at a time (?b=benchmark_long_fast).

declare(strict_types=1);
require __DIR__ . '/lib.php';

$benchmarks = [];
$current = null;
$rows = [];
$count = 0;
$problem = '';
try {
    $benchmarks = lb_benchmarks();
    $wanted = lb_text($_GET['b'] ?? '', 40);
    foreach ($benchmarks as $b) {
        if ($b['slug'] === $wanted) {
            $current = $b;
        }
    }
    if ($current === null && $benchmarks) {
        $current = $benchmarks[0];
    }
    if ($current !== null) {
        $count = lb_board_count((int) $current['id']);
        $rows = lb_page((int) $current['id'], 1, LB_PAGE_MAX);
    }
} catch (Throwable $e) {
    error_log('leaderboard page: ' . $e->getMessage());
    $problem = 'The leaderboard is being set up. Please come back soon.';
}

/** The words transcribed a minute, for a row: the book's words over the time taken ('' = not known). */
function wpm_text(array $row): string
{
    $words = (int) ($row['words'] ?? 0);
    $scoreMs = (int) ($row['score_ms'] ?? 0);
    if ($words <= 0 || $scoreMs <= 0) {
        return '';
    }
    return number_format($words * 60000 / $scoreMs, 0);
}

/** The speed against real time, for a row. */
function speed_text(array $benchmark, int $scoreMs): string
{
    $speed = (int) $benchmark['audio_ms'] / max(1, $scoreMs);
    return ($speed >= 10 ? number_format($speed, 0) : number_format($speed, 1)) . 'x';
}

/** What the card drew, for a row: '142 W of 175' ('' when not known). */
function power_text(array $row): string
{
    if ($row['avg_watts'] === null) {
        return '';
    }
    $text = (int) $row['avg_watts'] . ' W';
    if ($row['limit_watts'] !== null) {
        $text .= ' of ' . (int) $row['limit_watts'];
    }
    return $text;
}

header('Content-Type: text/html; charset=utf-8');
header('X-Content-Type-Options: nosniff');
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>epubunum leaderboard<?= $current ? ' - ' . lb_h($current['name']) : '' ?></title>
<meta name="description" content="How fast different computers turn an audiobook into a read-along book with EpubBuilder's benchmark.">
<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E%3Crect width='32' height='32' rx='6' fill='%2316263f'/%3E%3Crect x='6' y='9' width='20' height='4' rx='2' fill='%23c9d3e3'/%3E%3Crect x='6' y='15' width='12' height='4' rx='2' fill='%23f0c84b'/%3E%3Crect x='20' y='15' width='6' height='4' rx='2' fill='%23c9d3e3'/%3E%3Crect x='6' y='21' width='16' height='4' rx='2' fill='%23c9d3e3'/%3E%3C/svg%3E">
<style>
  :root {
    --ink: #16263f; --ink-soft: #46566f; --paper: #f3f5f1; --marker: #f0c84b; --mist: #c9d3e3; --rule: #d5dad2;
    --book: "Iowan Old Style", "Palatino Linotype", Palatino, "Book Antiqua", Georgia, serif;
    --ui: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  }
  * { box-sizing: border-box; }
  body { margin: 0; background: var(--paper); color: var(--ink); font-family: var(--ui); font-size: 1.0625rem;
         line-height: 1.6; }
  a { color: inherit; text-decoration-thickness: 1px; text-underline-offset: 0.2em; }
  a:focus-visible { outline: 3px solid var(--marker); outline-offset: 3px; }
  .wrap { max-width: 68rem; margin: 0 auto; padding: 0 1.5rem; }

  .field { background: var(--ink); color: var(--mist); padding-bottom: 2.5rem; }
  .masthead { display: flex; justify-content: space-between; align-items: baseline; gap: 1rem; padding: 1.5rem 0; }
  .name { font-family: var(--book); font-size: 1.5rem; color: #fff; text-decoration: none; }
  h1 { font-family: var(--book); font-weight: 400; color: #fff; font-size: clamp(2.2rem, 4.6vw, 3.4rem);
       line-height: 1.08; letter-spacing: -0.015em; margin: 1.5rem 0 1rem; }
  .field p { max-width: 42rem; margin: 0; }

  .boards { display: flex; flex-wrap: wrap; gap: 0.5rem 0.75rem; margin: 2rem 0 0; padding: 0; list-style: none; }
  .boards a { display: block; padding: 0.45rem 1rem; border: 1px solid var(--mist); border-radius: 999px;
              text-decoration: none; font-size: 0.95rem; }
  .boards a[aria-current="page"] { background: var(--marker); border-color: var(--marker); color: var(--ink);
                                   font-weight: 600; }

  main { padding: 3rem 0 4.5rem; }
  h2 { font-family: var(--book); font-weight: 400; font-size: clamp(1.6rem, 2.6vw, 2.1rem); line-height: 1.15;
       margin: 0 0 0.4rem; }
  .about { color: var(--ink-soft); margin: 0 0 2rem; max-width: 44rem; }
  .scroll { overflow-x: auto; }
  table { border-collapse: collapse; width: 100%; font-variant-numeric: tabular-nums; }
  th, td { text-align: left; padding: 0.7rem 1rem 0.7rem 0; border-top: 1px solid var(--rule); font-weight: 400;
           vertical-align: baseline; }
  thead th { border-top: 0; color: var(--ink-soft); font-size: 0.95rem; }
  .num { text-align: right; white-space: nowrap; }
  td.place { width: 4.5rem; font-family: var(--book); font-size: 1.25rem; }
  td.who span { display: block; color: var(--ink-soft); font-size: 0.9rem; }
  td.device span { color: var(--ink-soft); }
  td.os, td.power { white-space: nowrap; }
  tbody tr:first-child td { font-weight: 600; }
  tbody tr:first-child td.who span, tbody tr:first-child td.device span { font-weight: 400; }
  /* a narrow screen: each row is a few lines - who and time, what it ran on and the words a minute,
     the system and the speed, then the power */
  @media (max-width: 40rem) {
    thead { position: absolute; width: 1px; height: 1px; overflow: hidden; clip-path: inset(50%); }
    tbody tr { display: grid; grid-template-columns: 2.75rem 1fr auto; column-gap: 0.75rem;
               grid-template-areas: "place who time" "place device wpm" "place os speed" "place power power";
               padding: 0.8rem 0;
               border-top: 1px solid var(--rule); }
    tbody td { border: 0; padding: 0; }
    td.place { grid-area: place; width: auto; }
    td.who { grid-area: who; }
    td.time { grid-area: time; }
    td.speed { grid-area: speed; color: var(--ink-soft); font-size: 0.9rem; }
    td.wpm { grid-area: wpm; color: var(--ink-soft); font-size: 0.9rem; font-weight: 400; }
    td.wpm:not(:empty)::after { content: " words/min"; }
    td.os { grid-area: os; color: var(--ink-soft); font-size: 0.9rem; font-weight: 400; }
    td.power { grid-area: power; text-align: right; color: var(--ink-soft); font-size: 0.9rem; font-weight: 400; }
    td.device { grid-area: device; color: var(--ink-soft); font-size: 0.9rem; font-weight: 400; }
    tbody tr:first-child td.device, tbody tr:first-child td.speed, tbody tr:first-child td.wpm { font-weight: 400; }
  }
  .empty { padding: 2.5rem 0; border-top: 1px solid var(--rule); color: var(--ink-soft); max-width: 40rem; }

  footer { background: var(--ink); color: var(--mist); padding: 2.5rem 0; font-size: 0.95rem; }
  footer .wrap { display: flex; flex-wrap: wrap; justify-content: space-between; gap: 1rem 2rem; }
</style>
</head>
<body>

<div class="field">
  <div class="wrap">
    <header class="masthead">
      <a class="name" href="https://www.epubunum.com/">epubunum</a>
      <a href="https://www.epubunum.com/">What is epubunum?</a>
    </header>
    <h1>The benchmark leaderboard</h1>
    <p>EpubBuilder's benchmark times how long a computer takes to transcribe a whole audiobook. The score
      is that time: the shortest is first. Each row is one computer's best run.</p>
<?php if ($benchmarks): ?>
    <ul class="boards">
<?php foreach ($benchmarks as $b): ?>
      <li><a href="?b=<?= lb_h($b['slug']) ?>"<?= $current && $b['id'] === $current['id'] ? ' aria-current="page"' : '' ?>><?= lb_h($b['name']) ?></a></li>
<?php endforeach; ?>
    </ul>
<?php endif; ?>
  </div>
</div>

<main>
  <div class="wrap">
<?php if ($problem !== ''): ?>
    <p class="empty"><?= lb_h($problem) ?></p>
<?php elseif ($current !== null): ?>
    <h2><?= lb_h($current['name']) ?></h2>
    <p class="about"><?= lb_h($current['book']) ?>, <?= lb_h(lb_score((int) $current['audio_ms'])) ?> of narration.
      <?= $count === 1 ? '1 computer' : number_format($count) . ' computers' ?> on this board<?= $count > count($rows) ? '; the first ' . count($rows) . ' are shown' : '' ?>.</p>
<?php if (!$rows): ?>
    <p class="empty">No scores yet. Run this benchmark in EpubBuilder to be the first.</p>
<?php else: ?>
    <div class="scroll">
      <table>
        <thead>
          <tr>
            <th scope="col">Place</th>
            <th scope="col">Who</th>
            <th scope="col" class="num">Time</th>
            <th scope="col" class="num">Words/min</th>
            <th scope="col" class="num">Speed</th>
            <th scope="col">Ran on</th>
            <th scope="col">System</th>
            <th scope="col" class="num">Power</th>
          </tr>
        </thead>
        <tbody>
<?php foreach ($rows as $row): ?>
          <tr>
            <td class="place"><?= (int) $row['place'] ?></td>
            <td class="who"><?= lb_h($row['display_name']) ?><?php if ($row['label'] !== null && $row['label'] !== ''): ?><span><?= lb_h($row['label']) ?></span><?php endif; ?></td>
            <td class="num time"><?= lb_h(lb_score((int) $row['score_ms'])) ?></td>
            <td class="num wpm"><?= lb_h(wpm_text($row)) ?></td>
            <td class="num speed"><?= lb_h(speed_text($current, (int) $row['score_ms'])) ?></td>
            <td class="device"><?= lb_h($row['device']) ?> <span><?= lb_h($row['backend']) ?></span></td>
            <td class="os"><?= lb_h(lb_os($row['os'])) ?></td>
            <td class="num power"><?= lb_h(power_text($row)) ?></td>
          </tr>
<?php endforeach; ?>
        </tbody>
      </table>
    </div>
<?php endif; ?>
<?php endif; ?>
  </div>
</main>

<footer>
  <div class="wrap">
    <span>epubunum</span>
    <span>Words/min is the book's words divided by the time taken: how many words were transcribed each minute.
      Speed is the narration's length divided by the time: 60x means an hour of audio in a minute.
      Power is what the graphics card typically drew (the median) and, where known, the limit it was held to;
      for graphics built into a processor it is the whole chip's. Not every card reports it.</span>
  </div>
</footer>

</body>
</html>
