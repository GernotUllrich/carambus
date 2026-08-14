# TASK: ActionCable Origin-/CSRF-Härtung

**Erstellt:** 2026-08-14
**Status:** offen — noch nicht umgesetzt
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

**V3 — Origin der Overlay-Clients messen** *(ohne Verhaltensänderung!)*
Temporär in `ApplicationCable::Connection#connect` mitloggen:
```ruby
Rails.logger.info "[ActionCable][origin-probe] origin=#{request.env['HTTP_ORIGIN'].inspect} " \
                  "host=#{request.env['HTTP_HOST'].inspect} proto=#{request.ssl? ? 'https' : 'http'}"
```
Ein bis zwei Tage im Normalbetrieb laufen lassen (inkl. **einer Streaming-Session mit OBS**
und **mindestens einem Scoreboard**), dann auswerten:
```bash
grep "origin-probe" log/production.log | sort -u | head -50
```
**Erfolgskriterium für den eigentlichen Fix:** Jede beobachtete Zeile erfüllt
`origin == "#{proto}://#{host}"`. Jede Abweichung ist ein Kandidat für die Whitelist —
oder ein Grund, den Fix zu vertagen.
**Ergebnis hier eintragen:** _______________

> Diese Probe ist der Kern des Tasks. Ohne sie ist die Umstellung geraten, nicht belegt.

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
