# swkoeln-dev

Lokale Docker-Entwicklungsumgebung für das WordPress-Theme **swkoeln**. Dieses Repository enthält die Infrastruktur, **nicht** den Theme-Quellcode.

## Verzeichnisstruktur

Die beiden Git-Repositories müssen nebeneinander liegen:

```text
Dev/
├── swkoeln/              # WordPress-Theme (eigenes Git-Repository)
└── swkoeln-dev/          # Diese Entwicklungsumgebung
    ├── compose.yaml
    ├── swkoeln.code-workspace
    ├── config/           # PHP-/Xdebug-Konfiguration, .htaccess, Adminer und Hilfsplugin
    │   ├── php/conf.d/   # PHP-Fehlerausgabe und Xdebug
    │   ├── dot.htaccess  # Lokale Apache-Konfiguration
    │   ├── adminer-auto-login.php
    │   └── acf-php-to-json.php
    ├── scripts/          # Ersteinrichtung und Datenaktualisierung
    │   ├── setup.sh      # Vollständige Umgebung aus Produktionsdump einrichten
    │   ├── update.sh     # Uploads, ACF Pro und Datenbank aktualisieren
    │   ├── db_change.sh  # SQL-Dump für die lokale Umgebung anpassen
    │   ├── db_backup.sh  # Datenbankexport
    └── var/              # Laufzeitdaten, nicht in Git
        ├── html/         # WordPress-Core und Plugins
        ├── uploads/      # WordPress-Mediendateien
        └── log/          # debug.log
```

Docker bindet `../swkoeln` direkt unter `/var/www/html/wp-content/themes/swkoeln` ein. Änderungen am Theme sind dadurch unmittelbar in der lokalen WordPress-Installation sichtbar.

## Ersteinrichtung

Voraussetzungen: Docker mit Compose, Bash, `tar`, `openssl`, ein lokaler Benutzer und eine Gruppe `www-data` sowie das Repository `../swkoeln`. Für die Dateirechte wird bei Bedarf `sudo` verwendet.

Alle folgenden Befehle im Verzeichnis `swkoeln-dev` ausführen.

1. `.env` anhand der `.env.example` anlegen und die Datenbank-Zugangsdaten setzen:

   ```bash
   cp .env.example .env
   ```

2. Einen Produktionsdump als `.tar.gz` bereitstellen. Das Archiv muss folgende Struktur enthalten:

   ```text
   swk.de/                 # WordPress-Dateien einschließlich wp-content/uploads
   swk_db_dump.sql          # SQL-Dump der Produktionsdatenbank
   ```

3. In `.env` den Wert von `DEV_HOST` auf den lokal erreichbaren Hostnamen setzen (zum Beispiel `DEV_HOST=myhost`). Setup und Update verwenden beide diesen Wert.

4. Die Ersteinrichtung ausführen und die Rückfrage bestätigen:

   ```bash
   ./scripts/setup.sh /pfad/zum/produktionsdump.tar.gz
   ```

   Ohne Dateiangabe wird `swkweb.tar.gz` im aktuellen Verzeichnis verwendet. **Das Verzeichnis `var/` darf noch nicht existieren**, andernfalls bricht das Skript ab.

   Das Skript:
   - übernimmt WordPress und Plugins aus dem Archiv, entfernt ausgewählte Produktionsplugins und ersetzt die `.htaccess` durch die lokale Vorlage;
   - legt Uploads unter `var/uploads` und WordPress unter `var/html` ab;
   - erstellt `var/log/debug.log` und setzt die Dateirechte für `www-data`;
   - erzeugt eine lokale `wp-config.php` mit Datenbank-Zugangsdaten aus Compose, Entwicklungsmodus und Debug-Logging;
   - startet die Container und importiert den SQL-Dump;
   - passt Kollation, Website- und Mail-Einstellungen für die Entwicklung an und ersetzt Produktions-URLs mittels `wp search-replace` (außer in der Spalte `guid`);
   - installiert und aktiviert das Plugin Debug Bar.

   **Achtung:** Eine bereits vorhandene Datenbank im Docker-Volume wird beim Import überschrieben. Das Setup erstellt mit `mktemp` ein zufällig benanntes Arbeitsverzeichnis `tmp.setup.XXXXXX` im Projektverzeichnis und entfernt es beim Beenden wieder. Ein vorhandenes Verzeichnis `tmp/` bleibt unberührt.

5. WordPress unter dem eingestellten Hostnamen öffnen. Die Website und Benutzerkonten stammen aus dem Produktionsdump; eine neue WordPress-Installation über den Einrichtungsdialog ist nicht nötig.

Die Dienste sind bei `DEV_HOST=myhost` erreichbar unter:

| Dienst | Adresse |
| --- | --- |
| WordPress | http://myhost |
| Adminer | http://myhost:8080 |
| Mailpit | http://myhost:8025 |
| MariaDB (vom Host) | `127.0.0.1:3306` |

Später starten mit `docker compose up -d`, stoppen mit `docker compose down`. Persistente Daten bleiben dabei erhalten.

## Produktionsdaten aktualisieren

Für eine bereits eingerichtete Umgebung `scripts/update.sh` verwenden:

```bash
./scripts/update.sh /pfad/zum/produktionsdump.tar.gz
```

Ohne Dateiangabe wird auch hier `swkweb.tar.gz` verwendet. Das Archiv muss dieselbe Struktur wie bei der Ersteinrichtung haben. `.env`, `var/html` und `var/uploads` müssen bereits vorhanden sein; `DEV_HOST` in `.env` muss zur lokalen Umgebung passen.

**Achtung: Lokale Uploads, das Plugin `advanced-custom-fields-pro` und Datenbankinhalte werden durch die Produktionsdaten ersetzt. Änderungen bei Bedarf vorher sichern.** Vor dem Update fragt das Skript nach einer Bestätigung.

Das Update extrahiert nur `swk.de/wp-content/uploads`, `swk.de/wp-content/plugins/advanced-custom-fields-pro` und den SQL-Dump. Es ersetzt `var/uploads` sowie `var/html/wp-content/plugins/advanced-custom-fields-pro` vollständig und setzt deren Dateirechte. Anschließend importiert es die Datenbank mit denselben Entwicklungsanpassungen wie beim Setup. Die Container werden bei Bedarf gestartet; WordPress wird neu gestartet, damit Docker das ersetzte Upload-Verzeichnis einbindet.

Die übrigen WordPress-Dateien, Themes und Plugins sowie `.htaccess`, `wp-config.php` und `debug.log` bleiben unverändert. Das Update erstellt mit `mktemp` ein zufällig benanntes Arbeitsverzeichnis `tmp.update.XXXXXX` im Projektverzeichnis und entfernt es beim Beenden wieder. Ein vorhandenes Verzeichnis `tmp/` bleibt unberührt.

## Entwicklung mit VS Code

```bash
code swkoeln.code-workspace
```

Der **Multi-Root Workspace** öffnet sowohl das Theme als auch die Entwicklungsumgebung. Die enthaltene Xdebug-Launch-Konfiguration ermöglicht Breakpoints und Step-Debugging im Theme, in WordPress-Core und in Plugins. Dazu in VS Code **Debug WordPress** starten.

## Persistente Daten

`var/` und `.env` sind nicht Teil des Git-Repositories. WordPress-Dateien, Uploads und Debug-Log liegen unter `var/`. MariaDB und Mailpit speichern ihre Daten dagegen in den benannten Docker-Volumes `mariadb_data` und `mailpit_data`, nicht unter `var/`.

`docker compose down` erhält diese Volumes; `docker compose down -v` löscht sie. Bei Setup und Update werden die URLs automatisch an die lokale Umgebung angepasst.
