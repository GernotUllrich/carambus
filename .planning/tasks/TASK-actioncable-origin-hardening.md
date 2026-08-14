# TASK: ActionCable Origin-/CSRF-Härtung

**Erstellt:** 2026-08-14
**Status:** Messung auf der Authority **abgeschlossen** (2026-08-14), Probe wieder entfernt.
Flag **unverändert** — die Umstellung ist auf der Authority allein nicht validierbar (siehe 4a).
**Herkunft:** CONCERNS.md, Sektionen „ActionCable Forgery Protection Disabled" +
„Broad ActionCable Origin Validation"
**Risiko bei Umsetzung:** mittel — kann WebSocket-Verbindungen (Scoreboards) brechen
**Deploy:** eigenständig deploybar; Prod-Freigabe durch Betreiber erforderlich

---

## 1. Der eigentliche Befund (wichtiger als die CONCERNS.md-Formulierung)

Die CONCERNS.md listet zwei getrennte Punkte („Forgery Protection aus" und „Regex zu
breit"). Die Verifikation in der Rails-Quelle zeigt: **das ist ein Befund, und die
naheliegende Teil-Reparatur wäre wirkungslos.**

`actioncable-7.2.2.2/lib/action_cable/connection/base.rb:228-240`:

```ruby
def allow_request_origin?
  return true if server.config.disable_request_forgery_protection   # 229 ← short-circuit

  proto = Rack::Request.new(env).ssl? ? "https" : "http"
  if server.config.allow_same_origin_as_host && env["HTTP_ORIGIN"] == "#{proto}://#{env['HTTP_HOST']}"
    true                                                            # 232 ← greift ZUERST
  elsif Array(server.config.allowed_request_origins).any? { |o| o === env["HTTP_ORIGIN"] }
    true                                                            # 234
  else
    logger.error("Request origin not allowed: #{env['HTTP_ORIGIN']}")
    false
  end
end
```

Daraus folgen drei Dinge:

**(a) `allowed_request_origins` ist heute toter Code.**
`config/application.rb:176` setzt `disable_request_forgery_protection = true`. Zeile 229
kehrt sofort zurück — die Origin-Liste wird **nie** ausgewertet. Wer „nur den Regex
verschärft", ändert am Laufzeitverhalten **exakt nichts** und erzeugt eine falsche
Sicherheitsannahme. Der Regex ist nicht das Problem, sondern das Symptom.

**(b) Die Regexe sind ohnehin kaputt formuliert.**
`/http:\/\/*/` bedeutet „`http:` gefolgt von *null oder mehr* `/`" — nicht „http://irgendwas".
Er matcht unverankert jeden String, der `http:` enthält. Selbst als Whitelist gedacht wäre
er wirkungslos. (Gleiches in `config/environments/development.rb:94`.)

**(c) Der Fix ist deshalb genau eine Änderung: `disable_request_forgery_protection = false`.**
Erst dann wird die Origin-Logik überhaupt aktiv.

---

## 2. Warum das voraussichtlich sicher ist

`allow_same_origin_as_host = true` (`application.rb:177`) wird in Zeile 232 **vor** der
Liste geprüft und deckt den Normalfall vollständig ab: Browser lädt die Seite von Host X,
WebSocket geht an denselben Host X → `Origin == "proto://Host"` → erlaubt.

Das deckt ohne jede Whitelist ab:
- alle Scenario-Domains (`carambus_domain` ist pro Instanz getemplatet, `carambus.yml.erb:129/145`)
- lokale Server unter beliebiger LAN-IP oder beliebigem Hostnamen
- `api.carambus.de` und `carambus.de`

Bestätigend auf der Client-Seite: `app/javascript/channels/consumer.js:8` nutzt
`createConsumer("/cable")` — **relativ**, also per Definition same-origin.

**Konsequenz für den Zielzustand:** Es wird vermutlich *gar keine* Origin-Whitelist
gebraucht. Der Zielzustand ist `allowed_request_origins` leer/entfernt + 
`allow_same_origin_as_host = true` + Forgery-Protection an.

---

## 3. Konkrete Bruchrisiken (das ist der zu testende Teil)

| # | Risiko | Warum | Prüfung |
|---|---|---|---|
| R0 | **⚠ Initializer überschreibt `application.rb` — Fix an EINER Stelle wirkungslos** | `config/initializers/action_cable.rb:4` setzt `ActionCable.server.config.disable_request_forgery_protection = true` **direkt auf der Server-Config**. Initializer laufen **nach** `application.rb` → die Änderung in `application.rb` allein wird zurückgesetzt. **Beide Stellen müssen geändert werden.** | in Schritt 1 berücksichtigt |
| R1 | **Generiertes `production.rb` überschreibt die Änderung** | `config/environments/production.rb` ist **nicht im Repo** (`git ls-files` kennt nur `staging.rb`, `test.rb`) und wird pro Scenario erzeugt. Setzt es selbst `disable_request_forgery_protection = true`, läuft der Fix ins Leere. | Schritt V1 |
| R2 | **Reverse-Proxy verfälscht `Host`** | nginx muss `Host` und die WS-Upgrade-Header korrekt durchreichen, sonst `Origin != Host` trotz same-origin. `config/deploy/templates/nginx_conf.erb` enthält **keinen** `/cable`-Block — Konfiguration liegt woanders. | Schritt V2 |
| R3 | **`https` vor Proxy, `http` dahinter** | Zeile 231 leitet `proto` aus `Rack::Request#ssl?` ab. Ohne `X-Forwarded-Proto` bildet Rails `http://…`, der Browser sendet `https://…` → **kein** Match, Verbindung bricht. Klassischer Fallstrick hinter TLS-Terminierung. | Schritt V2 |
| R4 | **Streaming-Overlay in OBS** | `app/views/layouts/streaming_overlay.html.erb:29` nutzt `action_cable_meta_tag`. OBS-Browser-Source sendet je nach Version einen abweichenden oder **gar keinen** `Origin`-Header. Fehlender Origin (`nil`) matcht Zeile 232 nicht → Abbruch. | Schritt V3 |
| R5 | **Dev bricht** | `development.rb:93` setzt `action_cable.url = "ws://localhost:3000/cable"` (absolut). Seite über `127.0.0.1` oder LAN-IP geöffnet → Origin ≠ Host. | entschärft: `development.rb:90` setzt eigenes `disable_request_forgery_protection = true`; **development.rb nicht anfassen** |

R3 und R4 sind die realistischsten Brecher.

---

## 4. Vorarbeit (read-only, keine Codeänderung)

**V1 — Generiertes production.rb prüfen** *(Betreiber, auf `api.carambus.de`)*
```bash
grep -n "action_cable" config/environments/production.rb
```
Erwartung für den Fix: keine Zeile, die `disable_request_forgery_protection` auf `true`
setzt. Falls doch → Fix muss zusätzlich in der Scenario-Template-Quelle erfolgen.
**Ergebnis hier eintragen:** _______________

**V2 — Proxy-Header prüfen** *(Betreiber)*
```bash
grep -rn -A10 "location /cable\|proxy_set_header" /etc/nginx/sites-enabled/ | head -40
```
Nötig sind `proxy_set_header Host $host;` **und** `X-Forwarded-Proto $scheme;` sowie
`Upgrade`/`Connection`-Header. Zusätzlich muss Rails den Proxy als vertrauenswürdig
ansehen (`config.assume_ssl` / `force_ssl` bzw. `ActionDispatch::SSL`) — sonst R3.
**Ergebnis hier eintragen:** _______________

**V3 — Origin der Clients messen** — ✔ IMPLEMENTIERT (2026-08-14)

`ApplicationCable::Connection#log_origin_probe` ist als **Dry-Run ohne
Verhaltensänderung** eingebaut. Sie bildet die Prüfung für den *Zielzustand* nach
(Forgery-Protection aktiv, Whitelist leer) und schreibt pro Verbindungsaufbau eine Zeile:

```
[ActionCable][origin-probe] origin="https://api.carambus.de" host="api.carambus.de" proto=https same_origin=true would_reject=false
```

Bewusst über `Rails.logger` statt über den Cable-Logger — letzterer ist in Production auf
`Logger.new(nil)` gesetzt und würde die Zeilen verschlucken. Damit ist die Auswertung
unabhängig davon, ob der Logger-Punkt (Schritt 1) schon erledigt ist.

Im Fehlerfall schluckt ein `rescue` die Probe weg: sie darf einen Verbindungsaufbau
unter keinen Umständen verhindern.
Nach dem Deploy im Normalbetrieb laufen lassen — zwingend inklusive **einer
Streaming-Session mit OBS** und **mindestens einem Scoreboard**, das sind die
kritischen Fälle. Dann auswerten:

```bash
grep "origin-probe" log/production.log | sed 's/.*\[origin-probe\] //' | sort | uniq -c | sort -rn
```

Direkt die Problemfälle herausziehen:
```bash
grep "origin-probe" log/production.log | grep "would_reject=true"
```

**Erfolgskriterium für den eigentlichen Fix:** `would_reject=true` kommt nicht vor
(oder nur für Clients, die nachweislich egal sind). Jede Abweichung ist ein Kandidat
für die Whitelist — oder ein Grund, den Fix zu vertagen.

**Achtung `origin=nil`:** Clients, die gar keinen `Origin`-Header senden (native
WebSocket-Clients, je nach Version auch OBS), erscheinen als `origin=nil` und damit als
`would_reject=true`. Das ist Risiko R4 und **kein** Messfehler — sie würden nach der
Umstellung tatsächlich abgewiesen. Eine Whitelist hilft dort nicht (sie matcht gegen
`HTTP_ORIGIN`, das ja fehlt); nötig wäre dann eine bewusste Ausnahme im Code.

**Ergebnis hier eintragen:** _______________

> Diese Probe ist der Kern des Tasks. Ohne sie ist die Umstellung geraten, nicht belegt.

---

## 4a. Messergebnis Authority (2026-08-14) — und warum das Flag trotzdem liegen bleibt

Probe lief in Production auf `api.carambus.de`:

```
grep "origin-probe" log/production.log | grep -c "would_reject=true"
→ 0
```

Beispielzeile:
```
origin="https://api.carambus.de" host="api.carambus.de" proto=https
same_origin=true would_reject=false
```

**Für den Web-Traffic der Authority ist die Umstellung damit belegt unkritisch.** Auch R3
(fehlendes `X-Forwarded-Proto`) ist entkräftet: `proto=https` wird korrekt erkannt, der
Proxy reicht das Schema durch.

**Trotzdem nicht umgestellt.** Auf der Authority laufen **weder Scoreboards noch
OBS-Overlays** — genau die beiden Fälle, die den Task riskant machen (R4: Clients ohne
`Origin`-Header). Gemessen wurde also ausschließlich der unkritische Teil.

Da `config/application.rb` und `config/initializers/action_cable.rb` **geteilter Code**
über alle Instanzen sind, würde das Umlegen des Flags die lokalen/regionalen Server
mittreffen — dort, wo die ungemessenen Clients sitzen.

**Voraussetzung für die Umstellung:** dieselbe Probe auf einem lokalen Server mit
Scoreboard (nbv/bcw/phat) laufen lassen, inklusive einer OBS-Streaming-Session, und dort
`would_reject=true` auf 0 prüfen. Die Probe ist auf der Authority entfernt; für den
lokalen Einsatz kann sie aus Commit `9cc4579b` / `098fce80` wiederhergestellt werden.

Die beiden Fallstricke aus Schritt 1 (R0: Initializer überschreibt `application.rb`;
`Logger.new(nil)` verschluckt `"Request origin not allowed"`) gelten dort unverändert.

---

## 5. Umsetzung

Erst nach V1–V3 mit belegtem Erfolgskriterium.

### Schritt 1 — Config umstellen (`config/application.rb:175-177`)

```ruby
# vorher
config.action_cable.allowed_request_origins = [/http:\/\/*/, /https:\/\/*/]
config.action_cable.disable_request_forgery_protection = true
config.action_cable.allow_same_origin_as_host = true

# nachher
# Origin-Prüfung aktiv: same-origin genügt (Scoreboards/Overlays laden ihre Seite
# jeweils vom selben Host, consumer.js nutzt die relative URL "/cable").
# Cross-Origin-Ausnahmen ggf. hier ergänzen — Regexe MÜSSEN verankert sein (\A…\z).
config.action_cable.allow_same_origin_as_host = true
config.action_cable.allowed_request_origins = []
config.action_cable.disable_request_forgery_protection = false
```

**Zusätzlich zwingend** (R0) — `config/initializers/action_cable.rb`:

```ruby
# vorher (Zeile 4-5) — überschreibt application.rb, weil Initializer später laufen
ActionCable.server.config.disable_request_forgery_protection = true
ActionCable.server.config.allow_same_origin_as_host = true

# nachher: Zeile 4 ersatzlos entfernen; Zeile 5 ist redundant zu application.rb
# (dort gesetzt) und kann ebenfalls weg.
```

**Ebenfalls in dieser Datei (blockiert sonst die Verifikation!):**

```ruby
if Rails.env.production?
  ActionCable.server.config.logger = Logger.new(nil)   # ← verschluckt ALLE Cable-Logs
```

`Logger.new(nil)` verwirft auch `"Request origin not allowed: …"` aus `base.rb:237`.
Damit wäre der Prod-Check in Schritt 3 **strukturell blind** — er fände nie etwas,
egal wie viele Verbindungen scheitern. Vor dem Rollout mindestens auf
`Logger.new($stdout).tap { |l| l.level = Logger::ERROR }` o. Ä. anheben, sonst ist
die gesamte Abnahme wertlos.

**verify:** `bin/rails test test/channels/` läuft grün; zusätzlich in der Konsole
prüfen, dass die Config auch nach dem Boot stimmt:
```bash
bin/rails runner 'p ActionCable.server.config.disable_request_forgery_protection'
```
→ muss `false` ausgeben. Das ist der eigentliche Beweis, dass R0/R1 nicht greifen.

### Schritt 2 — Regression-Test ergänzen

Neu: `test/channels/application_cable/connection_test.rb`.
`config/environments/test.rb` enthält **keine** `action_cable`-Overrides (geprüft), der
Test sieht also die Werte aus `application.rb`.

```ruby
# frozen_string_literal: true

require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  # Regression zu CONCERNS.md: Forgery-Protection war global deaktiviert, wodurch
  # allowed_request_origins toter Code war (actioncable base.rb:229).
  test "request forgery protection ist aktiv" do
    refute ActionCable.server.config.disable_request_forgery_protection,
           "disable_request_forgery_protection=true macht die Origin-Pruefung wirkungslos"
  end

  test "keine unverankerten catch-all origin-regexe" do
    Array(ActionCable.server.config.allowed_request_origins).each do |origin|
      next unless origin.is_a?(Regexp)
      assert_match(/\\A/, origin.source, "Origin-Regex #{origin.inspect} ist nicht verankert")
    end
  end

  test "same-origin wird akzeptiert" do
    connect env: { "HTTP_HOST" => "api.carambus.de", "HTTP_ORIGIN" => "http://api.carambus.de" }
  end

  test "fremde origin wird abgewiesen" do
    assert_reject_connection do
      connect env: { "HTTP_HOST" => "api.carambus.de", "HTTP_ORIGIN" => "http://angreifer.example" }
    end
  end
end
```

> **Noch nicht ausgeführt.** Beim Umsetzen validieren. Zwei erwartbare Stolpersteine:
> (1) `find_verified_user` gibt derzeit `User.first` zurück — ohne User-Fixture kann
> `connect` bereits an der Authentifizierung statt an der Origin scheitern; ggf. Fixture
> laden. (2) Der `proto` in Zeile 231 kommt aus `Rack::Request#ssl?`; im Test daher
> `http://` verwenden oder `HTTPS`/`rack.url_scheme` mitgeben.

**verify:** `bin/rails test test/channels/application_cable/connection_test.rb` grün;
zusätzlich gegen den *alten* Config-Stand laufen lassen — Test 1 und 4 müssen dann
**fehlschlagen**, sonst testet er nichts.

### Schritt 3 — Staged Rollout

1. Lokal: Scoreboard-Seite öffnen, Verbindung im Browser-Devtools-Netzwerk-Tab prüfen
   (WS-Status 101, kein Reconnect-Loop).
2. Staging deployen; `grep "Request origin not allowed" log/staging.log` → muss leer sein.
3. Prod nach Freigabe. **Innerhalb der ersten Stunde**:
   ```bash
   grep -c "Request origin not allowed" log/production.log
   ```
   → jeder Treffer nennt den blockierten Origin und ist entweder Whitelist-Kandidat
   oder Rollback-Grund.

**verify (Definition of Done):**
- [ ] V1–V3 dokumentiert, Probe zeigt ausschließlich same-origin
- [ ] `test/channels/` grün, neuer Test schlägt gegen alte Config fehl
- [ ] Staging: Scoreboard + Overlay + Live-Turnier ohne WS-Fehler
- [ ] Prod 24 h: `Request origin not allowed` = 0

### Rollback
Einzeiler: `disable_request_forgery_protection` zurück auf `true`, Deploy. Kein
Datenbank- oder Migrationsanteil, daher folgenlos.

---

## 6. Abgrenzung — nicht Teil dieses Tasks

**`find_verified_user` gibt `User.first` zurück**
(`app/channels/application_cable/connection.rb:28`, Kommentar „Temporär für Debugging"):

```ruby
def find_verified_user
  # Temporär für Debugging:
  User.first || reject_unauthorized_connection
end
```

Jede WebSocket-Verbindung wird damit als **erster User der Tabelle** authentifiziert —
unabhängig von Session und Login. Ist das ein Admin, hat jeder Verbindungsaufbau dessen
Identität in allen Channels/Reflexes.

Das relativiert den Nutzen der Origin-Härtung erheblich: Origin-Prüfung schützt vor
*fremden Seiten*, die eine Verbindung aufbauen — nicht vor einer Verbindung, die sich
selbst zum ersten User erklärt. **Sachlich ist das der schwerwiegendere Befund.**

Bewusst getrennt gehalten, weil der Fix Kenntnis darüber braucht, wie Scoreboards
(die typischerweise *keinen* eingeloggten User haben) authentifiziert werden sollen —
das ist eine Design-Entscheidung, keine Config-Änderung. **Eigener Task.**
In CONCERNS.md bislang nicht erfasst.

---

# ANHANG (nur auf `scenario/nbv/actioncable-origin-probe`)

## Messung auf dem lokalen Server — Runbook

**Zweck:** Die Authority-Messung (2026-08-14) ergab `would_reject=true` = **0**, deckte aber
nur Browser-Traffic ab. Auf `api.carambus.de` laufen **weder Scoreboards noch OBS-Overlays** —
genau die Clients, die über das Flag entscheiden (Risiko **R4**: Clients ohne `Origin`-Header
werden nach der Umstellung abgewiesen, und eine Whitelist hilft dort nicht, weil sie gegen
`HTTP_ORIGIN` matcht).

Weil `config/application.rb` **geteilter Code** über alle Instanzen ist, würde ein Umlegen
des Flags die lokalen Server mittreffen. Diese Messung schließt die Lücke.

### Was diese Probe zusätzlich kann

Gegenüber der Authority-Variante ordnet sie jede Verbindung einem **Client-Typ** zu —
sonst ließe sich ein `would_reject=true` hinterher nicht zuordnen:

```
[ActionCable][origin-probe] client=scoreboard origin="http://192.168.1.50:3000"
  host="192.168.1.50:3000" proto=http same_origin=true would_reject=false ua="Mozilla/5.0 …"
```

`client` ist `scoreboard` (User `scoreboard@carambus.de`), `user` oder `anonymous`.
Die gekürzte `ua` identifiziert OBS-Browser-Sources und native WebSocket-Clients.

Dazu liegt die Probe bewusst **nach** `find_verified_user` in `connect` — nur so ist die
Identität beim Loggen schon bekannt.

### Deploy eines Feature-Branches

Der Standard-Deploy rollt **nur `master`** aus: `config/deploy.rb:10` und
`config/deploy/production.rb:14` setzen beide `set :branch, 'master'`, und die Stage-Datei
gewinnt (sie lädt zuletzt). Ein ENV-Override existiert nicht.

`config/deploy/production.rb` ist aber **gitignored** und damit pro Checkout lokal — die
Umstellung ist deshalb eine reine Betriebsänderung ohne Commit. Im nbv-Checkout Zeile 14:

```ruby
set :branch, 'scenario/nbv/actioncable-origin-probe'
```

Danach wie gewohnt deployen.

> ⚠️ **Zurückstellen nicht vergessen.** Nach der Messung Zeile 14 wieder auf
> `set :branch, 'master'`. Bleibt sie stehen, rollt **jeder** künftige Deploy dieses
> Checkouts weiter den Probe-Branch aus — der dann keine Master-Updates mehr bekommt.
> Vor jedem Deploy kurz prüfen:
> ```bash
> grep -n "set :branch" config/deploy/production.rb
> ```

### Ablauf

1. Branch auf dem lokalen Server ausrollen (Deploy führt der Betreiber, siehe oben).
2. **Normalbetrieb erzeugen** — und zwar zwingend alle drei Fälle:
   - [ ] mindestens ein **Scoreboard** aktiv (idealerweise über die LAN-IP geöffnet, nicht nur über den Hostnamen)
   - [ ] eine **OBS-Streaming-Session** mit Overlay
   - [ ] ein paar normale Browser-Zugriffe (eingeloggt und anonym)
3. Auswerten:

```bash
grep "origin-probe" log/production.log | grep -c "would_reject=true"
```

```bash
grep "origin-probe" log/production.log | grep "would_reject=true" | sed 's/.*\[origin-probe\] //' | sort | uniq -c | sort -rn
```

Verteilung über alle Client-Typen (zeigt auch, ob überhaupt alle drei Fälle erfasst wurden —
fehlt `client=scoreboard`, war die Messung unvollständig):

```bash
grep "origin-probe" log/production.log | grep -o "client=[a-z:]*" | sort | uniq -c
```

### Entscheidungsregel

| Ergebnis | Konsequenz |
|---|---|
| `would_reject=true` = 0 **und** alle drei Client-Typen kamen vor | Umstellung belegt sicher → Schritt 1 des Tasks umsetzen |
| `would_reject=true` > 0 mit `client=user`/`anonymous` | Whitelist-Kandidat, Origin aus dem Log übernehmen (verankert: `\A…\z`) |
| `would_reject=true` > 0 mit `client=scoreboard` **oder** `origin=nil` | **Nicht umstellen.** Whitelist hilft bei fehlendem `Origin` nicht — es bräuchte eine bewusste Code-Ausnahme |

### Nicht vergessen

- Die Probe schreibt **eine Zeile pro Verbindungsaufbau**. Auf der Authority war `/` bei
  85,2 % — vor längerem Betrieb den Plattenplatz prüfen.
- **Dieser Branch wird nicht nach `master` gemergt.** Er trägt nur die Messung. Nach der
  Auswertung: Ergebnis in Abschnitt 4a des Tasks auf `master` eintragen, Branch verwerfen.
- Der eigentliche Fix (Schritt 1) hat zwei Fallstricke, die hier unverändert gelten:
  **R0** — `config/initializers/action_cable.rb:4` setzt `disable_request_forgery_protection`
  erneut und überschreibt `application.rb`; **Logger** — `ActionCable.server.config.logger =
  Logger.new(nil)` in Production verschluckt `"Request origin not allowed"` und macht jede
  Abnahme blind.
