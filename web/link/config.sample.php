<?php
// The link site's settings - a SAMPLE. Copy it, fill it in, and keep the
// copy OUT of the repository (it holds the database's password):
//
//   best:  one folder ABOVE the site's document root, as link-config.php
//          (visitors cannot reach it there);
//   else:  beside index.php as config.php (.htaccess keeps visitors out,
//          and the file prints nothing if it is reached anyway).

return [
    // Plesk: Databases shows the server, the database's name and its user.
    'dsn' => 'mysql:host=localhost;dbname=NAME_OF_THE_DATABASE;charset=utf8mb4',
    'user' => 'DATABASE_USER',
    'password' => 'DATABASE_PASSWORD',

    // Any long random text, set once and NEVER changed: every address,
    // key, code and session is kept only as a hash made with it. Changing
    // it forgets every account, sign-in and install.
    'salt' => 'PUT-FORTY-OR-MORE-RANDOM-CHARACTERS-HERE',

    // The site's own address, as the sign-in mails and the programs give
    // it (no slash at the end).
    'site' => 'https://link.epubunum.com',

    // Who the sign-in mails come from: an address of this domain that
    // exists in Plesk (Mail), or the mails will be taken for spam.
    'mail_from' => 'epubunum <no-reply@epubunum.com>',
];
