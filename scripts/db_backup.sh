#!/usr/bin/env bash

set -euo pipefail

set -a
. ./.env
set +a

docker compose exec -T db sh -c 'mariadb-dump -u root -p"$MARIADB_ROOT_PASSWORD" "$MARIADB_DATABASE"' > wp_swk_db.sql`
