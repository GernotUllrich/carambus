# Scoreboard: add_n/minus_n ohne Wirkung — reaktivierter Admin-Guard

**Erfasst:** 2026-08-17 · **Status:** diagnostiziert, Fix offen
**Dringlichkeit:** hoch — betrifft den laufenden Turnier-/Trainingsbetrieb an den Tischen
**Zuständig:** carambus_nbv (TableMonitorReflex ist lokale Entität, `ApiProtector`)

## Symptom

An einigen Scoreboards zeigen die `add_n`/`minus_n`-Knöpfe der unteren Zeile **keine
Wirkung**. Numpad und Protokoll arbeiten normal. **Nicht auf allen Scoreboards.**

## Ursache (belegt)

[table_monitor_reflex.rb:347](app/reflexes/table_monitor_reflex.rb) (`minus_n`) und
[:457](app/reflexes/table_monitor_reflex.rb) (`add_n`) tragen als **einzige von 58
Actions** diesen Guard:

```ruby
if remote_request? && !current_user&.admin?
  Rails.logger.warn "🚫 Blocked add_#{n} from remote IP #{request.remote_ip} - Admin required"
  return
end
```

Bis zum 2026-08-14 gab `ApplicationCable::Connection#find_verified_user` pauschal
`User.first` zurück. Auf bc-wedel ist das `id=1 gernot.ullrich@gmx.de` mit **`admin=true`**.
Damit war `!current_user&.admin?` immer `false` — **der Guard war fünf Monate lang toter
Code.**

Der Security-Fix `1efa7995` + `67dfa40f` (auf bcw deployt am 15.08.) macht `current_user`
wahrheitsgemäß. Auf dem Scoreboard ist das jetzt `id=3 scoreboard@carambus.de` mit
**`admin=false`** (per `bypass_sign_in`, [locations_controller.rb:633](app/controllers/locations_controller.rb)).
**Der Guard greift damit erstmals überhaupt.**

### Beleg — bc-wedel `production.log`

| Datei | Zeitraum | Blockaden |
|---|---|---|
| `production.log.2.gz` | 21.03. – 15.08. | **0** |
| `production.log.1.gz` | ab 15.08. | 4 |
| `production.log` | ab 16.08. | **131** |

Alle 131 von IP `91.35.205.240` = öffentliche IP des Vereins.
Verteilung: `add_4` 36× · `add_10` 26× · `minus_1` 18× · `add_1` 15× · `add_2` 13× ·
`minus_2` 12× · `add_5` 8× · `minus_10` 3×.

### Warum nicht überall

[table_monitor_reflex.rb:1036-1041](app/reflexes/table_monitor_reflex.rb):

```ruby
!['127.0.0.1', '::1', 'localhost'].include?(remote_ip) && !remote_ip.start_with?('192.168.')
```

Bei bc-wedel kommen die Scoreboards mit der **öffentlichen** Vereins-IP an, nicht mit
`192.168.x` — sie erreichen den Pi über `bc-wedel.duckdns.org` (NAT-Hairpin). nginx reicht
die echte Client-IP korrekt durch (`X-Real-IP`, `X-Forwarded-For` gesetzt), es ist also
**kein Proxy-Fehler**. Wo Scoreboards direkt über die LAN-Adresse gehen, ist
`remote_request?` false und die Knöpfe funktionieren.

## Was NICHT zu tun ist

**Den ActionCable-Fix nicht zurückrollen.** Vorher trug jede WebSocket-Verbindung
Admin-Identität — das war die eigentliche Lücke. Anonyme Verbindungen müssen außerdem
erlaubt bleiben (`current_user = nil`, Variante C): die erste Fassung wies sie ab und legte
damit die Live-Suche in Produktion lahm.

## Vorschlag

`admin?` war nie die richtige Schwelle — sie hat nur nie gegriffen. Wer scoren darf, ist der
**Scoreboard-User** selbst. Ein Guard auf `current_user.present?` statt `admin?` ist immer
noch **strenger als der Zustand vor dem 14.08.** (damals: jede Verbindung = Admin) und
stellt die Funktion sofort wieder her.

Inhaltlich ist das `.planning/tasks/TASK-scoreboard-write-authorization.md`: die IP-Prüfung
ist ein halbfertiger Vorgriff auf das Topologie-Modell (Raspi mit fester IP ↔ Tisch) und
passt nicht zur Realität, weil der Verein über seinen eigenen öffentlichen Hostnamen
einsteigt. Betreiber-Vorgabe dort: LAN-Gerät nur nach Einwilligung, außerhalb LAN nie
schreiben. Ein reiner IP-Präfix-Test bildet das nicht ab.

Zwei Punkte, die beim Bauen zählen:

- Der Guard sitzt auf genau **2 von 58** Actions. Entweder gehört er auf alle schreibenden
  oder auf keine — der jetzige Zustand ist willkürlich und war nur deshalb unauffällig,
  weil er nie feuerte.
- Er **schweigt nach außen** (`return` ohne Rückmeldung). Genau deshalb sah es am
  Scoreboard aus wie ein toter Knopf. Was auch immer blockt, sollte dem Bediener etwas
  anzeigen.

## Sofortmaßnahme ohne Deploy — Scoreboards auf die LAN-Adresse umstellen

Die Scoreboards sind **eigene Raspberry Pis**, per WLAN mit dem carambus_bcw-Server
verbunden. Sie erreichen den Server offenbar über `bc-wedel.duckdns.org`; der Router
schickt das per NAT-Hairpin zurück ins LAN und ersetzt dabei die Quelladresse durch die
öffentliche IP — daher die 131 Blockaden von `91.35.205.240`.

**Topologie (erhoben 2026-08-17, read-only):**

| | |
|---|---|
| Server (carambus_bcw) | `192.168.2.210`, Interface `eth0` (verkabelt) |
| nginx | `listen 3131`, `server_name bc-wedel.duckdns.org` |
| vermutete Scoreboard-Pis | `192.168.2.222` – `.227` im ARP-Cache, gleiches MAC-Präfix `cc:32:e5:` |
| öffentliche IP des Vereins | `91.35.205.240` |

**Server liefert unter der LAN-Adresse aus — geprüft:**
`http://192.168.2.210:3131/` mit Browser-User-Agent → **HTTP 200**.
(Mit curl-Default-UA kommt **403** — das ist der nginx-Bot-Block, kein
Erreichbarkeitsproblem. Beim Nachprüfen `-A "Mozilla/5.0"` setzen.)

**Umzustellende URL auf jedem Scoreboard-Pi:**

```
http://192.168.2.210:3131/locations/0819bf0d7893e629200c20497ef9cfff/scoreboard?sb_state=table_scores&locale=de
```

Damit sieht Rails `remote_ip = 192.168.2.x`, `remote_request?` ist false, der Guard greift
nicht — ohne Deploy und ohne Codeänderung. Nebenwirkung: der Verkehr bleibt im LAN statt
über den Router hinaus und zurück zu laufen, und er hängt nicht mehr davon ab, ob DynDNS
gerade stimmt.

**Wo die URL steht — Vorsicht, zwei Fallstricke:**

1. `/var/www/carambus_bcw/shared/config/scoreboard_url` auf dem **Server** enthält
   `http://localhost:3131/locations/0819…/scoreboard?…`. Das gilt für ein Scoreboard, das
   *auf dem Server selbst* im Kiosk läuft — für die abgesetzten Pis ist `localhost` falsch.
   Deren URL steht auf ihnen, nicht hier.
2. [bin/autostart-scoreboard.sh](bin/autostart-scoreboard.sh) verdrahtet als Fallback
   `http://192.168.178.107:82/…` bzw. `:3131` — ein **anderes Subnetz** als das heutige
   `192.168.2.x`. Diese Adressen sind veraltet und führen beim Umstellen in die Irre.

**Ungeprüft (Pis waren beim Erheben abgeschaltet):** ob die Scoreboards über `http` statt
`https` sauber laufen. Der Kandidat für Ärger ist dabei nicht die Seite, sondern die
ActionCable-Verbindung auf derselben Origin — beim ersten Einschalten kurz kontrollieren.

## Abgrenzung

Die URL-Umstellung **umgeht** den Guard, sie repariert ihn nicht. Er sitzt weiterhin auf
2 von 58 Actions und schweigt, wenn er blockt. Der Codefix in carambus_nbv bleibt das Ziel.
