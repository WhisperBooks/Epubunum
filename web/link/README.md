# The link site - https://link.epubunum.com

PHP (7.4 or later, with PDO for MySQL) and a MySQL or MariaDB database.
One account, the installations it owns, and a way for those installations
to trust each other on the local network without the 6-digit code typed
on each. For installations that have no screen (a server) or no keyboard
(a TV). **Programs bought on Steam never need it**: their on-screen code
stays, and this is an extra.

| File | What it is |
|---|---|
| `index.php` | the page: sign in, the account's installations, add / remove |
| `api/register.php` | an installation makes itself known and gets its key |
| `api/claim.php` | an installation without a screen joins an account (a one-time key) |
| `api/code.php` | an installation with a screen asks for a code to show |
| `api/status.php` | an installation asks whether it has an account, and which others have |
| `api/ticket.php` | a client asks for a ticket to pair with a server of its account |
| `api/check.php` | the server asks whether a ticket handed to it is good |
| `api/release.php` | an installation leaves its account |
| `lib.php` | what they share (the rules of version 1 are its constants) |
| `schema.sql` | the tables - load once |
| `config.sample.php` | the settings to copy and fill in |
| `.htaccess` | keeps visitors out of everything but the page and `api/` |

## How it goes

1. **Sign in** (a person, in a browser): type a mail address, open the
   link mailed to it, press Sign in. No password. The first sign-in makes
   the account.
2. **Register** (a program, once): it sends its install id - the id it
   announces on the local network - and is given a key.
3. **Claim**, one of two ways:
   - *without a screen*: on the site, "Make a key" shows a one-time key
     (`ABCD-EFGH-JKMN`, an hour, once); the program is started with it
     once and sends it to `claim.php`;
   - *with a screen*: the program asks `code.php`, shows the code
     (`ABCD-EFGH`, ten minutes) and the site's address (`url` is for a QR
     code); the person types it on the site; the program asks
     `status.php` every five seconds until `claimed` is true.
4. **Pair** (two programs of one account, on the local network): the
   client asks `ticket.php` for a ticket for the server's install id and
   hands it to the server; the server shows it to `check.php`, is told
   which installation the client is, and gives it its own token as after
   a 6-digit code. From then on neither needs the site.

## Putting it up (Plesk)

1. **The database**: a new one (Databases > Add Database), or the
   leaderboard's - no table name is shared. Then Import Dump (or
   phpMyAdmin > Import) with `schema.sql`. It was not run against MySQL
   when written: if the import stops, the message names the statement.
2. **Mail**: the sign-in links are sent with PHP's `mail()`. Make the
   address of `mail_from` (Mail > Create Email Address, e.g. `no-reply`)
   so that the mails are not taken for spam. Not tried on the host.
3. **The settings**: copy `config.sample.php`, fill in the three database
   values, a long random `salt`, `site` and `mail_from`, and upload it as
   `link-config.php` ONE FOLDER ABOVE the document root (beside
   `httpdocs`, not in it). If that folder cannot be written to, upload it
   as `config.php` beside `index.php` instead. Never put the filled-in
   file in the repository (`.gitignore` leaves `config.php` out).
4. **The files**: everything in this folder except `README.md` and
   `config.sample.php` into the document root, with the `api` folder;
   remove the default `index.html` there.
5. **Look**: the address shows "Your programs, connected" and asks for a
   mail address. "The link site is being set up" means the settings file
   was not found or the database refused the connection (the reason is in
   the domain's PHP error log, never on the page). Then sign in: if no
   mail comes, the error log says whether it was accepted for sending.

## Changes to a database already made

None yet. A change is a statement listed here, run BEFORE the PHP files
that need it are uploaded.

## What version 1 checks

- An installation registers once with a random id and is given a key;
  every other call needs both. Only the key's hash is kept.
- Sign-in links (15 minutes), activation keys (an hour), codes (ten
  minutes) and tickets (two minutes) work once and are kept as hashes. A
  new code ends the one before.
- A sign-in link alone signs nobody in: the page it opens has a button
  (so a mail scanner that opens links uses nothing up).
- At most 3 sign-in mails an hour to an address and 10 asked from one
  place; 10 installations a day registered from one place; 10 wrong keys
  an hour from one place and 10 wrong codes an hour from an account; 10
  keys an hour made by an account; 6 codes and 30 tickets an hour asked
  by an installation; 50 installations in an account.
- A ticket is good only for the server it was asked for, shown with that
  server's own key, while both installations are of one account.
- An installation that has an account is not taken by another account:
  it is removed on the site, or releases itself, first.
- Forms of a signed-in browser carry the session's own mark; the cookie
  is HttpOnly, SameSite=Lax, and for HTTPS only when the site is.
- Not covered: the ticket travels between the two programs on the local
  network as the 6-digit code's token does today (plain HTTP). Removing
  an installation on the site does not undo pairings already made - the
  programs' own lists do that.

## Privacy

The mail address is NOT stored: it is typed at each sign-in, the link is
mailed to what was typed, and the account is known by a salted hash of
it. So the site cannot write to anyone, and nobody can read a list of
addresses out of it. No computer name, user name or network address is
stored; a sender is a salted hash, used only to count, gone after a day.
An installation is its random id, the program's name, the label its
owner gave it and its system. One cookie keeps a browser signed in;
nothing comes from other sites. "Delete the account" removes the
account, its sessions and keys, and takes every installation off it.

## The endpoints

All take a POST with a JSON object and answer JSON: `{"ok": true, ...}`
or `{"ok": false, "error": "..."}` with a fitting HTTP status (400 not as
expected, 401 unknown installation or wrong key, 403 not allowed, 409
already so, 429 too many, 500 the site's own trouble). Every call but
`register.php` carries `install_id` and `key`.

`POST /api/register.php` - body: `install_id` (a UUID), `app`
(`BookServer`, `BookManager`, `EpubBuilder` ...), optionally `label`
(what the owner calls it) and `os`. Answer: `key` - given once.

`POST /api/claim.php` - body: `activation_key` (as typed; case and
dashes do not count). Answer: `claimed` true.

`POST /api/code.php` - Answer: `code` (`ABCD-EFGH`), `url` (the site
with the code in it), `site` (the address to show), `expires_in` and
`interval` (seconds).

`POST /api/status.php` - Answer: `claimed`, and `installs`: the other
installations of the account (`install_id`, `app`, `label`, `os`).

`POST /api/ticket.php` - body: `server` (its install id). Answer:
`ticket`, `expires_in`.

`POST /api/check.php` - body: `ticket`. Answer: `client` (`install_id`,
`app`, `label`, `os`).

`POST /api/release.php` - Answer: `claimed` false.

## Testing

`python3 tools/test_link.py` (from the repository's root; needs `php`
with SQLite) runs the site on a local port against a throw-away SQLite
database, with the mails written to a file, and checks signing in, both
ways of claiming, the tickets, leaving, and the limits.
