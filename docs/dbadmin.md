# DB Administration

You do not need and local tools, but leverage the docker containers. Commands should be
started from the `swkoeln-dev` directory (where `compose.yaml` resides)

Note: Commands ask for the MariaDB admin password, specified in the `.env` file.

## Create a dump

`docker compose exec -T db sh -c 'mariadb-dump -u root -p"$MARIADB_ROOT_PASSWORD" wp_swk_db' > wp_swk_db.sql`


## Import a dump

`docker compose exec -T db sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb -u root wp_swk_db' < wp_swk_db.sql`
