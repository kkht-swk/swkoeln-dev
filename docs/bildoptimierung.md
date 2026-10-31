# Bildoptimierung: Stand 01.11.2026

## Erkenntnisse
- `oldvar/uploads`: 293 MB; `var/uploads`: 680 MB. Der Zuwachs stammt fast vollständig aus neuen Uploads 2026, vor allem transparenten PNG-Porträts samt WordPress-Größenvarianten.
- Neue transparente PNG-Ausgangsbilder enthalten im Mittel rund achtmal so viele Pixel wie die alten. WebP unterstützt die benötigte Transparenz und spart bei Fotos erheblich Platz.
- Die Mannschaftsseite lud Originale für eine Darstellung von nur 250 × 340 px. Im direkten Browservergleich war die optimierte Ausgabe nahezu gleichwertig.

## Lokal umgesetzt
- `../swkoeln/templates/single-mannschaft.twig`: Porträts werden zentriert auf maximal 1.000 × 1.360 px zugeschnitten und als WebP mit Qualität 82 ausgegeben. Kleinere Quellen werden nicht hochskaliert; Lazy Loading und asynchrones Dekodieren sind aktiviert.
- Erste-Herren-Seite geprüft: 38 Porträts jetzt zusammen **2,79 MB statt 79,7 MB** (−96,5 %). Mannschaftsfoto, Originale und Medienreferenzen blieben unverändert.
- Timber erzeugt Varianten beim ersten Rendern unter `var/uploads/` neben den Originalen und verwendet sie anschließend wieder. Das wurde durch einen zweiten Seitenaufruf geprüft.
- Zusätzlich entstanden PNG-/JPEG-Zwischendateien (37,71 MB) und vier Vergleichsdateien (0,41 MB). Aktuell hat Download-Effizienz Vorrang vor Speicherplatz.

## Noch offen
- Weitere Mannschaftsseiten, kleine Quellen und Bildausschnitte visuell prüfen; produktive Bereitstellung separat durchführen und dort WebP-Unterstützung sicherstellen.
- Erstgenerierung vorwärmen: Der erste lokale Aufruf überschritt das PHP-Zeitlimit von 30 Sekunden; nach erneutem Aufruf waren alle Varianten vorhanden.
- Weitere Theme-Vorlagen auf passende Größen, WebP und gegebenenfalls `srcset`/`sizes` umstellen; Upload-Regeln nach Bildzweck definieren, nicht global auf Porträtmaße begrenzen.
- Später Speicher optimieren: direkt vom Original zum WebP konvertieren und fertige Varianten vorab prüfen. Erst danach Zwischendateien entfernen; die aktuelle Filterkette würde sie sonst neu erzeugen. Vergleichsdateien können separat entfernt werden.
- Bestehende Medien/Dubletten nur mit Sicherung und Referenzprüfung bereinigen; keine automatische Bestandsmigration oder Upload-Begrenzung umgesetzt.
