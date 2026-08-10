# UMB-Scraping: Betrieb und Wartung

Diese Seite beschreibt, was beim UMB-Scraping **automatisch** läuft, welche
**Sonderaktionen** es gibt und **wann** man sie braucht. Die Methoden-Referenz
steht in [UMB Scraping Methoden](umb-scraping-methods.md).

Alle Befehle laufen auf der Authority (`api.carambus.de`) im Release-Verzeichnis:

```bash
cd ~/carambus_api/current
RAILS_ENV=production /var/www/.rbenv/shims/bundle exec rails <task>
```

---

## Was automatisch läuft

| Wann | Task | Was er tut |
|---|---|---|
| täglich 03:00 | `umb:update` | Übersichtsseite scrapen, neue Turnier-IDs suchen, Ergebnisse und Spielerlisten nachladen |

Konfiguriert in `config/schedule.rb` (whenever, Rolle `:api`).

`umb:update` arbeitet in vier Schritten:

1. **Übersicht** — `FutureTournaments.aspx`; legt neue Termine an. Der Zähler
   nennt nur *neu gespeicherte* Turniere; „0" heißt also in der Regel „alles
   schon bekannt", nicht „nichts gefunden".
2. **Neue IDs** — prüft oberhalb der höchsten bekannten `external_id`.
3. **Organizer** — trägt fehlende UMB-Zuordnungen nach.
4. **Ergebnisse** — lädt für bis zu 50 Turniere die Detailseite samt PDFs
   (`parse_pdfs: true`) und legt daraus Seedings und Games an.

!!! note "Warum manche Turniere bei jedem Lauf erneut auftauchen"
    Schritt 4 wählt Turniere über `games.empty? || detail_scraped_at.nil?`.
    Turniere ohne Ergebnis-PDFs bekommen nie Games und erfüllen die Bedingung
    dauerhaft. Seit 2026-08 werden sie nach **Terminnähe** sortiert, damit die
    Quote nicht von Terminen aus 2027–2030 aufgebraucht wird — vorher standen
    genau die vorne und lieferten erwartungsgemäß nichts.

---

## Sonderaktionen

Alle laufen ohne Parameter als **Trockenlauf** und schreiben erst mit `ARMED=1`
bzw. `FIX=1`. Vor schreibenden Läufen ein Backup ziehen:

```bash
pg_dump -Uwww_data carambus_production > ~/carambus_production_$(date +%Y%m%d_%H%M).sql
```

### `umb:verify_dates` — Datumsabgleich

Vergleicht das gespeicherte Datum mit der UMB-Detailseite.

```bash
rails umb:verify_dates          # melden
rails umb:verify_dates FIX=1    # Datum auf den UMB-Wert setzen
rails umb:verify_dates ALL=1    # gesamter Bestand statt Matcher-Fenster
```

**Wann:** nach größeren Scrape-Läufen, mindestens vierteljährlich.

**Warum es zählt:** Datumsfehler wirken sich in der Video-Zuordnung am stärksten
aus — das Datum ist dort mit Gewicht 0,40 das schwerste Signal. Ein Turnier mit
falschem Datum zieht Videos an, die es nie betroffen haben. Realfall 2026-08:
„UMB 3-Cushion World Masters" stand mit 2026-03-31 im Bestand, während UMB zur
selben ID 2020-03-31 und `CANCELLED / BOGOTA` lieferte; es zog 21 Videos eines
ganz anderen Turniers an.

!!! tip "UMB führt den Turnierstatus im Ortsfeld"
    Es gibt kein eigenes Statusfeld — Absagen und Verschiebungen stehen als
    `CANCELLED / …` bzw. `POSTPONED - …` im Ort. Der Task weist darauf hin.

### `umb:dedupe_tournaments` — Dubletten zusammenführen

```bash
rails umb:dedupe_tournaments                      # zeigen
rails umb:dedupe_tournaments ARMED=1              # zusammenführen
rails umb:dedupe_tournaments PURGE_DEAD=1 ARMED=1 # zusätzlich zurückgezogene Turniere löschen
```

Gruppiert streng nach identischem Titel **und** Datum. Behalten wird der
Datensatz mit `external_id` — nur über ihn lässt sich die Detailseite nachladen.
Games, Seedings und Videos werden **vor** dem Löschen umgehängt (sie hängen mit
`dependent: :destroy` am Turnier).

Gruppen mit **mehreren** `external_id`s werden nicht angefasst, sondern gemeldet.
`PURGE_DEAD=1` prüft sie live gegen UMB und löscht sie nur, wenn dort keine der
IDs mehr existiert und nichts daran hängt.

**Wann:** wenn `umb:update` viele „Failed to update" meldet. Diese Fehler
stammen fast immer von Dubletten ohne `external_id` — ohne sie lässt sich keine
Detail-URL bilden.

**Vorsicht:** Die Ursache ist behoben (der Ort ist kein Duplikat-Filter mehr).
Tauchen erneut Dubletten in Serie auf, ist das ein Hinweis auf ein neues
Ausgabeformat der UMB-Seite — dann erst die Ursache prüfen, nicht nur aufräumen.

### `umb:fix_states` — Datum und Status abgleichen

```bash
rails umb:fix_states            # zeigen
rails umb:fix_states ARMED=1    # korrigieren
```

Setzt `state` auf `planned` bzw. `finished`, passend zum Turnierdatum.

**Wann:** nach dem Import älterer Bestände.

!!! note "`planned`/`finished` sind keine AASM-States"
    Die internationalen Scraper führen eine eigene Konvention; die
    Tournament-Statemaschine kennt `tournament_finished`, `closed` usw. Deshalb
    schreibt der Task mit `update_columns` statt über AASM-Events.

---

## Video-Zuordnung

### `videos:match_tournaments_dry_run` — Trockenlauf

```bash
rails videos:match_tournaments_dry_run
rails videos:match_tournaments_dry_run LIMIT=5000 THRESHOLD=0.80
rails videos:match_tournaments_dry_run SHOW_ALL=1
```

Rechnet exakt wie der schreibende Lauf (er ruft `confidence_score` selbst auf),
schreibt aber nichts. **Immer vor dem echten Lauf ausführen** — dieser ordnet
zehntausende Videos automatisch zu, und eine Fehlzuordnung fällt später kaum auf.

Worauf zu achten ist:

- **Verteilung je Turnier** — ein Ausreißer deutet auf ein Turnier mit falschem
  Datum, das Videos anderer Veranstaltungen anzieht.
- **Mehrdeutige Fälle** — bester und zweitbester Treffer fast gleichauf.
- **Titel-Ähnlichkeit** — die Warnung bei < 0,20 ist ein *Hinweis*, kein Fehler:
  Turniertitel („World Cup 3-Cushion") und Videotitel („F. CAUDRON vs M. HORN")
  ähneln sich naturgemäß kaum. Verdächtig wird es, wenn ein Videotitel eine
  andere Veranstaltung nennt (Ligaspiele, Re-Uploads alter Turniere).

### `videos:match_tournaments` — schreibender Lauf

Vorher die betroffenen IDs sichern, dann läuft er umkehrbar:

```bash
rails runner 'File.write("/var/www/video_ids_vor_match.txt", Video.where(videoable_id: nil).where.not(published_at: nil).pluck(:id).join("\n"))'
rails videos:match_tournaments
```

Rückgängig machen:

```bash
rails runner 'ids=File.readlines("/var/www/video_ids_vor_match.txt").map(&:to_i); puts Video.where(id: ids).where.not(videoable_id: nil).update_all(videoable_id: nil, videoable_type: nil)'
```

`Video` ist versioniert (PaperTrail über `LocalProtector`), die Zuordnungen sind
also auch ohne diese Datei nachvollziehbar.

!!! warning "Die Zuordnung braucht Seedings"
    Das Spieler-Signal wiegt 0,35; ohne Seedings liegt das erreichbare Maximum
    bei 0,65 und damit unter der Schwelle von 0,75. Turniere ohne
    Teilnehmerliste können also **keine** Videos zugeordnet bekommen. Die
    Seedings entstehen in Schritt 4 von `umb:update` aus den PDFs — Turniere ohne
    Ergebnis-PDFs bleiben dauerhaft ohne.

---

## Wiederkehrende Routine

| Rhythmus | Aktion |
|---|---|
| täglich (automatisch) | `umb:update` per Cron |
| nach jedem größeren Turnier | `videos:match_tournaments_dry_run`, bei plausiblem Ergebnis `videos:match_tournaments` |
| vierteljährlich | `umb:verify_dates`, `umb:dedupe_tournaments` (Trockenlauf) |
| bei auffälligen Fehlerzahlen im Cron-Log | siehe Fehlerbilder unten |

---

## Fehlerbilder

**„Failed to update" in Serie** — Dubletten ohne `external_id`.
`umb:dedupe_tournaments` prüfen und ausführen.

**„Current max external_id" wirkt zu klein** — `external_id` ist eine
String-Spalte; ein SQL-`MAX()` darauf vergleicht lexikografisch und liefert
„99" statt 419. Im Task numerisch gecastet (`UMB_MAX_EXTERNAL_ID`); tritt der
Effekt in eigenen Abfragen auf, dort ebenso casten.

**Lücken im ID-Bereich** — der Task sucht nur oberhalb des Maximums. Fehlende
IDs darunter werden nie nachgeholt (Stand 2026-08: 62 Lücken unter 419, davon
laut Stichprobe rund ein Fünftel echte Turniere). Ein Lückenscan existiert nicht.

**HTTP 500 auf einer Detailseite** — bedeutet bei UMB „ID existiert nicht"; es
gibt keine 404-Antwort. Der Scraper behandelt es korrekt als „nicht gefunden".

**Video-Trockenlauf meldet 0 Zuordnungen** — normal, wenn die passenden Videos
bereits zugeordnet sind. Der Lauf betrachtet nur Videos mit `videoable_id: nil`.
