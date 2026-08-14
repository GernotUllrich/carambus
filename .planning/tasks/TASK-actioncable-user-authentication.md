# TASK: ActionCable — Authentifizierung statt `User.first`

**Erstellt:** 2026-08-14
**Status:** offen — noch nicht umgesetzt
**Herkunft:** Befund bei der Ausarbeitung von `TASK-actioncable-origin-hardening.md`;
in CONCERNS.md (2026-04-09) **nicht** enthalten
**Risiko bei Umsetzung:** mittel — kann Scoreboard-/Reflex-Verbindungen brechen
**Priorität:** höher als die Origin-Härtung (Begründung unten)

---

## 1. Befund

`app/channels/application_cable/connection.rb:26-29`:

```ruby
def find_verified_user
  # Temporär für Debugging:
  User.first || reject_unauthorized_connection
end
```

**Jede** WebSocket-Verbindung wird als *erster User der `users`-Tabelle* authentifiziert —
ohne Bezug zu Session, Cookie oder Login. `current_user` in allen Channels und Reflexes
ist damit dieser eine User. Ist es ein Admin, hat jeder Verbindungsaufbau dessen Rechte.

`reject_unauthorized_connection` ist praktisch unerreichbar: es greift nur, wenn die
`users`-Tabelle **leer** ist.

### Historie — das war einmal korrekt

```
79419edb  initial commit   env["warden"].user || reject_unauthorized_connection
c1e473cb  "checkpoint"     2025-02-25   →  User.first   # "Temporär für Debugging:"
```

Die ursprüngliche Implementierung war der Devise-Standard. Sie wurde am **2025-02-25** in
einem Commit namens „checkpoint" durch den Debug-Hack ersetzt und **nie zurückgenommen** —
seit rund 18 Monaten in Produktion.

Das ist der wichtigste Hinweis für die Umsetzung: **es gibt keinen fachlichen Grund für
`User.first`.** Zu klären ist nur, warum `env["warden"].user` damals nicht lieferte.

---

## 2. Warum das der schwerwiegendere Befund ist

Die Origin-Härtung (`TASK-actioncable-origin-hardening.md`) schützt davor, dass eine
*fremde Seite* eine Verbindung aufbaut. Sie hilft **nicht** gegen eine Verbindung, die
sich selbst zum ersten User erklärt. Solange `find_verified_user` so bleibt, ist die
Origin-Prüfung eine Tür neben einer offenen Wand.

Empfohlene Reihenfolge: **dieser Task zuerst**, Origin-Härtung danach.

---

## 3. Zielzustand (Vorgabe Betreiber)

Scoreboards laufen unter dem User `scoreboard@carambus.de`. **Das ist bereits implementiert
und funktioniert über HTTP** — der Task muss es nicht bauen, nur nicht kaputt machen.

`app/controllers/locations_controller.rb:631-640`:

```ruby
unless current_user.present?
  @user = User.scoreboard                    # User.find_by_email("scoreboard@carambus.de")
  if @user&.valid?
    bypass_sign_in @user, scope: :user       # ← echte Devise-Session
    Current.user = @user
  ...
```

`bypass_sign_in` legt eine **reguläre Warden-/Devise-Session** an. Der Scoreboard-Client
trägt danach ein gültiges Session-Cookie — genau das, was `env["warden"].user` auswertet.

**Daraus folgt der Zielzustand — Rückbau auf den Devise-Standard:**

```ruby
def find_verified_user
  env["warden"]&.user || reject_unauthorized_connection
end
```

Kein Sonderweg für Scoreboards nötig: sie sind über `bypass_sign_in` bereits ein
angemeldeter User wie jeder andere.

Weitere bestätigende Belege, dass `scoreboard@carambus.de` ein vollwertiger Account ist:
- `app/models/user.rb:86` — `User.scoreboard` (liefert in `test`-Env bewusst `nil`)
- `app/models/user.rb:102` — von `purge_unconfirmed!` ausgenommen
- `app/models/user.rb:234` — eigenes Default-Theme (`dark`)
- `lib/tasks/installation.rake:118` — wird bei der Installation angelegt

---

## 4. Die offene Frage — und wie sie beantwortet wird

**Warum lieferte `env["warden"].user` 2025-02-25 nicht?** Ohne Antwort führt ein Rückbau
denselben Fehler wieder herbei. Drei plausible Ursachen:

| # | Hypothese | Gegenprüfung |
|---|---|---|
| H1 | `env["warden"]` ist im Cable-Env gar nicht gesetzt (Warden-Middleware läuft für `/cable` nicht mit) | Probe P1 |
| H2 | Warden ist da, aber die Session ist leer — Cookie wird beim WS-Handshake nicht mitgeschickt | Probe P1 (`session_id` vorhanden, `user` nil) |
| H3 | Session-Store-Problem: `development.rb:4` nutzt `:redis_session_store`; für andere Envs ist **kein** `session_store` konfiguriert (`config/initializers/session_store.rb` ist vollständig auskommentiert) → Prod fällt auf CookieStore zurück | Probe P1 + `bin/rails runner 'p Rails.application.config.session_store'` |

H3 ist ein eigenständiger Konsistenz-Befund: Dev nutzt Redis-Sessions, Prod (mangels
Konfiguration) vermutlich CookieStore. Das gehört unabhängig von diesem Task geklärt.

### Probe P1 — messen statt raten *(read-only, kein Verhaltenswechsel)*

Temporär in `connect` einfügen, **ohne** `find_verified_user` zu ändern:

```ruby
Rails.logger.info "[ActionCable][auth-probe] " \
  "warden=#{env['warden'].present?} " \
  "warden_user=#{env['warden']&.user&.email.inspect} " \
  "session_user_id=#{(session['warden.user.user.key'] rescue nil).inspect} " \
  "first_user=#{User.first&.email.inspect}"
```

> Achtung: `ActionCable.server.config.logger = Logger.new(nil)` in
> `config/initializers/action_cable.rb` betrifft nur den **Cable-eigenen** Logger.
> `Rails.logger` oben ist davon nicht betroffen — die Probe schreibt also wirklich.
> Vor dem Auswerten dennoch verifizieren, dass Zeilen ankommen.

1–2 Tage laufen lassen, **inklusive** je einer Scoreboard-Session, einer Reflex-Nutzung
(Turnier-/Party-Monitor) und einer Streaming-Overlay-Session. Dann:

```bash
grep "auth-probe" log/production.log | sort -u | head -50
```

**Entscheidungsregel:**
- `warden_user` durchgehend gesetzt und plausibel → Rückbau ist sicher, weiter mit Schritt 1.
- `warden=true`, aber `warden_user=nil` → H2/H3: erst Session-Transport klären, **nicht** umstellen.
- `warden=false` → H1: Warden läuft für `/cable` nicht; dann ist der Cookie-basierte
  Devise-Weg nötig (siehe Variante B).

**Ergebnis hier eintragen:** _______________

### Variante B — falls `env["warden"]` nicht verfügbar ist

Cookie-basiert, ohne Warden-Middleware:

```ruby
def find_verified_user
  user_id = cookies.encrypted["_carambus_api_session"]&.dig("warden.user.user.key", 0, 0)
  User.find_by(id: user_id) || reject_unauthorized_connection
end
```

Der exakte Cookie-Name und die Key-Struktur sind **aus Probe P1 abzuleiten**, nicht zu
raten — sie hängen vom tatsächlichen Session-Store (H3) ab. Bei Redis-Session-Store
enthält das Cookie nur die Session-ID; dann muss über den Store aufgelöst werden.

---

## 5. Umsetzung

Erst nach P1 mit eindeutigem Ergebnis.

### Schritt 1 — Rückbau

`app/channels/application_cable/connection.rb`:

```ruby
def find_verified_user
  # Devise/Warden-Standard. NICHT durch User.first ersetzen (siehe c1e473cb, 2025-02-25):
  # das authentifiziert jede Verbindung als ersten User der Tabelle.
  # Scoreboards sind hier regulaer angemeldet — locations_controller.rb ruft
  # bypass_sign_in(User.scoreboard) auf und legt damit eine echte Session an.
  env["warden"]&.user || reject_unauthorized_connection
end
```

Der `&.` ist bewusst gesetzt: ohne ihn wirft ein fehlendes `env["warden"]` (H1) einen
`NoMethodError` statt sauber abzulehnen.

**verify:** `bin/rails test test/channels/` grün.

### Schritt 2 — Regressions-Test

Neu bzw. Ergänzung in `test/channels/application_cable/connection_test.rb`
(dieselbe Datei nutzt auch der Origin-Task).

```ruby
# frozen_string_literal: true

require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  # Regression zu c1e473cb: find_verified_user gab "User.first" zurueck und hat damit
  # jede WebSocket-Verbindung als ersten User der Tabelle authentifiziert.
  test "weist verbindung ohne angemeldeten user ab" do
    assert_reject_connection { connect }
  end

  test "uebernimmt den angemeldeten user aus der session" do
    user = users(:some_user)   # Fixture-Namen an test/fixtures/users.yml anpassen
    connect env: { "warden" => FakeWarden.new(user) }
    assert_equal user.id, connection.current_user.id
  end

  class FakeWarden
    def initialize(user) = @user = user
    attr_reader :user
  end
end
```

> **Nicht ausgeführt.** Beim Umsetzen validieren. Bekannte Stolpersteine:
> (1) `ActionCable::Connection::TestCase` erlaubt `connect env: {...}` — ob sich
> `"warden"` so durchreichen lässt, ist zu prüfen; sonst `stub_connection` verwenden
> oder `env["warden"]` in eine überschreibbare Methode kapseln.
> (2) `test/fixtures/users.yml` auf vorhandene Fixture-Namen prüfen.
> (3) `User.scoreboard` gibt in der Test-Env **absichtlich `nil`** zurück
> (`user.rb:85`) — ein Test gegen den echten Scoreboard-User funktioniert dort nicht.

**verify:** Test grün — **und** gegen den alten Stand (`User.first`) laufen lassen:
Test 1 muss dann **fehlschlagen**, sonst prüft er nichts.

### Schritt 3 — Rollout

1. Lokal: Scoreboard-Seite öffnen → WS-Status 101, kein Reconnect-Loop, Anzeige aktualisiert
   sich bei Punkteingabe.
2. Reflex-Pfad testen: Turnier-Monitor + Party-Monitor bedienen (die laufen über dieselbe
   Connection).
3. Staging deployen, dann Prod nach Freigabe.
4. Nach Rollout: `grep -c "An unauthorized connection attempt was rejected" log/production.log`
   → Treffer sind legitime Anonym-Zugriffe **oder** ein gebrochener Scoreboard. Unterscheiden!

**verify (Definition of Done):**
- [ ] P1 dokumentiert, Entscheidungsregel angewandt
- [ ] `User.first` aus `find_verified_user` entfernt
- [ ] Test grün, schlägt gegen alten Stand fehl
- [ ] Scoreboard + Reflexes auf Staging funktionsfähig
- [ ] Prod 24 h ohne unerwartete Rejects

### Rollback
Eine Methode zurücksetzen, Deploy. Kein Datenbank-/Migrationsanteil.

---

## 6. Nebenbefunde (nicht Teil dieses Tasks)

**Hartcodiertes Passwort im deaktivierten Initializer**
`config/initializers/create_scoreboard_user.rb.disabled` enthält
`user.password = "scoreboard123"`. Datei ist inaktiv (`.disabled`), das Passwort steht aber
im Repo. `lib/tasks/installation.rake:145` nennt zusätzlich `scoreboard@carambus.de / scoreboard`.
→ Prüfen, ob auf produktiven Instanzen ein solches Default-Passwort aktiv ist; ggf. rotieren.
Da der Account per `bypass_sign_in` genutzt wird, braucht er möglicherweise gar kein
nutzbares Passwort.

**Session-Store nur für Development konfiguriert**
`config/environments/development.rb:4` setzt `:redis_session_store`;
`config/initializers/session_store.rb` ist vollständig auskommentiert, für Production ist
nichts gesetzt. Dev und Prod nutzen damit vermutlich unterschiedliche Session-Stores (H3) —
das erklärt möglicherweise das ursprüngliche Warden-Problem und sollte unabhängig geklärt werden.
