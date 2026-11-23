<?php
// The leaderboard's settings - a SAMPLE. Copy it, fill it in, and keep the
// copy OUT of the repository (it holds the database's password):
//
//   best:  one folder ABOVE the site's document root, as
//          leaderboard-config.php (visitors cannot reach it there);
//   else:  beside index.php as config.php (.htaccess keeps visitors out,
//          and the file prints nothing if it is reached anyway).

return [
    // Plesk: Databases shows the server, the database's name and its user.
    'dsn' => 'mysql:host=localhost;dbname=NAME_OF_THE_DATABASE;charset=utf8mb4',
    'user' => 'DATABASE_USER',
    'password' => 'DATABASE_PASSWORD',

    // Any long random text, set once and never changed: it salts the hash
    // that stands for a sender's address (rate limits). Changing it only
    // forgets who has sent how much in the last hour.
    'salt' => 'PUT-FORTY-OR-MORE-RANDOM-CHARACTERS-HERE',
];
