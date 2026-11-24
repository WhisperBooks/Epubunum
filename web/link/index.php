<?php
// The page: sign in with a mailed link, then see the account's
// installations, add one (a code from its screen, or a one-time key for
// one without a screen), remove one, sign out, delete the account.

declare(strict_types=1);
require __DIR__ . '/lib.php';

$problem = '';     // the site itself is not working
$hint = '';        // which step of the setting-up failed (no names, no secrets)
$notice = '';      // something was done
$error = '';       // something was not
$view = 'signin';  // 'signin', 'sent', 'confirm', 'account'
$session = null;
$installs = [];
$newKey = '';      // a one-time key just made (shown once)
$token = '';       // a sign-in link's token, to confirm
$code = '';        // a code carried by the address (?code=)

/** Sends the browser to the page itself (after a POST that changed who is signed in). */
function go_home(): void
{
    header('Location: ./', true, 303);
    exit;
}

try {
    $db = ln_db();
    $session = ln_session();
    if ($session === null) {
        // nobody signed in: nothing below reads a table, so ask one now -
        // a database without its tables is then said on the page
        $db->query('SELECT 1 FROM accounts LIMIT 1');
    }
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    $action = $method === 'POST' && is_string($_POST['action'] ?? null) ? $_POST['action'] : '';
    $code = ln_typed($_GET['code'] ?? ($_POST['code'] ?? ''));
    if (strlen($code) !== 8) {
        $code = '';
    }

    // a signed-in form must carry the session's own mark
    $signedActions = ['code', 'addkey', 'remove', 'signout', 'delete'];
    if (in_array($action, $signedActions, true)) {
        $sent = is_string($_POST['csrf'] ?? null) ? $_POST['csrf'] : '';
        if ($session === null || !hash_equals(ln_csrf($session), $sent)) {
            $action = '';
            $error = 'That page was too old. Please try again.';
        }
    }

    if ($action === 'signin') {
        // a link is mailed to the address typed; the address is not kept
        $email = ln_email($_POST['email'] ?? '');
        if ($email === '') {
            $error = 'That does not look like a mail address.';
        } else {
            ln_tidy();
            $emailHash = ln_hash('email', $email);
            $sender = ln_sender();
            if (ln_count('mail', $emailHash, 3600) >= LN_MAILS_PER_ADDRESS
                || ln_count('mailfrom', $sender, 3600) >= LN_MAILS_PER_SENDER) {
                $error = 'Too many sign-in mails were asked for. Try again in an hour.';
            } else {
                ln_note('mail', $emailHash);
                ln_note('mailfrom', $sender);
                $signin = bin2hex(random_bytes(32));
                $db->prepare('INSERT INTO signins (email_hash, token_hash, created_at, expires_at)
                              VALUES (?, ?, ?, ?)')
                   ->execute([$emailHash, ln_hash('signin', $signin), ln_now(), ln_now(LN_SIGNIN_MINUTES * 60)]);
                $link = ln_config()['site'] . '/?t=' . $signin . ($code !== '' ? '&code=' . ln_grouped($code) : '');
                $body = "Someone - you, we hope - asked to sign in to epubunum's link site.\r\n\r\n"
                      . "Open this to sign in (it works once, for " . LN_SIGNIN_MINUTES . " minutes):\r\n\r\n"
                      . $link . "\r\n\r\n"
                      . "If it was not you, do nothing: without the link nobody is signed in.\r\n";
                if (!ln_mail($email, 'Sign in to epubunum link', $body)) {
                    error_log('link page: the sign-in mail was not accepted for sending');
                }
                $view = 'sent';
            }
        }
    } elseif ($action === 'confirm') {
        // the button on the page the mailed link opens
        $token = is_string($_POST['t'] ?? null) ? $_POST['t'] : '';
        $row = false;
        if (preg_match('/^[0-9a-f]{64}$/', $token)) {
            $q = $db->prepare('SELECT * FROM signins WHERE token_hash = ? AND used_at IS NULL AND expires_at > ?');
            $q->execute([ln_hash('signin', $token), ln_now()]);
            $row = $q->fetch();
        }
        $used = false;
        if ($row) {
            $q = $db->prepare('UPDATE signins SET used_at = ? WHERE id = ? AND used_at IS NULL');
            $q->execute([ln_now(), $row['id']]);
            $used = $q->rowCount() === 1;
        }
        if (!$used) {
            $error = 'That sign-in link was used already or is too old. Ask for a new one.';
            $token = '';
        } else {
            $q = $db->prepare('SELECT id FROM accounts WHERE email_hash = ?');
            $q->execute([$row['email_hash']]);
            $accountId = (int) $q->fetchColumn();
            if ($accountId === 0) {
                $db->prepare('INSERT INTO accounts (email_hash, created_at, last_seen) VALUES (?, ?, ?)')
                   ->execute([$row['email_hash'], ln_now(), ln_now()]);
                $accountId = (int) $db->lastInsertId();
            } else {
                $db->prepare('UPDATE accounts SET last_seen = ? WHERE id = ?')->execute([ln_now(), $accountId]);
            }
            $sessionToken = bin2hex(random_bytes(32));
            $db->prepare('INSERT INTO sessions (account_id, token_hash, created_at, expires_at) VALUES (?, ?, ?, ?)')
               ->execute([$accountId, ln_hash('session', $sessionToken), ln_now(),
                          ln_now(LN_SESSION_DAYS * 86400)]);
            ln_cookie($sessionToken);
            header('Location: ./' . ($code !== '' ? '?code=' . ln_grouped($code) : ''), true, 303);
            exit;
        }
    } elseif ($action === 'signout') {
        $db->prepare('DELETE FROM sessions WHERE token_hash = ?')->execute([ln_hash('session', $session['token'])]);
        ln_cookie('');
        go_home();
    } elseif ($action === 'delete') {
        if (($_POST['sure'] ?? '') !== 'yes') {
            $error = 'Tick the box to delete the account.';
        } else {
            $id = $session['account_id'];
            $db->beginTransaction();
            foreach (ln_installs_of($id) as $install) {
                ln_release((int) $install['id']);
            }
            $db->prepare('DELETE FROM activation_keys WHERE account_id = ?')->execute([$id]);
            $db->prepare('DELETE FROM sessions WHERE account_id = ?')->execute([$id]);
            $db->prepare('DELETE FROM attempts WHERE who = ?')->execute(['a' . $id]);
            $db->prepare('DELETE FROM accounts WHERE id = ?')->execute([$id]);
            $db->commit();
            ln_cookie('');
            go_home();
        }
    } elseif ($action === 'code') {
        // the code an installation's screen shows
        $who = 'a' . $session['account_id'];
        if ($code === '') {
            $error = 'A code has eight letters and digits, as the screen shows them.';
        } elseif (ln_count('wrongcode', $who, 3600) >= LN_WRONG_PER_HOUR) {
            $error = 'Too many wrong codes. Try again in an hour.';
        } else {
            $q = $db->prepare('SELECT c.id AS code_row, i.* FROM codes c JOIN installs i ON i.id = c.install
                               WHERE c.code_hash = ? AND c.used_at IS NULL AND c.expires_at > ?');
            $q->execute([ln_hash('code', $code), ln_now()]);
            $row = $q->fetch();
            if (!$row) {
                ln_note('wrongcode', $who);
                $error = 'That code is not known or is too old. Ask the program for a new one.';
            } else {
                $db->beginTransaction();
                $q = $db->prepare('UPDATE codes SET used_at = ? WHERE id = ? AND used_at IS NULL');
                $q->execute([ln_now(), $row['code_row']]);
                $why = $q->rowCount() === 1 ? ln_claim($row, $session['account_id']) : 'That code was used a moment ago.';
                if ($why !== '') {
                    $db->rollBack();
                    $error = $why;
                } else {
                    $db->commit();
                    $notice = ($row['label'] !== null ? $row['label'] . ' (' . $row['app'] . ')' : $row['app'])
                            . ' is now one of your installations.';
                    $code = '';
                }
            }
        }
    } elseif ($action === 'addkey') {
        $who = 'a' . $session['account_id'];
        if (ln_count('key', $who, 3600) >= LN_KEYS_PER_HOUR) {
            $error = 'Too many keys made. Try again in an hour.';
        } else {
            ln_note('key', $who);
            $letters = ln_letters(12);
            $db->prepare('INSERT INTO activation_keys (account_id, key_hash, created_at, expires_at)
                          VALUES (?, ?, ?, ?)')
               ->execute([$session['account_id'], ln_hash('activation', $letters), ln_now(),
                          ln_now(LN_KEY_MINUTES * 60)]);
            $newKey = ln_grouped($letters);
        }
    } elseif ($action === 'remove') {
        $installId = ln_install_id($_POST['install'] ?? '');
        $q = $db->prepare('SELECT id FROM installs WHERE install_id = ? AND account_id = ?');
        $q->execute([$installId, $session['account_id']]);
        $row = $q->fetch();
        if ($row) {
            ln_release((int) $row['id']);
            $notice = 'Removed. Programs it was already paired with stay paired until they forget it.';
        }
    }

    if ($session !== null && $method === 'GET' && isset($_GET['t'])) {
        // a sign-in link opened again by a browser that is signed in: its
        // token is not left in the address bar
        header('Location: ./' . ($code !== '' ? '?code=' . ln_grouped($code) : ''), true, 303);
        exit;
    }
    if ($session !== null) {
        $view = 'account';
        $installs = ln_installs_of($session['account_id']);
    } elseif ($view !== 'sent') {
        // a mailed link: show the button (the link alone signs nobody in,
        // so a mail scanner that opens it uses nothing up)
        $t = $action === '' && is_string($_GET['t'] ?? null) ? $_GET['t'] : '';
        if (preg_match('/^[0-9a-f]{64}$/', $t)) {
            $token = $t;
            $view = 'confirm';
        }
    }
} catch (Throwable $e) {
    if (isset($db) && $db->inTransaction()) {
        $db->rollBack();
    }
    error_log('link page: ' . $e->getMessage());
    $problem = 'The link site is being set up. Please come back soon.';
    $hint = ln_setup_hint($e);
}

$csrf = $session !== null && $problem === '' ? ln_csrf($session) : '';

header('Content-Type: text/html; charset=utf-8');
header('X-Content-Type-Options: nosniff');
header('Cache-Control: no-store');
header('Referrer-Policy: no-referrer');
header('X-Frame-Options: DENY');
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>epubunum link</title>
<meta name="description" content="Connect your epubunum programs to each other without typing a code on each.">
<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E%3Crect width='32' height='32' rx='6' fill='%2316263f'/%3E%3Crect x='6' y='9' width='20' height='4' rx='2' fill='%23c9d3e3'/%3E%3Crect x='6' y='15' width='12' height='4' rx='2' fill='%23f0c84b'/%3E%3Crect x='20' y='15' width='6' height='4' rx='2' fill='%23c9d3e3'/%3E%3Crect x='6' y='21' width='16' height='4' rx='2' fill='%23c9d3e3'/%3E%3C/svg%3E">
<style>
  :root {
    --ink: #16263f; --ink-soft: #46566f; --paper: #f3f5f1; --marker: #f0c84b; --mist: #c9d3e3; --rule: #d5dad2;
    --warn: #8a2b1d;
    --book: "Iowan Old Style", "Palatino Linotype", Palatino, "Book Antiqua", Georgia, serif;
    --ui: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
    --mono: ui-monospace, "SF Mono", Menlo, Consolas, monospace;
  }
  * { box-sizing: border-box; }
  body { margin: 0; background: var(--paper); color: var(--ink); font-family: var(--ui); font-size: 1.0625rem;
         line-height: 1.6; }
  a { color: inherit; text-decoration-thickness: 1px; text-underline-offset: 0.2em; }
  a:focus-visible, button:focus-visible, input:focus-visible { outline: 3px solid var(--marker); outline-offset: 3px; }
  .wrap { max-width: 46rem; margin: 0 auto; padding: 0 1.5rem; }

  .field { background: var(--ink); color: var(--mist); padding-bottom: 2.5rem; }
  .masthead { display: flex; justify-content: space-between; align-items: baseline; gap: 1rem; padding: 1.5rem 0; }
  .name { font-family: var(--book); font-size: 1.5rem; color: #fff; text-decoration: none; }
  h1 { font-family: var(--book); font-weight: 400; color: #fff; font-size: clamp(2.2rem, 4.6vw, 3.2rem);
       line-height: 1.08; letter-spacing: -0.015em; margin: 1.5rem 0 1rem; }
  .field p { max-width: 38rem; margin: 0; }

  main.wrap { padding-top: 2.5rem; padding-bottom: 4.5rem; }
  section { padding: 2rem 0; border-top: 1px solid var(--rule); }
  section:first-of-type { border-top: 0; padding-top: 0.5rem; }
  h2 { font-family: var(--book); font-weight: 400; font-size: clamp(1.5rem, 2.4vw, 1.9rem); line-height: 1.15;
       margin: 0 0 0.5rem; }
  p { margin: 0 0 1rem; }
  .soft { color: var(--ink-soft); }
  .said { padding: 0.8rem 1rem; border-left: 4px solid var(--marker); background: #fff; margin: 0 0 1.5rem; }
  .said.bad { border-left-color: var(--warn); }

  label { display: block; font-weight: 600; margin: 0 0 0.35rem; }
  .row { display: flex; flex-wrap: wrap; gap: 0.75rem; align-items: stretch; }
  input[type="email"], input[type="text"] { flex: 1 1 14rem; min-width: 0; font: inherit; color: inherit;
       padding: 0.6rem 0.8rem; border: 1px solid var(--ink-soft); border-radius: 6px; background: #fff; }
  input.code { font-family: var(--mono); letter-spacing: 0.12em; text-transform: uppercase; flex: 0 1 12rem; }
  button { font: inherit; font-weight: 600; padding: 0.6rem 1.2rem; border: 1px solid var(--ink); border-radius: 6px;
           background: var(--ink); color: #fff; cursor: pointer; }
  button.quiet { background: transparent; color: var(--ink); font-weight: 400; padding: 0.3rem 0.8rem; }
  button.danger { background: transparent; color: var(--warn); border-color: var(--warn); }

  table { border-collapse: collapse; width: 100%; }
  th, td { text-align: left; padding: 0.7rem 1rem 0.7rem 0; border-top: 1px solid var(--rule); font-weight: 400;
           vertical-align: baseline; }
  thead th { border-top: 0; color: var(--ink-soft); font-size: 0.95rem; }
  td.what span { display: block; color: var(--ink-soft); font-size: 0.9rem; }
  td.act { text-align: right; padding-right: 0; }
  td.when { white-space: nowrap; color: var(--ink-soft); }

  .key { font-family: var(--mono); font-size: clamp(1.3rem, 4.2vw, 1.9rem); letter-spacing: 0.08em;
         background: #fff; border: 2px solid var(--marker); border-radius: 8px; padding: 0.7rem 1rem;
         display: inline-block; margin: 0 0 1rem; user-select: all; }
  pre { font-family: var(--mono); font-size: 0.95rem; background: var(--ink); color: var(--mist); padding: 0.8rem 1rem;
        border-radius: 6px; overflow-x: auto; margin: 0 0 1rem; }
  .check { display: flex; gap: 0.6rem; align-items: baseline; font-weight: 400; margin: 0 0 1rem; }
  footer { border-top: 1px solid var(--rule); padding: 1.5rem 0 3rem; color: var(--ink-soft); font-size: 0.95rem; }
</style>
</head>
<body>
<div class="field">
  <div class="wrap">
    <div class="masthead">
      <a class="name" href="https://www.epubunum.com/">epubunum</a>
      <span>link</span>
    </div>
    <h1>Your programs, connected</h1>
    <p>Sign in once, add each program to your account, and they connect to each other on your own network without
       a code typed on every one. Useful for a server with no screen, and for a TV.</p>
  </div>
</div>

<main class="wrap">
<?php if ($problem !== ''): ?>
  <p class="said bad" role="alert"><?= ln_h($problem) ?></p>
  <p class="soft">For whoever is setting it up: <?= ln_h($hint) ?>.</p>
<?php else: ?>
<?php if ($error !== ''): ?>
  <p class="said bad" role="alert"><?= ln_h($error) ?></p>
<?php endif; ?>
<?php if ($notice !== ''): ?>
  <p class="said" role="status"><?= ln_h($notice) ?></p>
<?php endif; ?>

<?php if ($view === 'sent'): ?>
  <section>
    <h2>Look at your mail</h2>
    <p>If that address takes mail, a sign-in link is on its way to it. The link works once, for
       <?= LN_SIGNIN_MINUTES ?> minutes. You can close this page.</p>
    <p class="soft">Nothing after a few minutes? Look among the spam, then <a href="./">ask again</a>.</p>
  </section>

<?php elseif ($view === 'confirm'): ?>
  <section>
    <h2>Sign in on this browser?</h2>
    <p>You opened a sign-in link. This browser stays signed in for <?= LN_SESSION_DAYS ?> days, or until you sign
       out.</p>
    <form method="post" action="./">
      <input type="hidden" name="action" value="confirm">
      <input type="hidden" name="t" value="<?= ln_h($token) ?>">
<?php if ($code !== ''): ?>
      <input type="hidden" name="code" value="<?= ln_h(ln_grouped($code)) ?>">
<?php endif; ?>
      <button type="submit">Sign in</button>
    </form>
  </section>

<?php elseif ($view === 'signin'): ?>
  <section>
    <h2>Sign in</h2>
    <p>Type your mail address and a sign-in link is sent to it. There is no password, and the first sign-in makes
       the account.</p>
    <form method="post" action="./">
      <input type="hidden" name="action" value="signin">
<?php if ($code !== ''): ?>
      <input type="hidden" name="code" value="<?= ln_h(ln_grouped($code)) ?>">
<?php endif; ?>
      <label for="email">Mail address</label>
      <div class="row">
        <input type="email" id="email" name="email" autocomplete="email" required maxlength="254">
        <button type="submit">Send the link</button>
      </div>
    </form>
<?php if ($code !== ''): ?>
    <p class="soft" style="margin-top:1rem">The code <?= ln_h(ln_grouped($code)) ?> from your screen is kept for
       after you have signed in.</p>
<?php endif; ?>
  </section>

<?php else: ?>
<?php if ($newKey !== ''): ?>
  <section>
    <h2>The key for your program</h2>
    <p>Start the program once with this key. It works one time, within <?= LN_KEY_MINUTES ?> minutes, and is not
       shown again.</p>
    <p class="key"><?= ln_h($newKey) ?></p>
    <p>For example:</p>
    <pre>BookServer --activate <?= ln_h($newKey) ?></pre>
    <p class="soft">Capitals and the dashes do not matter. When the program says it is activated, it is listed
       below.</p>
  </section>
<?php endif; ?>

  <section>
    <h2>Your installations</h2>
<?php if (!$installs): ?>
    <p class="soft">None yet. Add the first one below.</p>
<?php else: ?>
    <table>
      <thead><tr><th scope="col">Program</th><th scope="col">Added</th><th scope="col"><span class="soft">&nbsp;</span></th></tr></thead>
      <tbody>
<?php foreach ($installs as $install): ?>
        <tr>
          <td class="what"><?= ln_h($install['label'] ?? $install['app']) ?>
            <span><?= ln_h($install['app']) ?><?= $install['os'] !== null ? ', ' . ln_h($install['os']) : '' ?></span></td>
          <td class="when"><?= ln_h(substr((string) $install['claimed_at'], 0, 10)) ?></td>
          <td class="act">
            <form method="post" action="./">
              <input type="hidden" name="action" value="remove">
              <input type="hidden" name="csrf" value="<?= ln_h($csrf) ?>">
              <input type="hidden" name="install" value="<?= ln_h($install['install_id']) ?>">
              <button type="submit" class="quiet">Remove</button>
            </form>
          </td>
        </tr>
<?php endforeach; ?>
      </tbody>
    </table>
<?php endif; ?>
  </section>

  <section>
    <h2>Add a program that shows a code</h2>
    <p>A program with a screen shows eight letters and digits. Type them here.</p>
    <form method="post" action="./">
      <input type="hidden" name="action" value="code">
      <input type="hidden" name="csrf" value="<?= ln_h($csrf) ?>">
      <label for="code">Code</label>
      <div class="row">
        <input type="text" id="code" name="code" class="code" autocomplete="off" autocapitalize="characters"
               spellcheck="false" maxlength="12" required value="<?= ln_h($code !== '' ? ln_grouped($code) : '') ?>">
        <button type="submit">Add it</button>
      </div>
    </form>
  </section>

  <section>
    <h2>Add a program without a screen</h2>
    <p>For a server: make a one-time key here, then start the program with it once.</p>
    <form method="post" action="./">
      <input type="hidden" name="action" value="addkey">
      <input type="hidden" name="csrf" value="<?= ln_h($csrf) ?>">
      <button type="submit">Make a key</button>
    </form>
  </section>

  <section>
    <h2>This browser and your account</h2>
    <form method="post" action="./" style="margin-bottom:2rem">
      <input type="hidden" name="action" value="signout">
      <input type="hidden" name="csrf" value="<?= ln_h($csrf) ?>">
      <button type="submit" class="quiet">Sign out</button>
    </form>
    <form method="post" action="./">
      <input type="hidden" name="action" value="delete">
      <input type="hidden" name="csrf" value="<?= ln_h($csrf) ?>">
      <label class="check"><input type="checkbox" name="sure" value="yes">
        <span>Delete my account: every installation is taken off it and nothing of it is kept.</span></label>
      <button type="submit" class="danger">Delete the account</button>
    </form>
  </section>
<?php endif; ?>
<?php endif; ?>
</main>

<footer>
  <div class="wrap">
    What is kept: a one-way hash of your mail address, to know you at the next sign-in (the address itself is
    not stored), and for each installation the program's name, the name you gave it and its system. One cookie
    keeps you signed in; there is nothing from other sites. Programs bought on Steam never need this site.
  </div>
</footer>
</body>
</html>
