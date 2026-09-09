# NGINX Bot-Block — Operations-Workflow

**Eingeführt:** 2026-04-27 ([carambus_master commits](#commits))
**Betrifft:** Public-facing Carambus-Scenarios (carambus, carambus_api, carambus_bcw)

## Was macht der Bot-Block

Verbieten von Bot-/Crawler-Traffic am NGINX-Edge mittels User-Agent-Filter — ergänzt das `Disallow: /` in `/robots.txt` für Bad-Actor-Bots, die robots.txt ignorieren.

**Geblockt** (Klartext-Match auf `User-Agent`-Header, case-insensitive):
- Generische Crawler: `bot`, `crawler`, `spider`, `scraper`, `wget`, `curl/`, `python-requests`
- SEO/Marketing: `AhrefsBot`, `SemrushBot`, `DotBot`, `MJ12Bot`, `PetalBot`, `YandexBot`, `Bytespider`
- AI/LLM-Trainings-Bots: `GPTBot`, `ClaudeBot`, `ChatGPT-User`, `CCBot`, `anthropic-ai`, `Claude-Web`, `cohere-ai`, `Diffbot`, `FacebookBot`, `Google-Extended`, `PerplexityBot`
- Leerer User-Agent

**Antwort:** HTTP `403 Forbidden`.

**Ausnahme:** `/versions/*` ist vom Filter ausgenommen — der stündliche
Sync der Regional-/Location-Server (`Version.update_from_carambus_api`) ist per
Definition ein Skript. Ein 403 dort ist vom Client nicht von "keine Updates" zu
unterscheiden und legt den Datenabgleich still. Realisiert über
`$carambus_deny` statt `$carambus_block_bot`.

## Architektur

```
carambus_master/templates/nginx/carambus_bot_block.conf   ← statischer Snippet (map-Block)
carambus_master/templates/nginx/nginx_conf.erb            ← ERB mit conditional if-Block
                                ↓ rake scenario:generate_configs
carambus_data/scenarios/<name>/production/nginx.conf      ← generierte Datei (committed)
                                ↓ rake scenario:sync_nginx_conf
/etc/nginx/sites-available/<name>                         ← was NGINX wirklich liest
                                ↓ symlink
/etc/nginx/sites-enabled/<name>
```

Zwei separate Files auf dem Server:

| Datei | Was | Wann installieren |
|---|---|---|
| `/etc/nginx/conf.d/carambus_bot_block.conf` | `map`-Block (definiert `$carambus_block_bot` einmal pro Server) | EINMALIG pro Server |
| `/etc/nginx/sites-available/<scenario>` | Server-Block mit `if ($carambus_deny) { return 403 }` | bei jeder nginx.conf-Änderung |

**Warum getrennt:** Auf Multi-Scenario-Servern (z. B. Hetzner mit `carambus.de` UND `carambus_api`) würde ein doppelt definierter `map`-Block `nginx -t` failen mit "duplicate map directive". Der Snippet liegt deshalb genau einmal in `conf.d/`, jedes Scenario referenziert nur die Variable.

## Per-Scenario Opt-Out

In `carambus_data/scenarios/<name>/config.yml`:

```yaml
environments:
  production:
    bot_block_enabled: false   # default ist true; auf false setzen wenn scrapebar
```

Aktueller Stand:

| Scenario | bot_block_enabled | Begründung |
|---|---|---|
| carambus (carambus.de) | `false` | Soll für Suchmaschinen indexierbar bleiben |
| carambus_api (newapi.carambus.de) | `true` | API-Server, keine Suchmaschinen-Relevanz |
| carambus_bcw (bc-wedel.duckdns.org) | `true` | Vereins-Scoreboards, kein öffentlicher Content |
| carambus_nbv (nbv.carambus.de) | `false` während Walkthrough-Phase, `true` nach Pilot | Per-Region-Production für v0.4-Walkthrough; Sportwart-Friction durch UA-Override vermeiden (Plan 14-G.7 / Sub-Task 6.4) |
| carambus_gu / phat / pbv / location_5101 | `false` | LAN-only (192.168.x.x), keine Bot-Exposition |

LAN-Scenarios stehen explizit auf `false`, damit beim Re-Generate kein `if`-Block gerendert wird, der ohne installierten conf.d-Snippet den `nginx -t` failen lassen würde.

### Walkthrough-Phasen-Hinweis (Plan 14-G.7 / AC-6.4)

Für **Per-Region-Production-Scenarios während aktiver Walkthrough-Pilotphasen** (z.B. carambus_nbv bei Sportwart-Onboarding):

```yaml
environments:
  production:
    bot_block_enabled: false   # während Walkthrough-Phase explizit AUSSCHALTEN
```

**Begründung:** Während externe Sportwarte das System initial testen, würde der Bot-Block `curl`-basierte Setup-Scripts (z.B. Auth-Token-Snippets aus der Setup-Doku Sektion 9.2) mit `403 Forbidden` blocken — auch wenn der User explizit `-A "Mozilla/5.0"`-Override nutzt. Das ist Onboarding-Friction. Nach Abschluss der Walkthrough-Phase wird der Bot-Block wieder aktiviert.

**Re-Aktivierungs-Checkliste nach Pilot:**
1. `bot_block_enabled: true` in carambus_data/scenarios/carambus_nbv/config.yml
2. `rake scenario:generate_configs[carambus_nbv,production]`
3. `cap production deploy` ODER `rake scenario:sync_nginx_conf[carambus_nbv,production]`

## Workflows

### Neuer Server (einmalige Erst-Einrichtung)

```bash
cd /Users/gullrich/DEV/carambus/carambus_master
git pull   # falls nicht aktuell

bundle exec rake "scenario:install_bot_block[<scenario_name>]"
# z. B. scenario:install_bot_block[carambus_bcw]
# Liest ssh_host + ssh_port aus config.yml.
# scp + sudo mv + nginx -t + sudo systemctl reload nginx
```

Nur nötig für Scenarios mit `bot_block_enabled: true`. Snippet bleibt persistent in `/etc/nginx/conf.d/` über Deploys hinweg.

### Nach Änderung am ERB-Template oder am bot_block_enabled-Flag

```bash
cd /Users/gullrich/DEV/carambus/carambus_master
bundle exec rake "scenario:generate_configs[<scenario_name>,production]"

# Geänderte carambus_data-Files committen + pushen
cd /Users/gullrich/DEV/carambus/carambus_data
git add scenarios/<scenario_name>/config.yml scenarios/<scenario_name>/production/nginx.conf
git commit -m "..."
git push

# Nginx auf dem Server aktualisieren
cd /Users/gullrich/DEV/carambus/carambus_master
bundle exec rake "scenario:sync_nginx_conf[<scenario_name>]"
# scp + sudo mv → /etc/nginx/sites-available/ + nginx -t + reload
```

### Verifizieren

```bash
# Block-Test (sollte 403 sein wenn bot_block_enabled: true)
curl -I -A "AhrefsBot/7.0" http://<webserver_host>:<webserver_port>/

# Normaler Browser (sollte 200/30x sein)
curl -I -A "Mozilla/5.0" http://<webserver_host>:<webserver_port>/
```

Beispiel BCW:
```bash
curl -I -A "AhrefsBot/7.0" http://bc-wedel.duckdns.org:3131/   # → 403 Forbidden
curl -I -A "Mozilla/5.0"   http://bc-wedel.duckdns.org:3131/   # → 200 OK
```

## Die zweite Ebene: IP-Sperre in der Firewall

Der Bot-Block filtert nach **Kennung** (User-Agent) und antwortet mit 403. Manche
Besucher lassen sich damit nicht abwehren: wer eine Kennung fälscht, wer gar kein
HTTP spricht (Portscans, SSH-Bruteforce), oder wer den 403 kassiert und trotzdem
weiterhämmert. Dafür gibt es eine zweite Ebene — die iptables-Kette
`carambus-blocklist`.

| | Bot-Block (nginx) | Sperrliste (iptables) |
|---|---|---|
| Kriterium | User-Agent | Herkunfts-IP |
| Antwort | 403 Forbidden | Paket verworfen, keine Antwort |
| Reichweite | nur HTTP | jeder Port |
| Pflege | Muster im conf.d-Snippet | `/etc/iptables/blocklist.v4` |
| Geeignet für | Crawler, die sich zu erkennen geben | gezielte Angreifer, Scanner |

**Suchmaschinen gehören NICHT in die IP-Sperrliste.** Googlebot und bingbot geben
sich korrekt zu erkennen, der 403 des Bot-Blocks ist die richtige Antwort. Eine
IP-Sperre träfe wechselnde Crawler-Netze und wäre Pflege ohne Ertrag.

### Warum eine eigene Kette

`/etc/iptables/rules.v4` gehört dem Ansible-Template
(`roles/bootstrap/templates/rules.v4.j2`) und wird bei jedem Firewall-Lauf
überschrieben. Eine dort eingetragene Sperre wäre beim nächsten Lauf weg — genau
das ist auf bc-wedel beinahe passiert (Phase 14, 2026-09-09).

Die Sperrliste liegt deshalb in `/etc/iptables/blocklist.v4`, die Ansible mit
`force: no` **nie** anfasst, und wird vom netfilter-persistent-Plugin
`35-blocklist` in die eigene Kette geladen:

```
INPUT → ufw-before-input → ufw-user-input → carambus-blocklist
                                                    ↑
                                    /etc/iptables/blocklist.v4
```

Der Sprung steht bewusst **vor** allen ACCEPT-Regeln.

### Pflege

`bin/blocklist.sh` läuft auf dem Server, nicht auf dem Entwicklungsrechner:

```bash
ssh <host> 'sudo /var/www/<scenario>/current/bin/blocklist.sh status'
ssh <host> 'sudo /var/www/<scenario>/current/bin/blocklist.sh suggest 30'
ssh <host> 'sudo /var/www/<scenario>/current/bin/blocklist.sh add 203.0.113.7'
ssh <host> 'sudo /var/www/<scenario>/current/bin/blocklist.sh add 47.79.0.0/16'
```

`suggest` liest nur. Es wertet das Zugriffslog auf zwei Signale aus — Anfragepfade,
die kein legitimer Client stellt (`.env`, `wp-admin`, `.git/` …), und absolute URLs
auf einen **fremden** Host, also die Suche nach einem offenen Proxy.

**Ein leeres Ergebnis ist der Normalfall**, nicht ein Fehler. Auf bc-wedel standen
im gesamten Log von März bis September 2026 (55.796 Zeilen) genau 15 Proxy-Scans,
jeder mit einem einzigen Treffer. Ein Host hinter einer Fritzbox mit zwei
freigegebenen Ports sieht kaum Angriffsdruck.

**Einzelne Treffer nicht sperren.** Ein Proxy-Test von einer Consumer-IP ist
Hintergrundrauschen, und die Adresse gehört morgen jemand anderem. Eine Meldung
wird erst interessant, wenn dieselbe Adresse mit vielen Treffern erscheint. Ganze
Netze (`/16`) nur bei belegtem Muster.

### Fallen

- **`netfilter-persistent save` nicht zum Sichern benutzen.** Es ruft auch
  `15-ip4tables` auf und überschreibt `rules.v4` mit dem laufenden Stand — danach
  kollidiert jeder Ansible-Lauf damit. Immer erst die Datei schreiben, dann
  `netfilter-persistent reload`. `bin/blocklist.sh` macht genau das.
- **Vor dem ersten Firewall-Lauf auf einem Altsystem** die gewachsenen DROP-Einträge
  nach `blocklist.v4` migrieren. Der Task „Seed blocklist file" legt die Datei aus
  dem Template an (wenige IPs) und überschreibt sie wegen `force: no` **nie wieder** —
  läuft Ansible zuerst, sind die alten Einträge dauerhaft weg. Der Migrationsbefehl
  steht in `host_vars/<host>` im Ansible-Repo.
- **Nicht nach Anfragevolumen sperren.** Die Top-IPs eines Vereinsservers sind die
  eigenen Scoreboards, `127.0.0.1` und der eigene DSL-Anschluss mit wechselnden
  Adressen. `bin/blocklist.sh` schließt private Netze aus und lehnt sie auch bei
  `add` ab — die Prüfung von Hand bleibt trotzdem nötig, denn Vereinsmitglieder
  kommen aus denselben Providernetzen wie der Anschluss des Vereinslokals.

## Troubleshooting

### `nginx -t` failt mit "unknown variable carambus_block_bot"

Die Server-Block-Konfig referenziert `$carambus_block_bot`, aber der `map`-Block fehlt — d. h. das conf.d-Snippet ist nicht installiert.

**Fix:** `bundle exec rake "scenario:install_bot_block[<scenario_name>]"`

### `nginx -t` failt mit "duplicate map directive"

Der `map`-Block kommt zweimal vor. Mögliche Ursachen:
- Eine alte `nginx.conf`-Version hat noch den `map` direkt eingebettet (statt nur die Referenz). Re-generate via `rake scenario:generate_configs` und sync.
- Auf einem Multi-Scenario-Server ist der Snippet aus Versehen mehrfach in `conf.d/` (z. B. mit unterschiedlichen Filenamen). `ls /etc/nginx/conf.d/` prüfen, doppelte entfernen.

### Bot-UA wird nicht geblockt (curl liefert 200 statt 403)

Reihenfolge prüfen:

1. **Steht der Block in der von NGINX geladenen Config?**
   ```bash
   sudo nginx -T 2>/dev/null | grep -A1 carambus_block_bot
   ```
   Erwartet: `map ...` und `if ($carambus_deny)`. Wenn leer → Snippet oder sites-available-Datei nicht aktuell.

2. **Welche Datei lädt NGINX?**
   ```bash
   ls -la /etc/nginx/sites-enabled/
   sudo nginx -T 2>&1 | grep -E "^# configuration file"
   ```

3. **Ist das letzte `nginx reload` durch?**
   ```bash
   sudo systemctl status nginx
   ```

### Reverse: Bot-UA wird zu Unrecht geblockt (legitim, soll aber durch)

Sofort-Workaround: betroffenen UA aus `templates/nginx/carambus_bot_block.conf` entfernen, dann auf jedem Server:
```bash
bundle exec rake "scenario:install_bot_block[<scenario_name>]"
```

Long-term: das `default 0;` in der `map` ist die "Allow"-Spur — nur explizite Patterns triggern den Block. Sehr restriktive UAs lieber gar nicht erst aufnehmen.

## Commits

- `389206e2` — feat(nginx): per-scenario bot block via shared conf.d snippet
- `b3439639` — refactor(rake): scenario:install_bot_block takes scenario_name
- `53b3c25c` — feat(rake): add scenario:sync_nginx_conf

## Referenzierte Files

```
carambus_master/templates/nginx/carambus_bot_block.conf      ← Snippet (statisch)
carambus_master/templates/nginx/nginx_conf.erb               ← ERB-Template (conditional if)
carambus_master/lib/tasks/scenarios.rake                     ← install_bot_block + sync_nginx_conf
carambus_data/scenarios/<name>/config.yml                    ← bot_block_enabled-Flag
carambus_data/scenarios/<name>/production/nginx.conf         ← generiert
```

Für die zweite Ebene (IP-Sperre):

```
bin/blocklist.sh                                             ← Pflege der Sperrliste
/etc/iptables/blocklist.v4                                   ← die Liste (Ansible fasst sie nicht an)
/usr/share/netfilter-persistent/plugins.d/35-blocklist       ← lädt sie in die Kette
~/DEV/ansible/roles/bootstrap/tasks/main.yml                 ← Firewall-Tasks (--tags firewall)
~/DEV/ansible/roles/bootstrap/templates/rules.v4.j2          ← deklariert die Kette + Sprung
```
