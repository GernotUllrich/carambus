# Handoff an Carambus (Paul): Vereinswappen im Scoreboard-Teaser skalieren nicht mit

**Von:** Carambus Turnier-App (Gernot)
**An:** Carambus (Paul-Plugin) — Scoreboard-Views
**Datum:** 2026-10-18
**Status:** Darstellungsfehler. Rein serverseitig (ein Partial, zwei Zeilen), keine Migration,
kein API-Change, keine App-Änderung. Umsetzung durch Paul.
**Untersuchter Checkout:** `/Users/gullrich/DEV/carambus/carambus_bcw`, HEAD `161f74b4`
(2026-10-16). Die beiden betroffenen Zeilen sind seit `79419edb4` (2025-02-16) unverändert;
das Partial selbst wurde zuletzt mit `cd7a2bd4` (2026-10-13, „Nachname, Vorname") angefasst.

**Verwandt, aber unabhängig:** `HANDOFF-to-carambus-tournament-scores-raster.md` (Kachelraster
der Turnierübersicht zählt gebundene statt laufende Tische). Beide betreffen die Lesbarkeit
derselben Seite und lassen sich **getrennt und in beliebiger Reihenfolge** umsetzen — der eine
ändert ERB-Logik in der View, der andere zwei `image_tag`-Aufrufe im Partial. Sie berühren sich
nur in einem Punkt, und der spricht dafür, beide zu machen: siehe
[Wechselwirkung mit dem Raster-Handoff](#wechselwirkung-mit-dem-raster-handoff).

---

## Der Fall vom 18.10.2026

Beim **23. DBU Grand Prix Biathlon** (17./18.10.2026, BC Wedel) lief die Turnierübersicht
`/locations/1?sb_state=tournament_scores` auf einem **Samsung-Fernseher** im Saal. Namen und
Punktestände skalierten mit und waren gut lesbar — die **Vereinswappen daneben blieben winzig**,
nach Eindruck im Saal „extrem klein". Auf dem Laptop, auf dem die Seite vorher geprüft wurde,
war nichts aufgefallen.

Das ist kein Zufall, sondern genau das erwartbare Verhalten: im Teaser sind die Schriftgrößen
in `vw` gesetzt (skalieren mit der Bildschirmbreite), die Logos in `rem` (skalieren nicht).
Auf einem 1440er Laptop fallen die beiden Maße zufällig zusammen, auf einem großen Display
laufen sie auseinander.

---

## Befund

### Die feste Größe

`app/views/table_monitors/_teaser.html.erb`, Zeilen **60** und **92** — identisch für linken
und rechten Spieler:

```erb
60  <div class="w-1/4"><%= image_tag(left_player[:logo],  class: "object-contain h-10 w-20") if left_player[:logo].present? %></div>
92  <div class="w-1/4"><%= image_tag(right_player[:logo], class: "object-contain h-10 w-20") if right_player[:logo].present? %></div>
```

`h-10 w-20` sind Tailwind-Standardklassen; geprüft in `app/assets/builds/application.css`:

```css
.h-10{height:2.5rem}   /* 40 px */
.w-20{width:5rem}      /* 80 px */
```

Das ist eine **feste Box von 80 × 40 px**, unabhängig von Bildschirm- und Schriftgröße.

### Alle Größenangaben im Partial, sortiert nach „skaliert / skaliert nicht"

Wir haben das Partial vollständig durchgesehen, nicht nur die Logo-Zeilen. Es gibt weitere
feste Maße, und sie haben dasselbe Problem — nur weniger sichtbar:

| Zeile | Angabe | Art | Wirkung |
|---|---|---|---|
| 28, 35 | `text-1vw` | **relativ** | Turniertitel, Disziplin |
| 43 | `text-2vw` (`<strong>`) | **relativ** | laufende Aufnahme |
| 50 | `text-2vw` | **relativ** | Statusanzeige (rot) |
| 24, 61–69, 76–77, 83–85, 93–101, 108–109, 115–117 | *keine* → erbt vom Grid-Container | **relativ** (`2vw`/`3vw`) | Tischnummer, **Spielernamen**, Punktestand, Aufnahme |
| **60, 92** | **`h-10 w-20`** | **fest, 40 × 80 px** | **Vereinswappen** |
| 16 | `m-10` | fest, 40 px | Außenabstand der Teaser-Tabelle |
| 61, 93 | `p-3` | fest, 12 px | Polster um den Spielernamen (schwarzer Kasten) |
| 29, 36, 51, 76, 83, 108, 115 | `p-1` | fest, 4 px | Polster um Punktestand / Aufnahme |
| 76, 83, 108, 115 | `ml-2` | fest, 8 px | Abstand der Zahlenfelder |

Die Logos sind also **die einzige feste *Inhalts*größe** — alles andere Feste ist Polster und
Abstand. Deshalb fällt nur das Logo auf. Die festen Polster sind trotzdem derselbe Konstruktions-
fehler und werden am 4K-Display sichtbar: 12 px Polster um eine 115 px hohe Schrift wirkt
gequetscht. Das ist ein **optionaler Nebenpunkt**, siehe unten.

### Die Wappen selbst sind hochkant oder quadratisch — die Box ist liegend

`:logo` ist eine URL (`clubs.logo`, `:string`, von den Verbandsseiten gescrapt:
`app/models/club.rb:231`). Drei Beispiele aus `carambus_bcw_development`, Naturgröße im
Browser gemessen:

| URL | Naturgröße | Verhältnis |
|---|---|---|
| `https://ndbv.de/images/wappen/1015.gif` | 100 × 100 | 1 : 1 |
| `https://westfalenbillard.net/images/wappen/1293.gif` | 137 × 200 | hochkant |
| `https://billard-bvbw.de/images/wappen/2442.gif` | 152 × 200 | hochkant |

Die Box ist mit 80 × 40 px aber **liegend (2 : 1)**. Mit `object-contain` bindet deshalb immer
die **Höhe**, und die Breite bleibt ungenutzt. Im Browser gemessen (Box 80 × 40):

| Wappen | tatsächlich sichtbar | ungenutzte Boxbreite |
|---|---|---|
| 100 × 100 | **40 × 40 px** | 40 px |
| 137 × 200 | **27,4 × 40 px** | 52,6 px |

Das ist der zweite Teil des Befunds: die deklarierten 80 px Breite sind **irreführend**. Kein
reales Wappen füllt sie. Wirksam ist allein die Höhe von 40 px — und bei hochkanten Wappen
bleibt ein 27 px breiter Streifen übrig. (Nebenbei: `w-20` = 80 px ist zudem breiter als der
umgebende `w-1/4`-Wrapper in schmalen Kacheln, das `<img>` ragt dort heraus.)

---

## Die Rechnung: wie groß ist die Schrift neben den 40 px?

Beide einbindenden Views setzen die Schriftgröße nach **derselben Formel** am Grid-Container:

```erb
app/views/locations/scoreboard_tournament_scores.html.erb:27
app/views/locations/_table_scores.html.erb:20
  <turbo-frame id="teasers" class="grid grid-cols-<%= cols %> text-<%= cols < 4 ? "3" : "2" %>vw gap-8">
```

Die `text-Nvw`-Klassen sind handgeschriebenes CSS (`app/assets/stylesheets/components/carambus.css:1-80`),
jeweils mit `line-height: 1` — die Zeilenhöhe ist also gleich der Schriftgröße:

```css
.text-2vw{font-size:2vw;line-height:1}
.text-3vw{font-size:3vw;line-height:1}
```

Daraus die Schrifthöhe der **Spielernamen** (die erben vom Container) neben der konstanten
Logohöhe von 40 px:

| Bildschirmbreite | 2 vw (ab 4 Spalten) | 3 vw (1–3 Spalten) | Logo | Verhältnis Logo : Schrift (2 vw / 3 vw) |
|---|---|---|---|---|
| 1440 px (Laptop) | 28,8 px | 43,2 px | 40 px | **1,39** / 0,93 |
| 1920 px (Full-HD-TV) | 38,4 px | 57,6 px | 40 px | 1,04 / **0,69** |
| 3840 px (4K-TV) | 76,8 px | 115,2 px | 40 px | 0,52 / **0,35** |

**Warum es auf dem Laptop nicht auffällt:** bei 1440 px und 4 Spalten ist das Logo mit 40 px
*größer* als die Schrift (Faktor 1,39) — es sieht genau richtig aus. Bei 1–3 Spalten sind es
0,93, also noch praktisch gleich hoch. Der Laptop liegt zufällig genau im Bereich, für den die
40 px einmal gewählt wurden.

**Was auf dem TV passiert:** bei 3840 px und 2–3 Spalten (der Normalfall bei Halbfinals) steht
ein 40 px hohes Logo neben 115 px hoher Schrift — **ein Drittel der Buchstabenhöhe**. Bei
hochkanten Wappen sind davon nur 27 px Breite belegt. Das deckt sich mit „extrem klein".

Zur Einordnung, ehrlich gesagt: **welche CSS-Breite der Samsung-TV meldet, haben wir nicht
gemessen.** TV-Browser melden bei 4K-Panels häufig 1920 CSS-px mit `devicePixelRatio: 2`, nicht
3840. Beide Fälle sind aber Befund: bei 1920 px und 3 vw ist das Verhältnis 0,69, bei 3840 px
0,35. Der Fehler existiert in beiden, nur die Stärke unterscheidet sich. Wer es genau wissen
will: `window.innerWidth` im TV-Browser auslesen.

---

## Entwurfsfrage: ein Wert für zwei Kontexte

Das Partial wird von **zwei** Views eingebunden, eine Änderung wirkt auf beide:

| | `locations/scoreboard_tournament_scores.html.erb` | `locations/_table_scores.html.erb` |
|---|---|---|
| Aufruf | `sb_state=tournament_scores` | `sb_state=table_scores` (über `scoreboard_table_scores.html.erb:25`) |
| Einbindung | Zeile 32 | Zeile 26 |
| Schriftformel | `cols < 4 ? 3 : 2` vw (Zeile 27) | **identisch** (Zeile 20) |
| Spaltenzahl | Mapping-Tabelle, **max. 4** (Zeile 25) | Mapping-Tabelle, Default `\|\| 7`, **bis 7** (Zeile 19) |
| Umgebung | `p-14`-Wrapper, `gap-8` | `p-8`-Wrapper, `gap-8` |

**Die gute Nachricht:** die Schriftformel ist in beiden Views dieselbe. Ein Logo-Maß, das in
`em` (also relativ zur geerbten Schriftgröße) angegeben ist, hält deshalb in **beiden** Views
und in **beiden** `cols`-Fällen dasselbe Verhältnis zur Schrift. Ein fester `vw`-Wert tut das
*nicht* — er wäre bei `text-2vw` richtig und bei `text-3vw` zu klein, und zwar schon innerhalb
derselben View. **Das ist das eigentliche Argument für `em` statt `vw`.**

**Der Unterschied, den man kennen muss:** `table_scores` lässt bis zu **7 Spalten** zu. Dort
schrumpft die Kachel, die Schrift bleibt aber bei 2 vw. Nachgerechnet für 1920 px und 7 Tische:

```
(1920 − 2·32 [p-8] − 6·32 [gap-8]) / 7 = 237 px Kachel
− 2·40 px (m-10 der Teaser-Tabelle)      = 157 px Inhaltsbreite
```

Im Browser gemessen: der Name „Mustermann, Heinz" bei 2 vw / 1920 px braucht mit `p-3`
**353 px**; die Teaser-Tabelle wird damit **359 px** breit. Die Kachel ist 157 px breit —
**der Teaser läuft in der 7-Spalten-Variante heute schon über**, mit oder ohne Logo. Dieser Fall
ist aus anderen Gründen kaputt; **der Logo-Wert darf nicht gegen ihn getunt werden.** (Wir haben
das nicht an einem echten 7-Tisch-Bildschirm gegengeprüft — die Rechnung steht, der Augenschein
fehlt.)

Praktisch heißt das: tunen gegen den Fall, der real auf dem Saalmonitor steht (1–4 Spalten),
und sicherstellen, dass die Änderung die schmalen Kacheln **nicht zusätzlich** verengt. Der
Vorschlag unten erfüllt das — er macht die Box dort sogar *schmaler* als heute.

---

## Empfehlung

**Logohöhe = 1,4 × geerbte Schriftgröße, Box quadratisch, mit 24-px-Untergrenze,
`object-contain` bleibt.**

Konkret, Zeilen 60 und 92:

```erb
60  <div class="w-1/4"><%= image_tag(left_player[:logo], class: "object-contain",
        style: "height: 1.4em; width: 1.4em; min-height: 1.5rem; min-width: 1.5rem") if left_player[:logo].present? %></div>

92  <div class="w-1/4"><%= image_tag(right_player[:logo], class: "object-contain",
        style: "height: 1.4em; width: 1.4em; min-height: 1.5rem; min-width: 1.5rem") if right_player[:logo].present? %></div>
```

Vorschlag für den Kommentar darüber, damit der Wert nicht beim nächsten Umbau wieder zur
festen Zahl wird:

```erb
<%- # Wappengroesse relativ zur geerbten Schrift (Grid-Container setzt text-2vw bzw.
    # text-3vw): 1.4em entspricht genau dem Verhaeltnis, das bei 1440 px / 4 Spalten
    # schon richtig aussah (40 px Logo zu 28,8 px Schrift) -- und haelt es auf jedem
    # Display. Fruehere feste 40 x 80 px wurden auf dem 4K-Saalmonitor zu einem
    # Drittel der Buchstabenhoehe (23. DBU Grand Prix, 18.10.2026).
    # Quadratische Box, weil die Verbandswappen quadratisch oder hochkant sind --
    # eine liegende 2:1-Box verschenkt nur Breite. object-contain muss bleiben.
    # min-* greift erst unter ~860 px Bildschirmbreite, damit das Logo auf einem
    # Telefon nicht verschwindet. %>
```

### Warum 1,4 und nicht irgendein vw-Wert

Der Faktor ist nicht geraten: **1,39 ist das Verhältnis, das heute schon gut aussieht** — 40 px
Logo neben 28,8 px Schrift bei 1440 px und 4 Spalten, also genau die Konstellation, in der die
Logos nie beanstandet wurden. `1.4em` reproduziert diesen Eindruck und trägt ihn auf jede
Bildschirmgröße. Im Browser gemessen (gerenderte Boxhöhe):

| Bildschirmbreite | 2 vw → 1,4 em | 3 vw → 1,4 em | heute |
|---|---|---|---|
| 1440 px | **40,3 px** | 60,5 px | 40 px |
| 1920 px | 53,8 px | 80,6 px | 40 px |
| 3840 px | 107,5 px | 161,3 px | 40 px |

Bei 1440 px / 4 Spalten also 40,3 px gegen heute 40 px — **auf dem Laptop ändert sich der
Augenschein praktisch nicht.** Das ist beabsichtigt: die Änderung repariert die großen
Displays, ohne das zu verstellen, was heute passt.

### Warum die Box quadratisch wird — und dabei sogar schmaler

Alle gemessenen Wappen sind quadratisch oder hochkant. Eine quadratische Box von `1.4em` nimmt
jedes davon ohne Verzerrung auf (hochkant bleibt mit `object-contain` schmaler als die Box —
gemessen 36,8 × 53,8 px bei 2 vw / 1920 px). Der Nebeneffekt ist der wichtige:

`1.4em` überschreitet die heutigen 80 px Boxbreite erst, wenn die Schrift größer als 57,1 px
wird — bei `text-2vw` also ab 2857 px, bei `text-3vw` ab 1905 px Bildschirmbreite. **In der
gedrängten 4-Spalten-Variante bis 2857 px ist die neue Box schmaler als die alte** (53,8 statt
80 px bei 1920 px) — der Spielername bekommt dort also Platz dazu, genau wo es knapp ist. Breiter
wird sie nur bei wenigen Spalten auf großen Displays, wo reichlich Platz ist.

### Untergrenze

`min-height/min-width: 1.5rem` (24 px) greift, wenn `1.4 × Schriftgröße < 24 px`, also unter
**857 px** Bildschirmbreite bei `text-2vw` bzw. **571 px** bei `text-3vw`. Auf jedem
Saalmonitor, Laptop und Tablet ist die Untergrenze damit **wirkungslos** — sie existiert nur,
damit das Wappen auf einem Telefon (2 vw = 7,8 px bei 390 px Breite → 11 px Box) nicht zum Punkt
schrumpft. Mit `object-contain` verzerrt sie nichts; gemessen bei greifender Untergrenze:
Box 24 × 24, sichtbar 16,4 × 24 für das 137 × 200er Wappen — Seitenverhältnis erhalten.

Wer die Untergrenze nicht will, lässt die beiden `min-*` weg. Der Rest des Vorschlags bleibt
davon unberührt.

### Auflösungsgrenze — das Einzige, was wirklich dagegen spricht

Die Wappen sind 100–200 px hoch (gemessen). Bei `text-3vw` auf 3840 px wird die Box 161 px hoch:
die 200 px hohen Wappen bleiben darunter, das 100 × 100er wird **1,6-fach hochskaliert** und wirkt
weich. Auf einem Saalmonitor aus Zuschauerentfernung ist das vermutlich das kleinere Übel gegen
„ein Drittel der Buchstabenhöhe", aber es ist eine echte Abwägung. Wer sie vermeiden will, hängt
eine Obergrenze an:

```
style: "height: 1.4em; width: 1.4em; min-height: 1.5rem; min-width: 1.5rem; max-height: 200px; max-width: 200px"
```

200 px ist die native Höhe der größeren Wappen und damit die natürliche Decke. Wir empfehlen
sie **nicht** von vorn herein — sie bringt bei `text-3vw` ab 4762 px Breite eine neue, feste
Grenze zurück, also genau das Problem, das hier behoben wird, nur eine Stufe höher. Eure
Entscheidung.

---

## CSS-Prüfung: Tailwind-Klassen oder inline-style?

Nach dem Muster der übrigen Views wäre `class: "object-contain h-[1.4em] w-[1.4em] min-h-[1.5rem] min-w-[1.5rem]"`
naheliegend. **Geprüft — die Klassen existieren heute nicht:**

| Klasse | in `app/assets/builds/application.css` | im jüngsten `public/assets/application-*.css` |
|---|---|---|
| `h-[1.4em]`, `w-[1.4em]` | **nein** | **nein** |
| `min-h-[1.5rem]`, `min-w-[1.5rem]` | **nein** | **nein** |
| `h-[60vh]`, `min-h-[38px]`, `max-w-[200px]` | ja | ja |
| `h-10`, `w-20`, `object-contain` | ja | ja |
| `text-1vw` … `text-24vw` | ja (handgeschrieben, `components/carambus.css`) | ja |

Die dritte Zeile ist der Beleg, dass Tailwind-Arbitrary-Values in diesem Projekt grundsätzlich
funktionieren: `mode: 'jit'`, `content` deckt `./app/views/**/*.html.erb` ab
(`tailwind.config.js`), und der Deploy baut das CSS vor dem Precompile
(`config/deploy.rb:177` `execute :yarn, "build:css"`, verdrahtet über
`before "deploy:assets:precompile", "deploy:assets:build_frontend_assets"`, Zeile 230). Nach
einem regulären Deploy **wären** die neuen Klassen also da.

**Wir empfehlen trotzdem inline-style**, aus einem Grund: das Fehlerbild einer fehlenden Klasse
ist hier besonders unangenehm. Ohne `h-…`/`w-…` hat das `<img>` **gar keine** Größenbeschränkung
— es rendert in Naturgröße (100–200 px hoch, gemessen) und `object-contain` greift ins Leere.
Ein Hotfix, der nur das ERB auf den Server bringt, oder ein stehengebliebenes
`app/assets/builds/application.css` (die Datei ist im Repo eingecheckt und kann gegenüber den
Views veralten) führt dann nicht zu „Logo wie vorher", sondern zu **riesigen Wappen, die die
Kachel sprengen**. Bei einer Änderung, deren ganzer Inhalt eine Größe ist, ist das
Build-unabhängige `style`-Attribut die robustere Form. `object-contain` bleibt als Klasse — die
ist seit Jahren im Build und wird hier nicht neu gebraucht.

Wenn ihr die Tailwind-Variante bevorzugt (Konsistenz mit dem Rest der Views), ist sie
funktional gleichwertig — dann aber bitte mit der Auflage, dass `yarn build:css` plus
`assets:precompile` Teil des Rollouts ist, und einmal im ausgelieferten
`public/assets/application-*.css` nach `.h-\[1\.4em\]` greppen.

---

## Wechselwirkung mit dem Raster-Handoff

`HANDOFF-to-carambus-tournament-scores-raster.md` schlägt vor, `cols` aus den **laufenden**
statt den **gebundenen** Tischen zu berechnen. Der Fall vom 17.10. (4 gebunden, 2 laufend) ergibt
danach `grid-cols-2 text-3vw` statt `grid-cols-4 text-2vw`.

Das heißt: **nach dem Raster-Fix wird die Schrift in genau diesen Situationen größer — und das
Logo-Missverhältnis damit schlechter.** Aus 1,04 (2 vw bei 1920 px) wird 0,69 (3 vw), aus 0,52
wird 0,35 bei 3840 px. Der Raster-Fix behebt ein Lesbarkeitsproblem und verschärft dabei dieses.

Umgekehrt gilt die Entwarnung: der hier vorgeschlagene `em`-Wert ist gegen die Schriftformel
immun. Er funktioniert vor dem Raster-Fix, nach ihm und bei jedem `cols`-Wert gleich — die
beiden Änderungen kollidieren nicht und brauchen keine Reihenfolge. Wir würden beide machen.

---

## Nebenbefunde (gehören nicht in diesen Fix)

**1. Feste Polster gegen skalierende Schrift** — `p-3` (12 px) um den Spielernamen, `p-1`
(4 px) und `ml-2` (8 px) um die Zahlenfelder, `m-10` (40 px) um die Teaser-Tabelle. Bei 3 vw auf
3840 px steht 12 px Polster um 115 px hohe Glyphen; der schwarze Namenskasten klebt an den
Buchstaben. Analog zum Logo-Fix wäre `p-[0.3em]` statt `p-3` das Mittel. Wir schlagen es
**nicht** als Teil dieser Änderung vor: es verschiebt das Layout sichtbar in beiden Views und ist
eine eigene optische Entscheidung, kein Fehler-Fix.

**2. Fehlendes `>` in Zeile 43.** Beim vollständigen Lesen aufgefallen:

```erb
43  <%= "#{t("table_monitor.inning")} <strong class='text-2vw'>#{…}</strong".html_safe %>
```

Das `</strong` hat kein schließendes `>`. Im Browser nachgestellt: der Parser verschluckt das
**darauf folgende `</div>`** als Teil des defekten End-Tags — das `<div class="p-1">` aus Zeile 36
bleibt offen und nimmt den nachfolgenden Inhalt in sich auf. Gemessen am Testschnipsel:

```
Eingabe:   …<strong class='text-2vw'>7</strong</div><div>NAECHSTER BLOCK</div>
DOM:       <div class="p-1">…<strong>7</strong><div>NAECHSTER BLOCK</div></div>
                                               ^ eine Ebene zu tief
```

Praktisch verschiebt das die `<td>`/`<tr>`-Verschachtelung des Teasers um eine Ebene. Der Browser
reparierts sich zurecht, sichtbar ist offenbar nichts — aber es ist ein Einzeichen-Fix, wenn ihr
sowieso in der Datei seid.

**3. Dasselbe Literal steht an sechs weiteren Stellen.** `object-contain h-10 w-20` kommt vor in:

```
app/views/table_monitors/_player_score_panel.html.erb:103, 118   (neben text-<%= vw3 %>)
app/views/table_monitors/_pool_scoreboard.html.erb:57, 313
app/views/table_monitors/_snooker_scoreboard.html.erb:76, 300
```

Das sind die Vollbild-Scoreboards eines einzelnen Tisches. Auch dort steht die feste 40-px-Box
neben vw-skalierter Schrift, der Konstruktionsfehler ist derselbe. **Bewusst nicht Teil dieses
Handoffs:** die Kontexte dort sind andere (Vollbild, eigene `vw3`/`vw6`-Variablen, anderes
Layout), der passende `em`-Faktor ist nicht automatisch 1,4, und es bräuchte je Ansicht einen
eigenen Augenschein. Falls ihr es gleich mit angeht: bitte je View prüfen, nicht pauschal
ersetzen.

---

## Testhinweis

**Reproduktion ohne Code:** `/locations/<id>?sb_state=tournament_scores` mit 2 laufenden
Partien öffnen, im Browser die Viewport-Breite auf 3840 setzen (DevTools → Device Toolbar →
Responsive) und das Wappen messen:

```js
const img = document.querySelector('.teaser img');
const r = img.getBoundingClientRect();
({ box: [r.width, r.height], schrift: getComputedStyle(img.closest('table')).fontSize })
```

* vorher: `box: [80, 40]`, `schrift: "115.2px"` — Verhältnis 0,35
* nachher: `box: [161.3, 161.3]`, `schrift: "115.2px"` — Verhältnis 1,4

**Erwartungswerte für einen Durchgang über die Breiten** (gerenderte Boxhöhe, von uns im
Browser gemessen):

| Breite | Spalten | Schrift | vorher | nachher |
|---|---|---|---|---|
| 1440 | 4 | 28,8 px (2 vw) | 40 px | **40,3 px** (unverändert im Augenschein) |
| 1440 | 2 | 43,2 px (3 vw) | 40 px | 60,5 px |
| 1920 | 4 | 38,4 px (2 vw) | 40 px | 53,8 px |
| 1920 | 2 | 57,6 px (3 vw) | 40 px | 80,6 px |
| 3840 | 2 | 115,2 px (3 vw) | 40 px | 161,3 px |
| 390 (Telefon) | 4 | 7,8 px (2 vw) | 40 px | 24 px (Untergrenze greift) |

**Beide Kontexte anfassen** — die Änderung wirkt auf zwei Seiten:

1. `sb_state=tournament_scores` (Turnierübersicht, 1–4 Spalten) — der Fall vom 18.10.
2. `sb_state=table_scores` („Laufende Partien", bis 7 Spalten) — hier vor allem darauf schauen,
   dass die Kacheln **nicht enger** werden. Sollten sie nicht: die Box ist unter 2857 px Breite
   schmaler als vorher. Dass der Teaser in der 7-Spalten-Variante schon vorher überläuft, ist
   ein anderes Thema (siehe Entwurfsfrage).

**Verzerrungstest:** je ein quadratisches und ein hochkantes Wappen nebeneinander, z. B.
`ndbv.de/images/wappen/1015.gif` (100 × 100) und `westfalenbillard.net/images/wappen/1293.gif`
(137 × 200). Beide müssen ihr Seitenverhältnis behalten — wenn `object-contain` verlorengeht,
wird das hochkante Wappen sichtbar quadratisch gestaucht.

**Automatisiert** lässt sich hiervon nur der ausgelieferte Markup festnageln, nicht der optische
Eindruck: eine View-Spec auf das `style`-Attribut bzw. den Klassenstring des `<img>`, plus die
Zusicherung, dass `object-contain` vorhanden bleibt. Mehr gibt eine Spec hier nicht her — die
`em`-Auflösung passiert im Browser.

---

## Was wir selbst nicht geändert haben

Nichts. Weder im Carambus-Repo noch in `carambus_bcw` ist eine Zeile angefasst. Alle Messungen
sind an Nachbauten im Browser entstanden (`font-size: 2vw`/`3vw` plus die echten Wappen-URLs,
Viewport auf 1440 / 1920 / 3840 emuliert) sowie durch Greps in
`app/assets/builds/application.css` und dem jüngsten `public/assets/application-*.css`. Die
Naturgrößen der Wappen kommen aus `naturalWidth`/`naturalHeight` der echten Dateien auf den
Verbandsservern.
