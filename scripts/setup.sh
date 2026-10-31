#!/usr/bin/env bash

set -euo pipefail

# This script extracts the production data and DB dump, replaces all production settings in the DB dump with
# dev environment settings and sets up the dev environment.
# It is intended to be used on an export of the production files and database in a single file
# with the following structure:
#   - swk.de/ (the production files)
#   - swk_db_dump.sql (the SQL dump of the production database)

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
VAR_DIR="$ROOT_DIR/var"
HTML_DIR="$VAR_DIR/html"
UPLOAD_DIR="$VAR_DIR/uploads"
LOG_FILE="$VAR_DIR/log/debug.log"
TMP_DIR=""

PROD_ARCHIVE=swkweb.tar.gz
WEB_DUMP=swk.de
DB_DUMP=swk_db_dump.sql

set -a
. "$ROOT_DIR/.env"
set +a

DEV_HOST="${DEV_HOST:-localhost}"
DEV_URL="http://$DEV_HOST"

as_root() {
    if [[ "$EUID" -eq 0 ]]; then
        "$@"
    else
        command -v sudo >/dev/null 2>&1 || die "sudo is required to set www-data ownership."
        sudo -- "$@"
    fi
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

cleanup() {
    if [[ -n "$TMP_DIR" ]]; then
        rm -rf -- "$TMP_DIR"
    fi
}
trap cleanup EXIT


# Some checks first when we will not do anything!

if [[ -d $VAR_DIR ]]; then
    echo "Error: '$VAR_DIR' already exists - exiting"
    exit 1
fi

# if [[ -d $VAR_DIR ]]; then
#     echo "Error: '$VAR_DIR' already exists - exiting"
#     exit 1
# fi


# Optionally, we accept a filename for the production dump
if [[ "$#" -eq 1 ]]; then
    if [[ ! -f "$1" ]]; then
        echo "Error: File '$1' not found"
        echo "Usage: $0 [<tar.gz file from production>]"
        echo "  If no file is provided, script looks for $PROD_ARCHIVE"
        exit 1
    fi
    PROD_ARCHIVE=$1
fi

# check if ../swkoeln is present
if [[ ! -d "$ROOT_DIR/../swkoeln" ]]; then
    die "Theme directory ../swkoeln is missing. Clone the theme alongside swkoeln-dev first."
fi

# last resort...
yesno="n"
if [[ "$yesno" != "y" ]]; then
    echo "I am about to process file '$PROD_ARCHIVE' and set up a development environment."

    read -r -p "Are you sure? [y/N] " response
    lower=$(printf '%s' "$response" | tr '[:upper:]' '[:lower:]')
    if ! [[ "$lower" =~ ^(yes|y)$ ]]; then
        echo "Ok, exiting..."
        exit
    fi
fi

if [[ ! -f "$PROD_ARCHIVE" ]]; then
    die "File '$PROD_ARCHIVE' not found"
    exit 1
fi


# create the debug.log - requires root!
echo "Creating the debug.log file..."
if [[ ! -d "$LOG_FILE" ]]; then
    id www-data >/dev/null 2>&1 || die "The local www-data user is required."
    WP_UID="$(id -u www-data)"
    WP_GID="$(getent group www-data | cut -d: -f3)"
    [[ -n "$WP_GID" ]] || die "The local www-data group is required."

    mkdir -p -- $VAR_DIR/log
    touch -- $LOG_FILE
    as_root chown -R www-data:www-data "$VAR_DIR/log"
fi

# Use a separate temp dir so an existing tmp directory is left untouched.
TMP_DIR="$(mktemp -d "$ROOT_DIR/tmp.setup.XXXXXX")"
echo "Created temp dir $TMP_DIR..."

# unzip the production files, remove unneeded plugins and overwrite .htaccess and move over
echo "Unzipping WordPress files..."
tar -xzf $PROD_ARCHIVE -C $TMP_DIR $WEB_DUMP
rm -rf $TMP_DIR/$WEB_DUMP/wp-content/plugins/{all-in-one-wp-security-and-firewall,google-sitemap-generator,koko-analytics,updraftplus}
rm -rf $TMP_DIR/$WEB_DUMP/wp-content/{aiowps_backups,mu-plugins}
rm -rf $TMP_DIR/$WEB_DUMP/aios-bootstrap.php
rm -rf $TMP_DIR/$WEB_DUMP/wp-content/themes/swkoeln
cp $ROOT_DIR/config/acf-php-to-json.php $TMP_DIR/$WEB_DUMP/wp-content/plugins
cp $ROOT_DIR/config/dot.htaccess $TMP_DIR/$WEB_DUMP/.htaccess

echo "Providing development wp-config.php..."
as_root rm -f "$TMP_DIR/$WEB_DUMP/wp-config.php"
cat > "$TMP_DIR/$WEB_DUMP/wp-config.php" <<'PHP'
<?php
// Local development configuration. Credentials are supplied by Docker Compose.
foreach (['WORDPRESS_DB_HOST', 'WORDPRESS_DB_NAME', 'WORDPRESS_DB_USER', 'WORDPRESS_DB_PASSWORD'] as $variable) {
    if (getenv($variable) === false || getenv($variable) === '') {
        throw new RuntimeException('Missing required environment variable: ' . $variable);
    }
}

define('DB_HOST', getenv('WORDPRESS_DB_HOST'));
define('DB_NAME', getenv('WORDPRESS_DB_NAME'));
define('DB_USER', getenv('WORDPRESS_DB_USER'));
define('DB_PASSWORD', getenv('WORDPRESS_DB_PASSWORD'));
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');

$table_prefix = 'wp_';

define('WP_ENVIRONMENT_TYPE', 'development');
define('WP_DEBUG', true);
define('WP_DEBUG_LOG', true);
define('WP_DEBUG_DISPLAY', false);
@ini_set('display_errors', '0');

PHP

for key in AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT; do
    printf "define('%s', '%s');\n" "$key" "$(openssl rand -hex 48)" >> "$TMP_DIR/$WEB_DUMP/wp-config.php"
done

cat >> "$TMP_DIR/$WEB_DUMP/wp-config.php" <<'PHP'

if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/');
}
require_once ABSPATH . 'wp-settings.php';
PHP

mv $TMP_DIR/$WEB_DUMP/wp-content/uploads $UPLOAD_DIR
mv $TMP_DIR/$WEB_DUMP $HTML_DIR

echo "Setting file permissions..."
as_root chown -R www-data:www-data "$VAR_DIR/"


# extract the DB dump and replace production settings with dev environment settings
echo "Preparing DB dump file..."
tar -xzf "$PROD_ARCHIVE" -C "$TMP_DIR" "$DB_DUMP"
"$ROOT_DIR/scripts/db_change.sh" "$TMP_DIR/$DB_DUMP" "$DEV_HOST" y


echo "Verifying containers are running..."

# start the containers first, as the DB container needs to be available for the import of the DB dump, which is done in a second step.
docker compose up -d --wait --wait-timeout 120

echo "Importing the database..."
# import the DB dump into the DB container
docker compose exec -T db sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb -u root $MARIADB_DATABASE' < $TMP_DIR/$DB_DUMP

echo "Changing some database values..."

# Remove unused serialized object
docker compose exec -e XDEBUG_MODE=off -u www-data wp wp option delete sm_status

# now change all relevant data in the DB
docker compose exec -e XDEBUG_MODE=off -u www-data wp wp search-replace \
  "https://schwarzweisskoeln.de" "$DEV_URL" \
  --all-tables-with-prefix --precise --skip-plugins --skip-themes --skip-columns=guid

echo "Installing plugins..."
docker compose exec -e WP_CLI_CACHE_DIR=/tmp/wp-cli-cache -e XDEBUG_MODE=off -u www-data wp wp plugin install debug-bar --activate --quiet
# docker compose exec -u www-data wp wp plugin activate acf-php-to-json

echo ""
echo "Done. You can now access the dev environment:"
echo "  WordPress at http://$DEV_HOST/ or http://$DEV_HOST/admin"
echo "  Adminer at http://$DEV_HOST:8080"
echo "  Mailpit at http://$DEV_HOST:8025"
# echo "Please login into the WP backend now and do a BetterReplace of https://schwarzweisskoeln.de to http://$DEV_HOST"
# echo "Also consider to add dev plugins, like the debug bar and query monitor."
echo ""
echo "Have fun."
