# Handoff an Carambus (Paul): Kachelraster der Turnierübersicht zählt gebundene statt laufende Tische

**Von:** Carambus Turnier-App (Gernot)
**An:** Carambus (Paul-Plugin) — Scoreboard-Views
**Datum:** 2026-10-17
**Status:** Darstellungsfehler. Rein serverseitig (eine View), keine Migration, kein
API-Change, keine App-Änderung. Umsetzung durch Paul.
**Untersuchter Checkout:** `/Users/gullrich/DEV/carambus/carambus_bcw`, HEAD `9943115a`
(2026-10-10). Die betroffene View ist seit `150aa8433` (2025-03-21) unverändert.

---

## Der Fall vom 17.10.2026

Beim **23. DBU Grand Prix Biathlon** (17./18.10.2026, BC Wedel) waren **vier Tische** an das
Turnier gebunden. In den Halbfinals liefen **zwei Partien**. Auf dem Saalmonitor
(`/locations/<id>?sb_state=tournament_scores`) entstand daraus ein **4-Spalten-Raster mit zwei
Kacheln** — jede Kachel auf einem Viertel der Bildschirmbreite, dazu die kleinere Schrift
(`text-2vw` statt `text-3vw`). Für Zuschauer im Saal war der Stand damit kaum lesbar.

Der Betreiber hat sich beholfen, indem er die beiden unbenutzten Tische per
`ExternalTournament::TableLocker` (`lock: false`) vom Turnier gelöst hat. Das wirkt, ist aber
ein Umweg mit Nebenwirkungen: die App führt die Tische in `state.tables` weiter und läuft beim
nächsten Spielstart in `ExternalTournament::StartGameProcessor::TableNotBoundError`
(`app/services/external_tournament/start_game_processor.rb:71`), und nach dem Turnier müssen
sie wieder gebunden werden. Es ist kein Ersatz für den Fix.

---

## Befund

`app/views/locations/scoreboard_tournament_scores.html.erb` holt die Relation **zweimal** und
benutzt für Zählung und Ausgabe **zwei verschiedene Mengen**:

```erb
24  <%- table_monitors = tournament&.tournament_monitor&.table_monitors.to_a.sort_by { |tm| tm.table.name }.reverse %>
25  <%- cols = { 1 => 1, 2 => 2, 3 => 3, 4 => 4, 5 => 4, 6 => 3, 8 => 4, 9 => 3, 10 => 4,
               11 => 4, 12 => 4, 13 => 4, 14 => 4, 15 => 3, 16 => 4, 17 => 4, 18 => 4 }[table_monitors.count] || 3 %>
27  <turbo-frame id="teasers" class="grid grid-cols-<%= cols %> text-<%= cols < 4 ? "3" : "2" %>vw gap-8">
28    <%- monitors = tournament&.tournament_monitor&.table_monitors %>
29    <%- monitors&.joins(:game).to_a.sort_by { |tm| tm.table.name }.reverse.each do |table_monitor| %>
30      <%- table_monitor.get_options!(I18n.locale) %>
31      <turbo_frame id="teaser_<%= table_monitor.id %>">
32        <%= render partial: "table_monitors/teaser", locals: { table_monitor: table_monitor } %>
```

* **Zeile 24/25** zählt **alle gebundenen** TableMonitors → 4.
* **Zeile 29** rendert nur die **mit einem Spiel** (`joins(:game)`) → 2.
* **Zeile 27** hängt beides am selben `cols`: Spaltenzahl *und* Schriftgröße.

Nebenbefunde in denselben Zeilen:

* Das Array aus Zeile 24 wird nach Zeile 25 **nicht mehr verwendet**. `sort_by { |tm| tm.table.name }.reverse`
  lädt dafür je Monitor den `table` nach (N+1) und wirft das Ergebnis weg.
* Zeile 28 holt dieselbe Relation ein zweites Mal — zwei Queries, wo eine genügt.
* Zeile 30 ruft `get_options!` und übergibt das Ergebnis **nicht** an das Partial.
  `app/views/table_monitors/_teaser.html.erb:5-8` prüft `unless local_assigns[:options].present?`
  und ruft `get_options!` deshalb ein **zweites Mal** je Kachel. Der `teaser`-Job macht es
  richtig (`app/jobs/table_monitor_job.rb:119`, `locals: { … options: options_snapshot }`).
  Optionaler Nebenaufräumer, nicht Teil des Fixes.

---

## Entwurfsfrage: springt das Raster bei jedem Spielende?

Das war die Sorge, die gegen den naheliegenden Fix sprechen könnte — ein Raster, das während
eines Rundenwechsels umbricht, wäre auf dem Saalmonitor unruhiger als eines, das zu groß bleibt.

**Geprüft: Diese Sorge trifft hier nicht zu.** Das Grid-Element wird nach dem Seitenaufbau
nie neu gerendert:

* `app/models/table_monitor.rb:163-173` setzt bei Änderungen zwei Jobs in die Queue:
  `"table_scores"` und `"teaser"`.
* Der `"table_scores"`-Job zielt auf den Container `#table_scores` — **den hat diese Seite
  nicht**. Der Kommentar in Zeile 167 sagt das selbst:
  *„Also send teaser for tournament_scores page (which doesn't have #table_scores container)"*.
* Der `"teaser"`-Job macht `cable_ready[...].inner_html(selector: "#teaser_#{id}")`
  (`app/jobs/table_monitor_job.rb:108-127`) — er ersetzt den **Inhalt einer bestehenden
  Kachel**. Existiert `#teaser_<id>` nicht im DOM, verwirft der Client die Nachricht.

Folge: Die Kachelmenge und damit `cols` liegen mit dem Seitenaufbau fest. Ein Spielende
ändert das Raster **nicht**. Neu gezeichnet wird erst bei einem Full Reload, und der passiert
nur bei Monitor-Aufwachen bzw. Verbindungsverlust
(`app/javascript/channels/table_monitor_channel.js:305`, `:403`) oder beim Versions-Check.

**Was als Risiko übrig bleibt**, ist genau dieser Reload: Fällt er mitten in einen
Rundenwechsel (von vier Partien läuft gerade noch eine), ergibt die neue Zählweise
`grid-cols-1` — eine Kachel über die gesamte Bildschirmbreite — und das bleibt so bis zum
nächsten Reload. Dagegen hilft eine Untergrenze (siehe Empfehlung).

### Separater, vorbestehender Fehler — gehört nicht in diesen Fix, aber ihr solltet ihn kennen

Aus derselben Mechanik folgt: **Ein Spiel, das auf einem beim Seitenaufbau leeren Tisch
startet, erscheint auf dieser Seite nie.** Sein `#teaser_<id>` ist nicht im DOM, also hat die
`inner_html`-Nachricht kein Ziel, und kein Job rendert das Grid neu. Das gilt heute schon, mit
und ohne den hier vorgeschlagenen Fix, und ist auch der Grund, warum die zu kleinen Kacheln
vom 17.10. nicht „von selbst" größer wurden. Wenn ihr das angehen wollt, bräuchte der
`"table_scores"`-Job ein zweites Ziel auf dieser Seite (z. B. `#teasers`), das den ganzen
Grid-Frame ersetzt — dann würde allerdings auch das Raster live umbrechen, und die
Entwurfsfrage oben wird echt. Zwei getrennte Entscheidungen; dieser Handoff fragt nur den
Zähl-Fix.

---

## Empfehlung

**Eine Relation, einmal geholt, für Zählung und Ausgabe — plus eine Untergrenze von 2 Spalten,
solange mehr als ein Tisch gebunden ist.** Die Untergrenze kostet nichts und fängt den
Reload-im-Rundenwechsel-Fall ab, ohne das Problem vom 17.10. zurückzuholen (4 gebunden /
2 laufend ergibt weiter 2 Spalten).

```erb
<%- if tournament&.tournament_monitor&.present? %>
  <%- tournament_monitor = tournament.tournament_monitor %>
  <%- # Raster und Schriftgroesse aus der Menge, die danach auch gerendert wird:
      # nur Tische mit laufendem Spiel. Frueher wurden alle gebundenen TableMonitors
      # gezaehlt -- vier gebundene Tische bei zwei Halbfinals ergaben ein 4-Spalten-
      # Raster mit zwei winzigen Kacheln (23. DBU Grand Prix, 17.10.2026).
      # Untergrenze 2 Spalten, damit ein Reload mitten im Rundenwechsel nicht eine
      # einzelne Kachel ueber die ganze Breite zieht. %>
  <%- active_monitors = tournament_monitor.table_monitors.joins(:game).includes(:table)
                                          .to_a.sort_by { |tm| tm.table.name }.reverse %>
  <%- min_cols = [tournament_monitor.table_monitors.count, 2].min %>
  <%- grid_count = [active_monitors.count, min_cols].max %>
  <%- cols = { 1 => 1, 2 => 2, 3 => 3, 4 => 4, 5 => 4, 6 => 3, 8 => 4, 9 => 3, 10 => 4,
               11 => 4, 12 => 4, 13 => 4, 14 => 4, 15 => 3, 16 => 4, 17 => 4, 18 => 4 }[grid_count] || 3 %>
  <turbo-frame id="teasers" class="grid grid-cols-<%= cols %> text-<%= cols < 4 ? "3" : "2" %>vw gap-8">
    <%- active_monitors.each do |table_monitor| %>
      <%- table_monitor.get_options!(I18n.locale) %>
      <turbo_frame id="teaser_<%= table_monitor.id %>">
        <%= render partial: "table_monitors/teaser", locals: { table_monitor: table_monitor } %>
      </turbo_frame>
    <%- end %>
  </turbo-frame>
<%- end %>
```

Was sich ändert: eine Relation statt zwei, `includes(:table)` statt N+1 beim Sortieren, und
`cols` aus `grid_count`. Die Mapping-Tabelle in Zeile 25 bleibt wie sie ist — nur ihr Eingabewert
wechselt von „gebunden" auf „laufend (mind. 2)".

Wer die Untergrenze nicht will, lässt `min_cols`/`grid_count` weg und nimmt
`[active_monitors.count]` direkt. Das ist die minimale Variante und behebt den Fall vom 17.10.
genauso; sie nimmt nur den Einzelkachel-Fall nach einem unglücklich getimten Reload in Kauf.

### Verworfene Variante: Platzhalterkacheln für leere Tische

Naheliegend wäre, stattdessen **alle gebundenen** Monitors zu rendern — dann stimmen Zählung
und Ausgabe ebenfalls überein, das Raster ist stabil, und die Kachel-Slots wären für den oben
beschriebenen Live-Update-Fehler sogar schon im DOM. Wir empfehlen das **nicht**:

* `TableMonitor::OptionsPresenter#build_options` (Zeile 31-37) fällt bei `game.blank?` auf
  `prev_game`/`prev_data` zurück und setzt `showing_prev_game: true`. Das Teaser-Partial
  wertet dieses Flag nicht aus — ein leerer Tisch würde also die **vorige, längst beendete
  Partie** zeigen, als liefe sie noch. Auf einem Saalmonitor ist das schlimmer als eine zu
  kleine Kachel.
* Bei einem Tisch, der in diesem Turnier noch nie gespielt hat, ist `prev_data` `NULL`
  (`db/schema.rb`, `table_monitors.prev_data` ohne Default). `show_data["free_game_form"]` in
  Zeile 38 würde dann auf `nil` aufgerufen. Ob `serialize :prev_data, coder: JSON, type: Hash`
  (`app/models/table_monitor.rb:367`) das noch zu `{}` glättet, haben wir **nicht
  verifiziert** — bitte prüfen, falls ihr diese Variante trotzdem wollt. Sie braucht jedenfalls
  einen eigenen Platzhalter-Zweig im Partial und ist damit kein Einzeiler mehr.

---

## CSS-Prüfung: sind alle möglichen Klassen im Build?

Bei interpolierten Tailwind-Klassen ist das nicht selbstverständlich — `tailwind.config.js`
hat **keine `safelist`**, `content` scannt nur `app/views/**/*.html.erb`, `app/helpers/**/*.rb`,
`app/assets/stylesheets/**/*.css` und `app/javascript/**/*.js`. Ergebnis der Prüfung:

| Klasse | Im Build? | Herkunft |
|---|---|---|
| `grid-cols-1` … `grid-cols-4` | **ja** | Tailwind-JIT aus literalen Vorkommen |
| `grid-cols-5`, `-6`, `-7` | ja | Tailwind-JIT |
| `grid-cols-8`, `-10`, `-17`…`-20` | ja | **handgeschrieben** in `app/assets/stylesheets/components/carambus.css:80ff` |
| `text-2vw` | **ja** | **handgeschrieben**, `components/carambus.css:11` |
| `text-3vw` | **ja** | **handgeschrieben**, `components/carambus.css:21` |

Geprüft in `app/assets/builds/application.css` (Build vom 23.09.2026) und im jüngsten
`public/assets/application-cdec80fb…css` — beide enthalten denselben Satz:
`grid-cols-1,2,3,4,5,6,7,8,9,10,12,17,18,19,20` und
`text-1vw,2vw,3vw,4vw,6vw,8vw,10vw,12vw,14vw,16vw,18vw,20vw,24vw`.

**Für diesen Fix ist also nichts zu tun** — der benötigte Bereich `grid-cols-1..4` /
`text-2vw` / `text-3vw` ist vollständig vorhanden, und die `text-Nvw`-Klassen sind
handgeschriebenes CSS und damit purging-immun.

**Aber es ist eine latente Falle, und ihr habt sie an einer Stelle schon umgangen.** Die
`grid-cols-N` für N ≤ 7 stehen nur deshalb im Build, weil sie literal in Views auftauchen:
`grid-cols-1` in 16 Dateien, `-2` in 35, `-3` in 31, `-4` in 20 — der Bereich 1–4 ist also
breit abgesichert. `grid-cols-7` dagegen kommt in **genau einer** Datei vor:

```erb
app/views/locations/_table_scores.html.erb:11-17
  <div class="grid grid-cols-1 gap-4"></div>
  <div class="grid grid-cols-2 gap-4"></div>
  …
  <div class="grid grid-cols-7 gap-4"></div>
```

Sieben leere Divs, die nur existieren, damit der JIT-Scanner die Klassen findet.
`scoreboard_tournament_scores.html.erb` hat diesen Trick **nicht**. Vorschlag für eine
Gelegenheit: eine echte `safelist` in `tailwind.config.js`
(`{ pattern: /^grid-cols-([1-9]|1[0-2])$/ }`) und die Dummy-Divs raus. Dann hängt keine
interpolierte Spaltenklasse mehr an einem zufälligen Literal in einer fremden View.

---

## Dieselbe Zählweise in verwandten Views?

Geprüft wurden alle Stellen mit `cols = { … }` (`grep -rn "cols = {" app/views/`):

**`app/views/locations/_table_scores.html.erb:18-21`** — gerendert über
`scoreboard_table_scores.html.erb:25`, also `sb_state=table_scores`. **Hier ist es schon
richtig:**

```erb
18  <%- tables_selected = location_.tables.select { |table| table.table_kind == table_kind && table.table_monitor.andand.game.present? } %>
19  <%- cols = { … }[tables_selected.count] || 7 %>
21  <%- tables_selected.sort_by { |table| table.name }.reverse.each do |table| %>
```

Dieselbe Variable wird gezählt und iteriert, und der Filter enthält bereits
`table_monitor.andand.game.present?`. **Kein Änderungsbedarf** — und das ist zugleich das
Muster, auf das die Turnierübersicht gebracht werden soll.

**`app/views/locations/scoreboard_tables.html.erb:29-31`** — `tables_selected` sind hier
bewusst *alle* Tische der Tischart (es ist der Tisch-**Auswahl**-Bildschirm), und genau diese
Menge wird gezählt und gerendert. **Konsistent, kein Änderungsbedarf.**

**`app/views/locations/scoreboard_big_table_scores.html.erb` — 0 Byte.** Die Datei ist in
unserem Checkout leer, obwohl der Controller sie rendert
(`app/controllers/locations_controller.rb:159`, `when "big_table_scores"`). `sb_state=big_table_scores`
liefert damit eine leere Seite. Das hat mit diesem Bug nichts zu tun, und wir wissen nicht, ob
die Datei bei euch auch leer ist (Platzhalter für etwas Geplantes?) oder ob bei uns etwas
verlorengegangen ist. **Bitte einmal gegenprüfen.**

---

## Testhinweis

**Reproduktion (ohne Code):** Turnier mit vier gebundenen Tischen anlegen, nur zwei Partien
starten, `/locations/<id>?sb_state=tournament_scores` öffnen, im HTML-Quelltext nach
`id="teasers"` suchen.

* vorher: `<turbo-frame id="teasers" class="grid grid-cols-4 text-2vw gap-8">` — zwei Kacheln darin
* nachher: `<turbo-frame id="teasers" class="grid grid-cols-2 text-3vw gap-8">`

**Automatisiert** lässt sich das gut als Request- oder View-Spec auf genau diesen
Klassen-String festnageln, mit der Anzahl `table_monitors` *mit Spiel* als Parameter:

| gebunden | mit Spiel | erwartet |
|---|---|---|
| 4 | 2 | `grid-cols-2 text-3vw` — der Fall vom 17.10. |
| 4 | 4 | `grid-cols-4 text-2vw` — unverändert gegenüber heute |
| 4 | 1 | `grid-cols-2 text-3vw` — Untergrenze greift (ohne sie: `grid-cols-1 text-3vw`) |
| 4 | 0 | `grid-cols-2`, leeres Grid, **keine Exception** |
| 1 | 1 | `grid-cols-1 text-3vw` |

**Zwei Dinge, die der Test mit abdecken sollte:**

1. **Der `|| 3`-Fallback wird jetzt anders erreichbar.** In der Mapping-Tabelle fehlt der
   Schlüssel `7` (und alles über 18). Bisher traf das nur Hallen mit sieben gebundenen Tischen;
   nach der Änderung trifft es *sieben laufende Partien* — in einer größeren Halle also
   häufiger. `7 → 3 Spalten` ist vermutlich Absicht (die Tabelle ist ja von Hand getuned,
   `6 → 3` und `9 → 3` stehen explizit drin), aber prüft es einmal bewusst nach.
2. **Keine Exception bei 0 laufenden Partien.** `active_monitors` ist dann `[]`, das Grid
   bleibt leer. Vorher wurde in diesem Fall ein 4-Spalten-Grid ohne Inhalt gerendert — also
   gleich harmlos, aber der Pfad ist neu.

Ein Blick auf die Query-Anzahl lohnt zusätzlich: der Fix entfernt eine der beiden
Relations-Abfragen und — über `includes(:table)` — das N+1 beim Sortieren.

---

## Was wir selbst nicht geändert haben

Nichts. Weder im Carambus-Repo noch in `carambus_bcw` ist eine Zeile angefasst. Der
`TableLocker`-Umweg vom 17.10. war eine Laufzeit-Maßnahme über die API, kein Patch — die
vier Tische sind inzwischen wieder gebunden. Wir patchen die View auch nicht lokal: beim
nächsten Deploy wäre es weg und an euch vorbei.
