# TASK: Schreibzugriff auf Scoreboards nach Netz-Topologie autorisieren

**Erstellt:** 2026-08-14 · **Status:** offen, nicht begonnen
**Herkunft:** Betreiber-Vorgabe im Anschluss an die Durchsicht von `c1e473cb`
**Einordnung:** Das Modell ist **topologiebasiert**, nicht rollenbasiert — ein
`admin?`-Gate wäre hier der falsche Hebel.

---

## 1. Ausgangslage

Reflexes sind über ActionCable erreichbar; anonyme Verbindungen sind seit `67dfa40f`
(Variante C) ausdrücklich zugelassen. Schreibende Reflexes prüfen heute **nichts**:

| Reflex | Gates | Schreibops |
|---|---|---|
| `table_monitor_reflex.rb` | **0** (die 2 `remote_request?`-Gates 2026-08-17 entfernt, s. Abschnitt 7) | 46 |
| `game_protocol_reflex.rb` | **0** | **15** (`increment_points`, `delete_inning`, `confirm_result`, …) |
| `party_monitor_reflex.rb` | 2 | 10 |
| `tournament_reflex.rb` | **0** | 7 |

Historisch war es **nicht besser**: Vor `1efa7995` trug jede Verbindung die Identität von
`User.first`. Variante C hat die Identität ehrlich gemacht, die Autorisierung aber nicht
berührt.

## 2. Fachliches Zielmodell (Betreiber-Vorgabe)

Scoreboards laufen normalerweise auf einem **Raspberry Pi mit fester IP**, der einem
**bestimmten Tisch** zugeordnet ist. Diese Zuordnung wird bereits anderweitig genutzt,
u. a. für die **Tischheizungs-Steuerung** — die Verknüpfung IP ↔ Tisch existiert also
schon und ist keine neue Erfindung.

Daraus die gewünschten Stufen:

| Herkunft der Verbindung | Schreiben | Verhalten |
|---|---|---|
| Zugeordneter Raspi (bekannte IP ↔ Tisch) | ✅ | Normalfall, ohne Rückfrage |
| Anderes Gerät im selben LAN (z. B. Handy eines Spielers) | ✅ | **Erst nach Warnung und expliziter Einwilligung** — soll Fehlbedienung verhindern, nicht den Zugriff |
| Raspi, der einem **anderen** Tisch zugeordnet ist | ⚠️ | Meist ein Bedienfehler. Nur bewusst erlauben (Ausfall eines Raspi), also mit deutlicher Warnung |
| Außerhalb des LAN | ❌ | **Nie schreiben.** Von dort ausschließlich lesender Zugriff |

**Kernsatz:** „Eingabe an das Scoreboard außerhalb des LAN ist immer unerwünscht."

## 3. Konsequenzen für die Umsetzung

- Der Träger der Entscheidung ist die **Client-IP** (bzw. das Netz), nicht die User-Rolle.
  `current_user&.admin?` ist hier untauglich — Scoreboards werden bewusst ohne Login
  bedient (`LocationsController#show` → `bypass_sign_in(User.scoreboard)`, Rolle `player`).
- Die Prüfung gehört auf den **schreibenden** Pfad (Reflexes), nicht auf den lesenden.
  Zuschauen von außerhalb bleibt erlaubt und erwünscht.
- Hinter einem Reverse Proxy muss die echte Client-IP verfügbar sein
  (`X-Forwarded-For`/`remote_ip`, Proxy als vertrauenswürdig konfiguriert). Sonst sieht die
  App nur den Proxy und das Modell kollabiert auf „alles ist LAN" oder „nichts ist LAN".
  **Das ist der erste zu prüfende Punkt** — ohne verlässliche Client-IP trägt der Rest nicht.
- Die zweistufige Variante („Warnung + Einwilligung") ist UI-Arbeit, kein reines Gate: Der
  Zustand der Einwilligung muss pro Verbindung/Session gehalten werden.

## 3a. Geltungsbereich (Betreiber, 2026-08-14)

Das Topologie-Modell gilt **ausschließlich für die Tisch- und Protokoll-Pfade**:

| Reflex | im Modell | Schreibops |
|---|---|---|
| `table_monitor_reflex.rb` | ✅ | 46 |
| `game_protocol_reflex.rb` | ✅ | 15 |
| `party_monitor_reflex.rb` | ❌ | 10 (hat bereits 2 `admin?`-Gates) |
| `tournament_reflex.rb` | ❌ | 7 |

Das ist der fachlich richtige Schnitt: Nur an diesen beiden hängt ein **physisches Gerät am
Tisch**, dessen Standort überhaupt eine Aussage trägt. Turnier- und Party-Verwaltung
passiert nicht am Scoreboard, sondern durch Turnierleitung — dort ist die Netz-Herkunft
kein sinnvolles Kriterium.

> **Randnotiz, nicht Teil dieses Tasks:** `TournamentReflex` hat damit weder ein
> Rollen-Gate (0) noch fällt es unter das Topologie-Modell. Ob seine 7 Schreibpfade auf
> anderem Weg abgesichert sind, ist eine eigene, hier bewusst **nicht** verfolgte Frage.

## 4. Offene Fragen vor dem Entwurf

1. **Wo liegt die IP↔Tisch-Zuordnung heute?** Die Tischheizungs-Steuerung nutzt sie
   bereits — die vorhandene Quelle wiederverwenden statt eine zweite Wahrheit zu schaffen.
2. **Wie wird „im LAN" bestimmt?** Private Netzbereiche (RFC 1918), eine konfigurierte
   Liste je Location, oder der Abgleich mit dem Netz des Servers?
3. **Wie verhält sich das bei Cloud-Instanzen?** Siehe Abschnitt 5 — dort gibt es keine
   physischen Scoreboards, das Modell müsste dort entweder alles Schreiben verbieten oder
   für Demo-Zwecke bewusst ausnehmen.
4. ~~Gilt dasselbe für `PartyMonitorReflex` und `TournamentReflex`?~~ — **geklärt
   (Betreiber, 2026-08-14): nur die Tisch- und Protokoll-Pfade.** Siehe Abschnitt 3a.

## 5. ⚠️ Cloud-Instanzen haben keine echten Scoreboards

Betreiber-Klarstellung: *„nbv.carambus.de ist bzgl. der Scoreboards eigentlich Unsinn — per
definitionem kann in der Cloud kein physikalisches Scoreboard dranhängen. Das ist nur gut
für Tests und Demo-Zwecke."*

Das hat zwei Folgen:

**(a) Für diesen Task:** Auf Cloud-Instanzen ist „schreibender Scoreboard-Zugriff" ohnehin
kein produktiver Anwendungsfall. Dort wäre die strengste Stufe vertretbar.

**(b) Für die Origin-Härtung:** Die Messung auf `nbv.carambus.de`
(`.planning/tasks/TASK-actioncable-origin-hardening.md`) hat `client=scoreboard`-Zeilen
erfasst — das waren aber **Demo-Aufrufe über die Cloud**, nicht Raspis im Vereins-LAN. Ein
echter Raspi verbindet sich gegen einen **lokalen** Server, typischerweise über eine
LAN-IP (`http://192.168.x.x:3000`) statt über einen Cloud-Hostnamen. Origin/Host sehen dort
anders aus. Der real relevante Fall ist damit **weiterhin ungemessen**.

## 6. Was dieser Task NICHT ist

Es ist ein **Härtungsvorhaben mit klarer fachlicher Zielvorstellung**, kein akuter
Sicherheitsvorfall — der beschriebene Zustand besteht seit Langem und war vor den Änderungen
vom 2026-08-14 nicht besser.

**Korrektur 2026-08-17:** „Kein Grund zur Eile" stand hier ursprünglich unbedingt. Das war
falsch. Nicht das Fehlen der Absicherung hat Kosten verursacht, sondern ihre **halbe**
Umsetzung: zwei von 41 schreibenden Actions blockierten, die übrigen 39 nicht — Ergebnis war
kein Schutz, aber ein Abend Fehlersuche an zwei Tischen. Siehe Abschnitt 7.

---

## 7. Feldbefund 2026-08-17 — die fehlende Messung aus 5(b), unfreiwillig nachgeholt

Abschnitt 5(b) hielt fest, der real relevante Fall — ein echter Raspi im Vereins-LAN — sei
**ungemessen**. Er ist jetzt gemessen, durch einen Betriebsvorfall bei BC Wedel.

### Was passierte

An **bcw6 und bcw7** zeigten die `add_n`/`minus_n`-Knöpfe keine Wirkung. Numpad, Protokoll
und alles Übrige schrieben normal. An bcw1/3/5/8 funktionierte alles.

Ursache: die beiden `remote_request?`-Gates waren fünf Monate lang **toter Code** — vor
`1efa7995` gab ActionCable pauschal `User.first` zurück, auf bcw ein Admin. Seit die
Identität ehrlich ist (`scoreboard@carambus.de`, `admin=false`), griffen sie erstmals.
Vollständige Kette mit Belegen:
`.planning/debug/scoreboard-add-n-blocked-by-admin-guard.md`.

### Die eigentliche Erkenntnis für dieses Modell

**Nicht alle Scoreboards kommen mit einer LAN-IP an.** Aus dem `production.log` von bcw:

| Quelle | Gerät | Requests |
|---|---|---|
| `192.168.2.215` | bcw5 | 99 |
| `192.168.2.218` | bcw8 | 38 |
| `192.168.2.211` | bcw1 | 17 |
| `192.168.2.213` | bcw3 | 15 |
| **`91.35.205.240`** | **bcw6 + bcw7 (öffentliche IP des Vereins)** | **121** |

bcw6 und bcw7 stehen **physisch am Tisch**, rufen den Server aber über
`bc-wedel.duckdns.org` auf. Der Router schickt das per **NAT-Hairpin** zurück ins LAN und
ersetzt dabei die Quelladresse durch die öffentliche IP.

> **Für den Server sind sie von einem entfernten Browser nicht unterscheidbar.**
> Beide melden `91.35.205.240`.

Damit ist Abschnitt 3, Punkt 3 („hinter einem Reverse Proxy muss die echte Client-IP
verfügbar sein") **notwendig, aber nicht hinreichend**. Die Client-IP ist hier korrekt
durchgereicht — nginx setzt `X-Real-IP` und `X-Forwarded-For` sauber. Sie ist trotzdem
wertlos, weil das **Routing** die Herkunft verwischt, nicht der Proxy.

### Daraus folgt eine Voraussetzung, keine Krücke

**Jedes Scoreboard muss den Server über die LAN-Adresse erreichen** (bei bcw:
`http://192.168.2.210:3131/…`). Solange ein legitimes Scoreboard über die öffentliche IP
hereinkommt, gilt:

- eine IP-basierte Umsetzung von „außerhalb des LAN nie schreiben" **sperrt genau die
  Geräte aus, die sie schützen soll** — im Kleinen ist das am 17.08. passiert;
- jede Lockerung, die diese Geräte wieder hereinlässt, lässt zwangsläufig auch echte
  Zugriffe von außen herein.

Es gibt keine dritte Möglichkeit, solange die Unterscheidung allein an der IP hängt. Die
URL-Umstellung ist deshalb **Teil dieses Tasks**, nicht eine Notmaßnahme daneben. Sie
gehört vor die Implementierung, nicht danach — und sie braucht eine Absicherung dagegen,
dass ein neu aufgesetztes Scoreboard wieder mit dem öffentlichen Hostnamen konfiguriert
wird.

### Zwischenmaßnahme am 2026-08-17

Die beiden Gates **entfernt** (nicht repariert). Begründung: sie saßen auf 2 von 41
schreibenden Actions; `key`, `nnn_enter`, `undo`, `redo`, `start_game`, `set_balls`,
`numbers`, `foul` und 31 weitere schreiben ungeprüft. Wer scoren will, nimmt einen der
anderen Wege — die Gates hinderten niemanden, kosteten aber die Bedienbarkeit.

Die Alternative (Schwelle von `admin?` auf `current_user.present?`) hätte die Funktion
ebenfalls hergestellt, aber eine Sperre erhalten, die keine ist — und damit den Eindruck
von Schutz genährt. Der jetzige Zustand ist ehrlich: **null Absicherung schreibender
Zugriffe, dokumentiert hier.**

### Zwei Anschlussbefunde

1. **Dasselbe Muster lebt weiter** in `app/controllers/static_controller.rb:58`
   (`remote_request? && !current_user&.admin?`, gegen `ApplicationController#remote_request?`).
   Nicht geprüft, ob es dort etwas Sinnvolles bewirkt oder derselbe Blindgänger ist.
2. **Stilles Abweisen ist eine eigene Fehlerquelle.** Der Guard endete auf `return` ohne
   Rückmeldung — am Tisch nicht von einem defekten Knopf zu unterscheiden. Was die künftige
   Umsetzung abweist, muss dem Bediener **sichtbar** abgewiesen werden; das ist UI-Arbeit
   und gehört in den Umfang, nicht als Nachgedanke.
