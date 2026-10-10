<?php

/*
| Razorpay TEST keys.
| 1. Razorpay Dashboard -> switch to TEST MODE (top right)
| 2. Settings -> API Keys -> Generate Test Key
| 3. Paste Key Id and Key Secret between the quotes below (no spaces).
|
| The React .env is NOT read here. PHP needs the keys in this file.
| Never put key_secret in the React app.
|
| After editing, open in browser (logged in as admin, via the app's Purchases page
| or with the token): GET /api/payments/diagnose  -> tells you exactly what is wrong.
*/
$keyId     = 'rzp_test_kFACQEbZzr4lUe';
$keySecret = 'czoSmS7mEkbts6nPbR9gv5EL';

return [
    'key_id'     => trim(getenv('RAZORPAY_KEY_ID') ?: $keyId),
    'key_secret' => trim(getenv('RAZORPAY_KEY_SECRET') ?: $keySecret),
    'currency'   => 'INR',

    // XAMPP on Windows usually has no CA bundle, which makes every Razorpay call fail with
    // "SSL certificate problem". While developing locally we skip the check automatically.
    // Set to true on a real server (or set curl.cainfo in php.ini and leave this false).
    'verify_ssl' => false,
];
