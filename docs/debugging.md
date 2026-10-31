# PHP-Debugging mit VS Code und Xdebug

Wie im README erwähnt sollte man einfach in VS Code die Multi-Root Umgebung
öffnen und kann dann dort einfach das Debugging mit Xdebug launchen können.
Die Konfiguration stellt sicher, dass alle relevanten Pfade korrekt gemappt sind,
so dass man das Theme, aber auch WP Code und Plugins etc debuggen kann.

Xdebug verbindet sich **vom Container zu VS Code** auf dem Host über
`host.docker.internal:9003`. Eine Docker-Portfreigabe für 9003 ist deshalb nicht
nötig. `xdebug.start_with_request=yes` aktiviert das Debugging bei jedem Request;
ein Browser-Plugin oder ein Trigger-Parameter ist nicht erforderlich.

Bei Problemen:

- `docker compose exec wp php --ri xdebug` prüft, ob Xdebug geladen und der
  Step Debugger aktiviert ist.
- `ss -ltnp 'sport = :9003'` sollte während der laufenden VS-Code-Debug-Sitzung
  einen Listener zeigen. Nur einen Debug-Listener gleichzeitig starten.
- Bei grauen/unbestätigten Breakpoints zuerst den geöffneten Workspace und die
  Pfadzuordnung prüfen. Zum Testen kann vorübergehend `"stopOnEntry": true`
  in die Launch-Konfiguration aufgenommen werden.
- Wenn keine Verbindung ankommt, Host-Firewall und Erreichbarkeit von Port 9003
  aus dem Docker-Netz prüfen. VS Code muss für diese Konfiguration auf dem
  Docker-Host laufen, nicht in einem separaten Dev Container.
- Nach Änderungen an `config/php/conf.d/xdebug.ini` den PHP/Apache-Container mit
  `docker compose restart wp` neu starten.
