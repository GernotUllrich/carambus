# Wissenswertes — Inhalte für die Clubmitglieder

Statische Seiten, die unter `/wissenswertes/` erreichbar sind und vom Knopf
„Wissenswertes" auf der Scoreboard-Welcome-Page verlinkt werden
(`app/views/locations/scoreboard_welcome.html.erb`).

## Warum liegt das hier und nicht in `public/`?

`public/wissenswertes` ist ein Capistrano-**`linked_dir`** (`config/deploy.rb`). Der Inhalt
lebt pro Server unter `shared/public/wissenswertes/` und ist damit **nicht Teil des Deploys** —
er lässt sich ändern, ohne die Anwendung neu auszurollen, und übersteht umgekehrt jeden Deploy.
Dieses Verzeichnis hier ist die versionierte Quelle; `publish.sh` bringt sie auf die Server.

⚠️ **`doc/` (Einzahl), nicht `docs/`.** `docs/` ist das Quellverzeichnis von mkdocs
(`docs_dir: docs` in `mkdocs.yml`). Wer hier ablegt, veroeffentlicht ungewollt in die
technische Dokumentation unter `/docs/`: ein laufender mkdocs-Watcher baut den Inhalt sofort
nach `public/docs/` mit und schreibt Suchindex und Sitemap neu. `doc/` ist der Platz fuer
Material, das *nicht* zur Dokumentationsseite gehoert.

## Dateien

| Datei | Rolle |
|---|---|
| `neu-im-august.html` | Quelle der Präsentation. **Fragment**, kein vollständiges Dokument — siehe unten. |
| `index.html` | Übersichtsseite, die unter `/wissenswertes/` erscheint |
| `neu-im-august.pdf-quelle.html` | eigene Fassung fürs Drucken (A4 hoch, Zeilenlängen freigegeben) |
| `Carambus-Neu-im-August.pdf` | daraus erzeugt, per „Drucken → Als PDF sichern" im Browser |
| `publish.sh` | baut und verteilt |

⚠️ `neu-im-august.html` ist ein **Fragment ohne `<!doctype>`, `<head>` und `<meta charset>`** —
so kam es aus dem Artifact-Werkzeug, das diesen Rahmen selbst beisteuert. Direkt auf einen Server
gelegt zerlegt es die Umlaute, weil nginx `Content-Type: text/html` ohne `charset` sendet und der
Browser dann Latin-1 rät. **Deshalb nie von Hand kopieren, immer `publish.sh` nehmen** — das
Skript setzt den Rahmen und den Rückweg zum Scoreboard davor.

## Veröffentlichen

```
./publish.sh bcw           # nur Wedel
./publish.sh gu phat       # mehrere auf einmal
```

Bekannte Instanzen:

| Instanz | Server | Pfad |
|---|---|---|
| `bcw` | `bc-wedel` | `/var/www/carambus_bcw` |
| `gu` | `192.168.178.29`, Port 8910 | `/var/www/carambus_gu` |
| `phat` | ssh-Alias `gu` | `/var/www/carambus_phat` |

⚠️ **Namensfalle:** Der ssh-Alias `gu` zeigt auf die Maschine, auf der zurzeit
`carambus_phat` läuft. Die Instanz `carambus_gu` liegt auf `192.168.178.29`.

Auf einer Instanz, die den `linked_dir` noch nicht kennt (vor Commit `3ed8e41c`), bricht
`publish.sh` mit einer Meldung ab — dort erst einmal `cap production deploy` laufen lassen.

## PDF neu erzeugen

`neu-im-august.pdf-quelle.html` im Browser öffnen, „Drucken" → „Als PDF sichern", A4 hoch,
Ränder Standard, Hintergrundgrafiken an.

## Die verschickte Adresse

Per E-Mail an die Mitglieder ging **http://bc-wedel.duckdns.org:3131/wissenswertes/**.
`publish.sh` ruft diese Adresse nach jedem Hochladen selbst auf und meldet, wenn sie nicht
mit HTTP 200 antwortet.

⚠️ **Beim Prüfen von Hand immer eine Browser-Kennung mitschicken.** nginx wertet auf allen
Instanzen `$carambus_deny` aus (`/etc/nginx/conf.d/carambus_bot_block.conf`) und weist die
Standardkennung von `curl` mit „403 Forbidden" ab. Ohne `-A` sieht eine völlig intakte Seite
aus wie eine kaputte:

```
curl -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
     -o /dev/null -w "%{http_code}\n" http://bc-wedel.duckdns.org:3131/wissenswertes/
```

Dass `/wissenswertes/` ohne Dateinamen funktioniert, liegt an nginx' `try_files $uri
$uri/index.html $uri.html` in der `location /` — die Adresse braucht also kein `index.html`
am Ende und bleibt so kurz, wie sie verschickt wurde.
