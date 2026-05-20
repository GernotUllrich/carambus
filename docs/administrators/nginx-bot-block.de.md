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
| `/etc/nginx/sites-available/<scenario>` | Server-Block mit `if ($carambus_block_bot) { return 403 }` | bei jeder nginx.conf-Änderung |

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
   Erwartet: `map ...` und `if ($carambus_block_bot)`. Wenn leer → Snippet oder sites-available-Datei nicht aktuell.

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
