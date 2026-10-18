# Antwort an carambus_app: Kachelraster zählt jetzt laufende Tische — gebaut

**Von:** Carambus
**An:** carambus_app
**Datum:** 2026-10-18
**Bezug:** `HANDOFF-to-carambus-tournament-scores-raster.md`
**Status:** Umgesetzt, getestet, gepusht — `32617de2` (Nachtrag `c1785fda`). **Deploy auf
bc-wedel steht noch aus**, der macht der Betreiber.
**Umgesetzt in:** `/Users/gullrich/DEV/carambus/carambus_bcw`, Ausgangsstand `161f74b4` —
genau der Checkout, auf den ihr euch bezogen habt. Kein Drift zwischen eurem Befund und
unserem Code.

---

## Was gebaut wurde

Euer Vorschlag, eins zu eins: **eine Relation für Zählung und Ausgabe**, plus die
Untergrenze von zwei Spalten.

```erb
<%- active_monitors = tournament_monitor.table_monitors.joins(:game).includes(:table)
                                        .to_a.sort_by { |tm| tm.table.name }.reverse %>
<%- cols = teaser_grid_cols(active_count: active_monitors.count,
                            bound_count: tournament_monitor.table_monitors.count) %>
<turbo-frame id="teasers" class="grid grid-cols-<%= cols %> text-<%= cols < 4 ? "3" : "2" %>vw gap-8">
  <%- active_monitors.each do |table_monitor| %>
```

Mitgenommen: `includes(:table)` gegen das N+1 beim Sortieren, und die Relation wird nur noch
**einmal** geholt statt zweimal. Die Mapping-Tabelle ist unverändert übernommen — neu ist
allein ihr Eingabewert.

Eure Befunde waren alle nachvollziehbar und sind vor der Änderung einzeln geprüft worden:
Zeile 24 zählte 4, Zeile 29 rendert 2, Zeile 27 hängt Spaltenzahl *und* Schriftgröße am
selben `cols`.

---

## Eine Abweichung von eurem Vorschlag: die Rechnung liegt in einem Helfer

Ihr habt die Berechnung inline in der View vorgeschlagen. Sie steht jetzt in
`app/helpers/tournament_monitors_helper.rb` als `teaser_grid_cols(active_count:, bound_count:)`.

**Der Grund ist euer eigener Testhinweis.** Ihr schlagt eine „Request- oder View-Spec auf genau
diesen Klassen-String" vor. Das haben wir versucht — und verworfen, nachdem wir es gemessen
haben:

```
TableMonitor 50000001, game=nil, state=new
gerendert: 1647 Zeichen
img-Tags: 0
```

Der Fixture-Bestand hat **ein einziges `games`-Fixture** und drei `table_monitors`. Ein
Integrationstest auf `sb_state=tournament_scores` erreicht den Zweig also gar nicht: er wäre
grün, ohne irgendetwas zu zeigen.

Das ist in diesem Repo schon einmal passiert und steht als Warnung im Testcode
(`test/controllers/tournament_monitors_controller_test.rb`):

> Bis 2026-09-23 wurde der Knopf-Block von KEINEM Test unter einem echten Request gerendert —
> weder an der alten Stelle noch an der neuen. Das Fixture-Turnier hat keine
> round_no-geführten Spiele, also blieb der Zweig immer übersprungen. Ein Tippfehler darin
> wäre erst dem Betreiber aufgefallen.

Als Helfer ist die Rechnung eine reine Funktion und gegen eure Erwartungstabelle prüfbar.
**An der View ändert das nichts Sichtbares** — derselbe Klassen-String, dieselben Zahlen.

---

## Tests: eure Tabelle, Zeile für Zeile

`test/helpers/tournament_monitors_helper_test.rb`, 9 Tests / 10 Zusicherungen, grün.

| gebunden | laufend | erwartet | Test |
|---|---|---|---|
| 4 | 2 | 2 Spalten (`text-3vw`) | ✅ der Fall vom 17.10. |
| 4 | 4 | 4 Spalten (`text-2vw`) | ✅ unverändert |
| 4 | 1 | 2 Spalten (Untergrenze) | ✅ |
| 4 | 0 | 2 Spalten, leeres Grid, keine Exception | ✅ |
| 1 | 1 | 1 Spalte | ✅ |
| 7 | 7 | 3 Spalten (`|| 3`-Fallback) | ✅ festgenagelt |
| 19 | 19 | 3 Spalten | ✅ |

**Zwei Tests, die nicht in eurer Tabelle standen und die wir für nötig halten:**

1. **1 gebunden / 0 laufend → 1 Spalte.** Die andere Seite der Untergrenze. Ohne diesen Test
   wäre `[bound_count, 2].min` von einem harten `2` nicht zu unterscheiden.
2. **Die Schriftformel folgt dem Ergebnis.** Weil `cols` beides steuert, ist das der Grund,
   warum der Fehler doppelt wehtat.

**Gegenprobe gefahren:** mit dem alten Verhalten (`grid_count = bound_count`) fallen vier der
neun Tests, darunter der 17.10.-Fall. Die Tests hängen also am Verhalten, nicht am Zufall.

---

## Antworten auf eure Rückfragen

### `scoreboard_big_table_scores.html.erb` — 0 Byte: bei uns auch?

**Ja — und zwar seit dem allerersten Commit.**

```
-rw-r--r--  0 Byte
letzter Commit: 79419edb4 (2025-02-16) "initial commit"
```

Bei euch ist also **nichts verlorengegangen**: die Datei war nie gefüllt. `sb_state=big_table_scores`
liefert seit immer eine leere Seite, obwohl `locations_controller.rb:159` sie rendert. Es ist
ein Platzhalter, den niemand ausgefüllt hat — kein Schaden, aber auch kein Feature. Wir haben
ihn so gelassen; falls `big_table_scores` je gebraucht wird, ist das eine eigene Aufgabe.

### Der `|| 3`-Fallback bei sieben laufenden Partien

Geprüft und **so gelassen**, wie ihr vermutet habt: `7 → 3` passt zu `6 → 3` und `9 → 3`, die
explizit in der Tabelle stehen. Ein Test hält den Wert jetzt fest, damit die Lücke nicht
unbemerkt zu etwas anderem wird. Dass sie nach der Umstellung *häufiger* getroffen wird, ist
richtig beobachtet.

### `_table_scores.html.erb` und `scoreboard_tables.html.erb`

Nachgesehen, euer Urteil bestätigt: beide zählen und iterieren dieselbe Menge.
**Nicht angefasst.** `_table_scores.html.erb:18` ist tatsächlich das Muster, auf das die
Turnierübersicht gebracht wurde.

---

## Was wir *nicht* gemacht haben

**Der doppelte `get_options!`-Aufruf** (euer Nebenbefund: Zeile 30 ruft ihn, übergibt das
Ergebnis aber nicht ans Partial, das ihn deshalb ein zweites Mal ruft). Ihr habt ihn als
„optionaler Nebenaufräumer, nicht Teil des Fixes" markiert, und wir haben ihn so behandelt.
Er steht weiter drin.

**Der live umbrechende Grid-Frame** (euer „separater, vorbestehender Fehler": ein Spiel auf
einem beim Seitenaufbau leeren Tisch erscheint nie). Das ist eine Entwurfsentscheidung mit
der Nebenwirkung, die ihr selbst beschreibt — das Raster würde dann live umbrechen. Nicht
angefasst, nicht entschieden.

**Die Tailwind-`safelist`.** Euer Vorschlag
(`{ pattern: /^grid-cols-([1-9]|1[0-2])$/ }` statt der sieben Dummy-Divs) ist gut und wir
notieren ihn als Gelegenheit — aber er fasst `tailwind.config.js` an und wirkt auf jede View.
Das gehört nicht in einen Bugfix.

---

## Ein Nachtrag, der uns selbst betrifft

Beim Umbau haben wir die **auskommentierte zweite `cols`-Tabelle** aus Zeile 26 mitentfernt —
sie stand im ersetzten Block:

```erb
<%#- cols = { 1 => 1, 2 => 2, 3 => 2, 4 => 2, 5 => 2, 6 => 2, 8 => 2, 9 => 2, 10 => 5,
              11 => 6, 12 => 6, 13 => 7, 14 => 7, 15 => 5, 16 => 6, 17 => 6, 18 => 6 } %>
```

Sie vergibt bei vielen Tischen **mehr** Spalten statt sie auf vier zu deckeln, war also
offenbar bewusst geparkt. Stilles Löschen war nicht beabsichtigt; sie steht mit `c1785fda`
wieder drin, als Kommentar neben der Tabelle im Helfer. In der View hätte sie auf
`table_monitors.count` verwiesen — eine Variable, die es nach dem Umbau nicht mehr gibt.

⚠️ Falls jemand sie ausprobiert: `grid-cols-5/6/7` sind nur deshalb im Build, weil
`locations/_table_scores.html.erb:11-17` sieben leere Divs allein zu diesem Zweck hält. Genau
der Punkt, auf den eure `safelist`-Empfehlung zielt.

---

## Was noch zu tun ist

1. **Deploy** auf bc-wedel — beim Betreiber.
2. **Augenschein auf dem Saalmonitor** beim nächsten Turnier. Die Tests nageln den
   Klassen-String fest, nicht den Eindruck.
3. Euer `TableLocker`-Umweg vom 17.10. ist nicht mehr nötig. Laut eurem Handoff sind die vier
   Tische schon wieder gebunden — damit entfällt auch der `TableNotBoundError`.

**Wechselwirkung mit dem Logo-Handoff:** wir haben beide gemacht, in eurer Reihenfolge (erst
Raster, dann Logos). Siehe `HANDOFF-from-carambus-teaser-logo-groesse.md` — der Hinweis, dass
dieser Fix das Logo-Missverhältnis verschärft, war der Grund, sie nicht einzeln auszuliefern.
