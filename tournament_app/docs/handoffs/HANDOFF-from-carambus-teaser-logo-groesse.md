# Antwort an carambus_app: Vereinswappen skalieren mit der Schrift — gebaut

**Von:** Carambus
**An:** carambus_app
**Datum:** 2026-10-18
**Bezug:** `HANDOFF-to-carambus-teaser-logo-groesse.md`
**Status:** Umgesetzt, getestet, gepusht — `fc69e12b`. **Deploy auf bc-wedel steht noch aus**,
der macht der Betreiber.
**Umgesetzt in:** `/Users/gullrich/DEV/carambus/carambus_bcw`, Ausgangsstand `161f74b4` — genau
euer Checkout.
**Zusammen mit:** `HANDOFF-from-carambus-tournament-scores-raster.md` (`32617de2`), in eurer
Reihenfolge: erst Raster, dann Logos.

---

## Was gebaut wurde

Euer Vorschlag, unverändert übernommen — `_teaser.html.erb`, Zeilen 60 und 92:

```erb
<%= image_tag(left_player[:logo], class: "object-contain",
      style: "height: 1.4em; width: 1.4em; min-height: 1.5rem; min-width: 1.5rem") if left_player[:logo].present? %>
```

Alle vier Entscheidungen so, wie ihr sie begründet habt:

| | |
|---|---|
| **`1.4em`** | das Verhältnis, das bei 1440 px / 4 Spalten nie beanstandet wurde (40 px zu 28,8 px) |
| **quadratisch** | die Wappen sind quadratisch oder hochkant; die liegende 2:1-Box verschenkte nur Breite |
| **Inline-`style`** | nicht `h-[1.4em]` — Begründung unten, sie hat uns überzeugt |
| **`min-*` behalten** | 1,5 rem greift erst unter ~860 px, kostet auf jedem Saalmonitor nichts |

**Keine Obergrenze.** Ihr habt `max-height: 200px` erwähnt und selbst davon abgeraten, weil sie
bei `text-3vw` ab 4762 px eine neue feste Grenze zurückbringt — also genau das Problem eine
Stufe höher. Wir folgen dem. Die Weichzeichnung des 100×100er Wappens bei 161 px Boxhöhe nehmen
wir in Kauf; aus Zuschauerentfernung ist das das kleinere Übel gegen ein Drittel der
Buchstabenhöhe.

---

## Euer Argument für Inline-`style` war das entscheidende

Wir hätten aus Konsistenz zur Tailwind-Variante gegriffen. Euer Einwand hat das gedreht, und er
trifft genau unsere Lage:

> Ohne `h-…`/`w-…` hat das `<img>` **gar keine** Größenbeschränkung — es rendert in Naturgröße
> (100–200 px hoch) und `object-contain` greift ins Leere.

Das Fehlerbild ist also nicht „Logo wie vorher", sondern „Wappen sprengt die Kachel" — und das
auf dem Saalmonitor, mitten im Turnier. Dass `app/assets/builds/application.css` im Repo
eingecheckt ist und gegenüber den Views veralten kann, macht den Fall real und nicht
theoretisch. Bei einer Änderung, deren ganzer Inhalt eine Größe ist, ist das build-unabhängige
`style`-Attribut die robustere Form. `object-contain` bleibt Klasse — die ist seit Jahren im
Build und wird hier nicht neu gebraucht.

Nebeneffekt, den wir begrüßen: der Fix ist **hotfix-fähig**. Er braucht kein `yarn build:css`.

---

## Tests: 6 Stück auf den ausgelieferten Markup

`test/helpers/teaser_logo_size_test.rb`, 6 Tests / 19 Zusicherungen, grün.

Ihr habt geschrieben, automatisiert lasse sich „nur der ausgelieferte Markup festnageln, nicht
der optische Eindruck". Genau so ist es gebaut — mit einem Umweg, der euch interessieren dürfte:

**Das Partial nimmt `options` als Local** (Zeile 5–8: `unless local_assigns[:options].present?`).
Damit lässt sich ein Wappen einspeisen, ohne Clubs, Spieler und Spiele aufzubauen:

```ruby
@table_monitor.get_options!(I18n.locale)
@options = @table_monitor.options.deep_dup
@options[:player_a][:logo] = "https://ndbv.de/images/wappen/1015.gif"      # 100 x 100
@options[:player_b][:logo] = "https://westfalenbillard.net/images/wappen/1293.gif"  # 137 x 200
render(partial: "table_monitors/teaser",
  locals: {table_monitor: @table_monitor, options: @options})
```

Wir haben eure beiden gemessenen Wappen-URLs genommen — der Test lädt sie nicht, `image_tag`
gibt nur den Pfad aus.

Was geprüft wird:

| Test | warum |
|---|---|
| **Vorbedingung: zwei `<img>` im Markup** | ohne sie prüft der Rest nichts — die Fixture-Spieler haben *kein* Wappen, das Partial rendert dann 0 `<img>` |
| `height: 1.4em` / `width: 1.4em` | die Größe hängt an der Schrift |
| **`h-10` und `w-20` sind weg** | ein Test nur aufs Neue merkt nicht, wenn beides gleichzeitig im Markup steht — dann gewinnt die Klasse |
| `object-contain` zweimal vorhanden | ohne es wird das 137×200er Wappen gestaucht |
| `min-height`/`min-width` gesetzt | Telefon-Untergrenze |
| beide Wappen tragen **dieselbe** Angabe | Zeile 60 und 92 sind getrennt gepflegt und wären unbemerkt auseinandergelaufen |

**Gegenprobe gefahren:** mit der alten festen Box fallen vier der sechs Tests.

Den Verzerrungstest mit quadratischem *und* hochkantem Wappen nebeneinander haben wir
übernommen — beide stecken im Testaufbau.

---

## Eine Richtigstellung zu unseren Gunsten, nicht zu euren

In einer Zwischennotiz hatten wir euch einen Zählfehler zugeschrieben: ihr schreibt „dasselbe
Literal steht an **sechs weiteren** Stellen", wir hatten acht gezählt. **Euer Satz war
richtig** — sechs weitere plus die zwei im Teaser sind acht gesamt. Nachgezählt:

```
im _teaser:      2  (jetzt 0)
in den anderen:  6  (_player_score_panel 103/118, _snooker_scoreboard 76/300,
                     _pool_scoreboard 57/313)
```

Sorry für das Rauschen.

---

## Was wir *nicht* gemacht haben

**Die sechs weiteren Stellen.** Wie von euch vorgesehen: andere Kontexte (Vollbild, eigene
`vw3`/`vw6`-Variablen, anderes Layout), der passende `em`-Faktor ist dort nicht automatisch
1,4, und es bräuchte je Ansicht einen eigenen Augenschein. Unangetastet.

**Die festen Polster** (`p-3`, `p-1`, `ml-2`, `m-10`). Euer Nebenbefund 1 — eine optische
Entscheidung, kein Fehler-Fix, und sie verschiebt das Layout in beiden Views sichtbar. Nicht
angefasst.

**Das fehlende `>` in Zeile 43.** Euer Nebenbefund 2, von uns bestätigt:

```erb
<%= "#{t("table_monitor.inning")} <strong class='text-2vw'>#{…}</strong".html_safe %>
```

Ein Einzeichen-Fix, aber ein anderer Fehler als dieser hier. Er gehört in einen eigenen Commit,
damit man ihn im Zweifel allein zurücknehmen kann — bei einer Änderung, die die
`<td>`/`<tr>`-Verschachtelung berührt, ist das kein Pedanterie-Argument. Sagt Bescheid, dann
kommt er separat.

---

## Was noch zu tun ist

1. **Deploy** auf bc-wedel — beim Betreiber. Danach sind beide Fixes drüben.
2. **Augenschein auf dem Saalmonitor.** Die `em`-Auflösung passiert im Browser; kein Test
   ersetzt den Blick aus Zuschauerentfernung. Eure Erwartungstabelle (40 px → 161 px bei
   3840 px / 3 vw) ist der Maßstab.
3. **Die CSS-Breite des Samsung-TV messen**, falls es jemanden interessiert: ihr habt offen
   gelassen, ob er 1920 px mit `devicePixelRatio: 2` oder 3840 px meldet. Für den Fix ist es
   gleichgültig — der `em`-Wert stimmt in beiden Fällen —, aber es würde die Erwartungswerte
   schärfen. `window.innerWidth` im TV-Browser.

**Ein Hinweis zur Reihenfolge, der sich bestätigt hat:** euer Abschnitt zur Wechselwirkung war
der Grund, beide zusammen auszuliefern. Der Raster-Fix allein hätte den Saalmonitor beim
nächsten Turnier *schlechter* gemacht als vorher — größere Schrift, gleich kleine Wappen, also
Verhältnis 0,69 statt 1,04. Dass ihr das selbst durchgerechnet und mitgeschickt habt, hat eine
Fehlentscheidung auf unserer Seite verhindert.
