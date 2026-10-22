# Eingriffe im laufenden Turnier

> Stand: 2026-10-18. Entstanden aus dem 23. DBU Grand Prix Biathlon (17./18.10.2026,
> 19 Starter, Plan `Biathlon-GP 19`), bei dem Paarungen, Tischzuordnung und Anzeige
> mitten im Betrieb geändert werden mussten.
>
> Gegenstand sind Eingriffe, für die die Oberfläche keinen Weg anbietet. Alles, was
> über die normale Bedienung geht, gehört nicht hierher.
>
> Code-Verweise zeigen auf `tournament_app/schemes/plan/index.html` (Plan-Schema) und
> auf `app/` dieses Repos; Zeilennummern sind Stand Oktober 2026 und driften.
>
> Für Turnierleiter ist [Turnier-App](../managers/tournament-app.md) die erste Adresse,
> insbesondere der Abschnitt „Wenn etwas schiefgeht". Hier stehen die Eingriffe darunter —
> die, für die es keinen Knopf gibt.

## Warum solche Eingriffe überhaupt tragen

Drei Eigenschaften machen den Unterschied zwischen einem chirurgischen Eingriff und
einem Blindflug. Wer sie kennt, kann abschätzen, was ein Eingriff anfasst.

**1. Der Plan ist im Zustand eingefroren, nicht berechnet.**
`state.executorParams` wird einmal gesetzt — beim Attach aus dem Server-Payload, oder
beim Turnierstart aus dem Generator (`biathlonGpPlan` im GP-Modus, aufgerufen allein in
`startTournament`). Danach liest `rebuildRun()` nur noch. Eine Änderung daran überlebt
also jeden Reload. Umgekehrt heißt das: Ein **erneutes Attach überschreibt sie**.

**2. `rebuildRun()` ist deterministisch und speichert keine Spieler.**
Persistiert wird je Partie nur `{key, res, winner}` in `state.records`. Beim Laden parst
die App den Plan neu, verteilt die Teilnehmer und spielt die Ergebnisse per
`recordResult` ein — die Teilnehmer jeder Partie werden dabei **frisch aufgelöst**.
Daraus folgt die zentrale Regel:

> Eine geänderte Referenz wirkt rückwirkend. Hat die Partie schon ein Ergebnis, wird
> dieses Ergebnis den **neuen** Spielern zugeschrieben.

**3. Die Ergebniszuordnung hängt an der `external_id`, nicht am Tisch.**
`acknowledgeResult` sucht das Spiel über `find_game`, und das iteriert über alle an den
TournamentMonitor **gebundenen** TableMonitors — ohne festgelegte Reihenfolge
(`acknowledge_result_processor.rb`). Zwei Tische mit derselben `external_id` sind
deshalb kein kosmetisches Problem, sondern ein Münzwurf darüber, welches Ergebnis
zurückkommt.

## Vor jedem Eingriff

1. **Sicherung ziehen** („💾 Sicherung speichern") und wegspeichern. Das ist der Rückweg.
2. **Vorbedingung prüfen** — welche, steht beim jeweiligen Eingriff unten.
3. **Konsole statt Restore**, wo eine Konsole da ist. Der Konsolenweg ändert genau ein
   Feld; das Einspielen einer Sicherung überschreibt den **ganzen** Zustand und verliert
   alles, was seit dem Ziehen dazugekommen ist.

Chrome sperrt das Einfügen in die DevTools-Konsole („Don't paste code you don't
understand"). Entweder einmal `allow pasting` tippen, oder den Eingriff in abtippbare
Einzelschritte zerlegen — das ist ohnehin die bessere Übung, weil man nach jedem Schritt
das Zwischenergebnis sieht.

Der Instanz-Schlüssel ist `carambus.instance.<id>`; die `<id>` steht in der Adresszeile
des Turniers (`?t=…`) und in jeder Sicherung unter `instance.id`.

## Paarungen einer Runde ändern

Der Hebel ist `state.executorParams`. Geändert werden nur die Referenzen **innerhalb**
der betroffenen Spiele; die Schlüssel bleiben, sonst verlieren die bereits erfassten
Ergebnisse ihren Bezug.

```js
s=JSON.parse(localStorage["carambus.instance.<id>"])
p=JSON.parse(s.executorParams)
p.<spiel>.r<runde>["<tisch-token>"]=["<refA>","<refB>"]
s.executorParams=JSON.stringify(p); localStorage["carambus.instance.<id>"]=JSON.stringify(s); location.reload()
```

### Die Vorbedingung hängt von der Art der Referenz ab

Das ist der Punkt, an dem man sich vertun kann — sie ist **nicht** für jede Runde
dieselbe.

| Geänderte Referenz | Beispiel | Verboten sind Ergebnisse … |
|---|---|---|
| Gruppenplatz (`g<N>.rk<n>`) | Viertelfinale neu verdrahten | … in **irgendeinem** KO-Spiel |
| Setzlisten-Platz (`ks.rk<n>`) | dito | … in **irgendeinem** KO-Spiel |
| Spielausgang (`<spiel>.rk1`) | Halbfinale neu verdrahten | … nur im **geänderten** Spiel und danach |

Der Grund: `g1.rk1` wird aus der Gruppentabelle aufgelöst, `qf1.rk1` dagegen aus
`run.results["qf1"]`. Ein vorhandenes Viertelfinal-Ergebnis stört die Halbfinal-Änderung
also nicht — es ist sogar ihre Voraussetzung. Eine Änderung an den Viertelfinals selbst
würde dasselbe Ergebnis dagegen anderen Spielern zuschreiben.

Prüfzeile, auf die jeweils verbotene Menge angepasst:

```js
[...s.records.map(r=>r.key),...Object.keys(s.gameUI)].filter(x=>/^(hf1|hf2|fin)$/.test(x))
```

Muss `[]` ergeben. `gameUI` gehört mit in die Prüfung: Dort stehen die **gestarteten**
Spiele, die noch kein Ergebnis haben — auch die dürfen nicht umverdrahtet werden.

### Nach der Änderung gegenprüfen

- Gruppentabellen und Spielzähler unverändert
- die betroffene Runde zeigt die erwarteten Namen
- so viele verschiedene Spieler wie Startplätze

Wer es vorher wissen will: `schemes/plan/plan-engine.test.mjs` zeigt, wie sich die
Engine aus der HTML extrahieren und unter Node gegen eine Sicherung laufen lässt. Damit
lassen sich die resultierenden Paarungen mit Klarnamen ausgeben, bevor irgendetwas am
Gerät passiert.

## Tische

### „Tisch zuordnen" ist der Spielstart

Die Oberfläche kennt keinen reinen Tischvermerk. Der Knopf schickt bei bestehender
Verbindung `startGame` an Carambus — mit beiden Spielern und dem Tischnamen — und setzt
`state.gameUI[key]` erst, wenn das durchging. Und es gibt **keinen Weg zurück**:
`delete state.gameUI[key]` steht allein in `completeGame`, also hinter der
Ergebniserfassung.

### Einen Tisch wechseln

**Offline** genügt es, den Namen umzuhängen. Beide Schlüssel **vor** dem Zuweisen
bestimmen, sonst stehen kurzzeitig zwei Spiele auf demselben Tisch und der zweite
Suchlauf greift daneben:

```js
u=s.gameUI; a=Object.keys(u).find(k=>u[k].table==="Tisch 1"); b=Object.keys(u).find(k=>u[k].table==="Tisch 2")
u[a].table="Tisch 2"; u[b].table="Tisch 4"
```

**Live** reicht das nicht: Carambus führte das Spiel weiter auf dem alten Tisch, und
weil `find_game` nur über die `external_id` sucht, läge dieselbe Kennung auf zwei
Tischen. Dann gibt es zwei Wege:

- **Das Scoreboard mitnehmen.** Am physischen Tisch 2 das Carambus-Scoreboard von
  „Tisch 1" aufrufen. Nichts zu ändern, weder am Server noch am Zustand. Einziger
  Nebeneffekt: Im Ergebnisarchiv steht der alte Tischname, weil `completeGame` beim
  Erfassen `table: state.gameUI[key]?.table` mitschreibt. Kosmetisch, nachträglich
  korrigierbar.
- **Lösen und neu starten.** Erst in Carambus den alten Tisch abräumen, dann
  `delete state.gameUI.<key>`, dann über die Oberfläche auf dem richtigen Tisch starten.
  Reihenfolge einhalten — sonst liegt die `external_id` doppelt.

### Was „Partie abbrechen" nicht kann

Der naheliegende Weg, einen Tisch in Carambus abzuräumen, versagt bei App-Spielen
**stillschweigend**:

```ruby
def external_result_pending?
  d["external_id"].to_s.present? && g.result_acknowledged_at.nil?
end
```

Solange ein App-Spiel läuft und sein Ergebnis nicht abgeholt ist, ist das wahr — und der
Controller überspringt Terminate dann vollständig, ohne Rückmeldung
(`locations_controller.rb`, Zweig `terminate_game_id`). Derselbe Guard blockiert
`close_match` über `external_release_allowed?`. Man klickt, nichts passiert, nur das Log
weiß davon.

Ein gestartetes, noch nicht beendetes App-Spiel lässt sich daher **nur** mit
`reset_table_monitor(force: true)` vom Tisch lösen — oder gar nicht.

### Einen Tisch wirklich frei bekommen

Nach dem Abholen des Ergebnisses feuert `acknowledgeResult` zwar `close_match!`, aber
das **lässt `game_id` stehen**. Der Tisch gilt weiter als belegt. Erst
`reset_table_monitor` setzt beides zurück:

```ruby
assign_attributes(tournament_monitor: nil, game_id: nil, nnn: nil, panel_state: "pointer_mode", data: {})
```

Es löscht das Spiel dabei **nicht** — die Ergebnisse bleiben.

```ruby
Table.where(location_id: <loc>).find_by(name: "Tisch 4").table_monitor.reset_table_monitor(force: true)
```

### Einen Tisch nur vom Turnier lösen

**Seit Plan 28-02 gibt es dafür einen Knopf:** In der Tisch-Leiste („Spiele & Gruppen")
trägt jeder freie Tisch ein **✕**; ein gelöster Tisch bleibt gedimmt als „gelöst" in der
Leiste und kommt mit **⟲ einbinden** einzeln zurück (`releaseTable` / `bindTable`,
Zustand `state.releasedTables`). Die App stellt `state.tables` erst nach der
Serverbestätigung um. Der Konsolenweg unten bleibt als Rückfallebene.

Der Server schützt das Lösen selbst: `lock_table` mit `lock: false` auf einen Tisch, dessen
App-Ergebnis noch nicht abgeholt ist (`external_result_pending?`), antwortet **409**
`table_in_use` mit `game` und `detail` und ändert nichts. `force: true` umgeht das — nur für
ein tatsächlich aufgegebenes Spiel.

Wenn es allein um die Turnierzugehörigkeit geht (Anzeige, Freigabe für den
Vereinsbetrieb), genügt der Teil-Release — aus der App heraus, ohne Serverzugriff:

```js
await Carambus.api.lockTable({...tournamentApiRef(), tableName:"Tisch 4", tableId:tableIdOf("Tisch 4"), lock:false})
```

Muss `in_tournament: false` melden. Danach **immer** `state.tables` nachziehen:

```js
state.tables = state.tables.filter(n => n!=="Tisch 4"); save(); renderAll()
```

Ohne diesen Schritt bietet die App den Tisch weiter zur Auswahl an, und der nächste
Start läuft in `TableNotBoundError`.

Umgekehrt bindet „Tische neu binden" (oder `lockTable` mit `lock: true`) die Tische aus
`state.tables` wieder an — gebaut für den Fall nach einer Sicherung, fasst `state.records`
nicht an.

> **Reihenfolge:** Erst das Ergebnis in die App holen, dann entbinden. Ein entbundener
> Tisch ist für `find_game` unsichtbar; das Ergebnis wäre nicht mehr abrufbar.
> Seit 28-02 verweigert der Server das Entbinden in diesem Fall (409), außer mit `force: true`.

## Die Turnierübersicht `?sb_state=tournament_scores`

Die Ansicht bemisst ihr Raster an einer **anderen** Menge, als sie anzeigt:

```erb
table_monitors = tournament.tournament_monitor.table_monitors.to_a   # ALLE gebundenen
cols = { 1 => 1, 2 => 2, 3 => 3, 4 => 4, … }[table_monitors.count] || 3
<turbo-frame class="grid grid-cols-<%= cols %> text-<%= cols < 4 ? "3" : "2" %>vw">
  monitors.joins(:game)…                                             # nur MIT Spiel
```

Daraus folgen zwei Dinge:

- **Kacheln verschwinden durch Entbinden**, nicht durch das Spielende. Ein beendetes
  Spiel behält seine `game_id` und bleibt sichtbar, bis der Tisch gelöst oder
  zurückgesetzt wird.
- **Weniger gebundene Tische heißt größere Darstellung.** Unter vier Tischen kippt der
  Ternär zusätzlich von `text-2vw` auf `text-3vw`. Wer am Saalmonitor nur die laufenden
  Partien groß sehen will, löst die ungenutzten Tische.

Dass die Zählung über alle gebundenen statt über die gezeigten Tische läuft, ist als
Fehler erfasst: `HANDOFF-to-carambus-tournament-scores-raster.md`.

## Nach einem versehentlichen Abräumen

`POST end_tournament` (in der App der Knopf „Abräumen") gibt alle Tische frei und
schließt den TournamentMonitor. Die Signatur im Nachhinein: `monitor=closed`,
`gebunden: []`, und die zuletzt gestarteten Spiele sind leere Hüllen — `data` enthält nur
`external_id`, `round_no`, `warmup_minutes`, kein `tmp_results`.

**Der App-Zustand bleibt dabei unangetastet**, solange es nicht der Knopf „Turnier
verwerfen" war (der leert zusätzlich `state.records`). Carambus ist hier nur Spiegel; die
Wiederherstellung ist entsprechend simpel:

1. `state.tables` auf die gewünschten Tische setzen
2. `delete state.gameUI.<key>` für die Spiele, die neu gestartet werden sollen
3. Tische binden („Tische neu binden")
4. Spiele normal über die Oberfläche starten

Der geschlossene Monitor stört nicht: Weder `StartGameProcessor` noch `TableLocker` noch
`AcknowledgeResultProcessor` prüfen seinen Zustand. Gebunden sein muss der Tisch, mehr
nicht.

Die herrenlosen Spielhüllen dürfen liegen bleiben — `find_game` sucht nur über gebundene
TableMonitors und findet sie nie. Sauberer ist es trotzdem, sie zu löschen, damit die
`external_id` nicht doppelt in der Datenbank steht.

## Was still fehlschlägt

Eine Liste der Stellen, an denen ein Eingriff wirkungslos bleibt, **ohne** eine
Fehlermeldung zu erzeugen. Alle sind in dieser Form beobachtet worden.

| Eingriff | Bedingung | Symptom |
|---|---|---|
| „Partie abbrechen" / `close_match` | `external_result_pending?` | nichts passiert, nur ein Log-Eintrag |
| `reset_table_monitor` ohne `force` | dieselbe | Rückgabe ohne Aktion |
| Save eines Stammdatensatzes auf einem Location-/Region-Server | `id < 50_000_000` | `ActiveRecord::Rollback` in einem `after_save`, Änderung verschwindet |
| Tisch entbunden, Ergebnis noch nicht geholt | nur noch mit `force: true` (seit 28-02 sonst 409) | `acknowledgeResult` findet das Spiel nicht mehr |
| Dieselbe `external_id` auf zwei Tischen | — | zufällig das falsche Ergebnis |
| Paarung geändert, Spiel hatte schon ein Ergebnis | — | Ergebnis wird den neuen Spielern zugeschrieben |

Der dritte Fall trifft auch Korrekturen an Stammdaten, die man unterwegs machen will —
etwa einem Spieler seinen Verein zuzuordnen, damit das Wappen erscheint. `player_locals`
hilft dort nicht, die Tabelle führt nur E-Mail, PIN und Einwilligung. Solche Korrekturen
gehören auf die Authority und kommen per Sync zurück.

## Verwandte Dokumente

- [Turnier-App](../managers/tournament-app.md) — Anleitung für Turnierleiter, mit dem
  Abschnitt „Wenn etwas schiefgeht" für alles, was über die Oberfläche geht
- [External Tournament Bridge](external-tournament-bridge.md) — die Endpunkte, über die
  App und Carambus sprechen (`lock_table`, `start_game`, `acknowledge_result`, …)
- [Fallstricke](fallstricke.md) — die repoweite Sammlung still zuschlagender Lehren;
  die Tabelle am Ende dieses Dokuments ist ihr app-seitiges Gegenstück

Die App bringt eigene Entwicklerdoku mit, nicht Teil dieser mkdocs-Site:
`tournament_app/docs/ARCHITECTURE.md` (Aufbau, Instanzen, `shared/`-Kern),
`tournament-plan-executor.md` (die `executor_params`-DSL mit Referenzformen und
Ranking-Regeln) und `json-schema.md` (die Endpunkte im Detail).
