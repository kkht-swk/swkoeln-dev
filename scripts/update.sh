#!/usr/bin/env bash

set -euo pipefail

# This script extracts the production uploads, ACF Pro plugin and DB dump, replaces production settings in the DB dump with
# dev environment settings and updates the existing dev environment.
# It is intended to be used on an export of the production files and database in a single file
# with the following structure:
#   - swk.de/ (only wp-content/uploads and wp-content/plugins/advanced-custom-fields-pro are extracted)
#   - swk_db_dump.sql (the SQL dump of the production database)

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
VAR_DIR="$ROOT_DIR/var"
HTML_DIR="$VAR_DIR/html"
UPLOAD_DIR="$VAR_DIR/uploads"
ACF_DIR="$HTML_DIR/wp-content/plugins/advanced-custom-fields-pro"
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
        command -v sudo >/dev/null 2>&1 || die "sudo is required to replace uploads and ACF Pro and set www-data ownership."
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
if [[ ! -d "$HTML_DIR" || ! -d "$UPLOAD_DIR" ]]; then
    die "The development environment is missing. Run scripts/setup.sh first."
fi

# Optionally, we accept a filename for the production dump
if [[ "$#" -gt 1 ]]; then
    die "Usage: $0 [<tar.gz file from production>]"
fi
if [[ "$#" -eq 1 ]]; then
    if [[ ! -f "$1" ]]; then
        echo "Error: File '$1' not found"
        echo "Usage: $0 [<tar.gz file from production>]"
        echo "  If no file is provided, script looks for $PROD_ARCHIVE"
        exit 1
    fi
    PROD_ARCHIVE=$1
fi

if [[ ! -f "$PROD_ARCHIVE" ]]; then
    die "File '$PROD_ARCHIVE' not found"
fi

# last resort...
yesno="n"
if [[ "$yesno" != "y" ]]; then
    echo "I am about to process file '$PROD_ARCHIVE' and replace your development uploads, ACF Pro plugin and database."

    read -r -p "Are you sure? [y/N] " response
    lower=$(printf '%s' "$response" | tr '[:upper:]' '[:lower:]')
    if ! [[ "$lower" =~ ^(yes|y)$ ]]; then
        echo "Ok, exiting..."
        exit
    fi
fi

# Use a separate temp dir so an existing tmp directory is left untouched.
TMP_DIR="$(mktemp -d "$ROOT_DIR/tmp.update.XXXXXX")"
echo "Created temp dir $TMP_DIR..."

# Extract only uploads and ACF Pro, not the other WordPress files or configuration.
echo "Unzipping uploads and ACF Pro..."
tar -xzf "$PROD_ARCHIVE" -C "$TMP_DIR" \
    "$WEB_DUMP/wp-content/uploads" \
    "$WEB_DUMP/wp-content/plugins/advanced-custom-fields-pro"

# extract the DB dump and replace production settings with dev environment settings
echo "Preparing DB dump file..."
tar -xzf "$PROD_ARCHIVE" -C "$TMP_DIR" "$DB_DUMP"
"$ROOT_DIR/scripts/db_change.sh" "$TMP_DIR/$DB_DUMP" "$DEV_HOST" y

echo "Replacing uploads..."
as_root rm -rf -- "$UPLOAD_DIR"
mv "$TMP_DIR/$WEB_DUMP/wp-content/uploads" "$UPLOAD_DIR"

echo "Replacing ACF Pro plugin..."
as_root rm -rf -- "$ACF_DIR"
as_root mv "$TMP_DIR/$WEB_DUMP/wp-content/plugins/advanced-custom-fields-pro" "$ACF_DIR"

echo "Setting uploads and ACF Pro permissions..."
as_root chown -R www-data:www-data "$UPLOAD_DIR" "$ACF_DIR"

echo "Verifying containers are running..."

# start the containers first, as the DB container needs to be available for the import of the DB dump
docker compose up -d --wait --wait-timeout 120

# Docker must mount the replacement uploads directory, not the old directory.
docker compose restart wp

echo "Importing the database..."
# import the DB dump into the DB container
docker compose exec -T db sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb -u root $MARIADB_DATABASE' < "$TMP_DIR/$DB_DUMP"

echo "Changing some database values..."

# Remove unused serialized object
docker compose exec -e XDEBUG_MODE=off -u www-data wp wp option delete sm_status

# now change all relevant data in the DB
docker compose exec -e XDEBUG_MODE=off -u www-data wp wp search-replace \
  "https://schwarzweisskoeln.de" "$DEV_URL" \
  --all-tables-with-prefix --precise --skip-plugins --skip-themes --skip-columns=guid

echo ""
echo "Done. You can now access the dev environment:"
echo "  WordPress at http://$DEV_HOST/ or http://$DEV_HOST/admin"
echo "  Adminer at http://$DEV_HOST:8080"
echo "  Mailpit at http://$DEV_HOST:8025"
echo ""
echo "Have fun."
