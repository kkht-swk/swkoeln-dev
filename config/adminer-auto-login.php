<?php
// See https://www.adminer.org/en/extension/
// What worked best is to just simply override the login form.

// See https://github.com/TimWolla/docker-adminer/issues/231

function adminer_object() {

    class MyDbLocalAdminer extends Adminer\Adminer {

        function loginForm() {
            echo Adminer\input_hidden('auth[driver]', 'server');
            echo Adminer\input_hidden('auth[server]', getenv('ADMINER_HOST'));
            echo Adminer\input_hidden('auth[username]', getenv('ADMINER_USER'));
            echo Adminer\input_hidden('auth[password]', getenv('ADMINER_PWD'));
            echo Adminer\input_hidden('auth[db]', getenv('ADMINER_DB'));
            echo Adminer\script("document.querySelector('form').submit();");
        }
    }

    return new MyDbLocalAdminer;
}

include '/var/www/html/adminer.php';
