# Fallstricke

Gesammelte Lehren aus der Arbeit am Carambus-Code und an seiner Werkzeugkette — jede eine, die
mindestens einmal Zeit gekostet hat, weil sie **still** zuschlägt: kein Fehler, keine Meldung,
nur ein falsches Ergebnis, das plausibel aussieht.

Diese Seite ist getrackt. Sie kommt per `git pull` in jeden Checkout und steht dort in jeder
Sitzung zur Verfügung — anders als das Gedächtnis eines einzelnen Arbeitsverzeichnisses, das
nur dort sichtbar ist, wo es entstanden ist.

**Jeder Eintrag nennt seinen Beleg** — eine Datei mit Zeilennummer oder ein nachvollziehbares
Verhalten. Ohne Beleg ist eine Regel beim nächsten Leser nicht überprüfbar und wird irgendwann
zum Aberglauben.

Hier stehen nur Lehren über **Code und Werkzeuge**. Betriebliches (Hosts, Zugänge, Datenstände)
gehört nicht in ein öffentliches Repo.

---

## Shell und Werkzeugkette

### Die Agent-Shell ist zsh, nicht bash

Unquotiertes `$VAR` wird in zsh **nicht** in Wörter zerlegt. Eine Schleife über eine Liste läuft
deshalb genau einmal statt *n*-mal — und die Prüfung darüber meldet „bestanden".

```bash
V='a b'; n=0; for x in $V; do n=$((n+1)); done; echo $n   # zsh: 1,  bash: 2
```

**Beleg:** `ps -p $$ -o comm=` liefert `/bin/zsh`.
**Ausweg:** Array bauen (`ARR=(${(f)"$(cmd)"})`) oder explizit `${=VAR}`. Bei Zählungen immer
„N von M" ausgeben und gegen die erwartete Zahl halten.

### `grep` ohne Treffer endet mit Exit 1

Das ist kein Fehler, sondern die Definition: „nichts gefunden". In einem Skript mit
`set -euo pipefail` reicht es aber, um den Lauf **ohne Meldung** zu beenden.

```bash
echo hallo | grep -v hallo   # Exit 1
```

Besonders tückisch in einer Pipeline zum Filtern:
`cmd | grep -v muster | wc -l` liefert mit `pipefail` den Status 1, sobald `grep` nichts
durchlässt — also ausgerechnet im *sauberen* Fall.

**Ausweg:** `awk '!/muster/'` statt `grep -v`; awk kennt „keine Zeile passte" nicht als
Misserfolg. Muss es grep sein: `|| true` an die Pipeline.

### Ein `grep`-Muster mit führendem `-` wird zur Option

`grep -qxF "$s"` mit `s=-Users-...` liest das Argument als Optionsbündel. Der Treffer bleibt dann
für immer aus — und bei einem `-V` im Namen druckt grep seine Versionsnummer mitten in die
Ausgabe.

**Ausweg:** das Muster immer als `grep -e "$s"` übergeben.

### `comm` braucht dieselbe Kollation wie `sort`

`LC_ALL=C sort` allein genügt nicht — `comm` selbst muss ebenfalls unter `LC_ALL=C` laufen.
Sonst vergleicht es nach einer anderen Ordnung als der, in der sortiert wurde, und meldet fast
alles als einseitig.

**Beleg:** dieselben zwei Dateilisten ergaben ohne `LC_ALL=C` beim `comm` **229** einseitige
Einträge, mit `LC_ALL=C` **5**. Die falsche Zahl ist plausibel groß und damit gefährlicher als
ein Absturz.

### BSD-`tar --exclude` ist nicht verankert

Ein Muster trifft auch **nachlaufende** Pfadkomponenten. `--exclude archive` und
`--exclude ./archive` verwerfen beide auch `handoffs/archive/`.

**Beleg:** ein Kopierlauf zählte 156 Dateien, eine frühere Messung 134 — die Differenz war genau
die Zahl der Dateien unterhalb eines *tieferen* `archive/`.
**Ausweg:** vollständig kopieren und danach **verankert** beschneiden (`rm -rf "$ziel/archive"`).
Dasselbe gilt für `diff -x`.

### `git status --porcelain` fasst unverfolgte Verzeichnisse zusammen

Ein unverfolgtes Verzeichnis erscheint als **eine** Zeile, gleichgültig wie viele Dateien darin
liegen. 673 Dateien sahen so wie ein einzelner Eintrag aus — und der wurde für einen bekannten,
harmlosen gehalten.

**Ausweg:** `git status --porcelain -uall`, wann immer die Zahl zählt.

### Ein `case`-Muster in `$( … )` braucht eine führende Klammer

Innerhalb einer Kommandosubstitution kann die schließende Klammer eines `case`-Musters die
Substitution vorzeitig beenden.

```bash
x=$( case "$v" in (*muster*) echo ja ;; esac )   # mit '(' korrekt
```

Dieselbe Zeile funktioniert außerhalb von `$( … )` tadellos — der Fehler fällt deshalb spät auf.

### `timeout(1)` und `flock(1)` gibt es auf macOS nicht

Beide fehlen, auch als `gtimeout`, sofern die GNU-Coreutils nicht installiert sind.

**Ausweg für eine Sperre:** `mkdir` ist atomar — von zwei gleichzeitigen Aufrufen kann nur einer
gewinnen. Dazu eine Altersprüfung, damit eine verwaiste Sperre nicht ewig blockiert.

### Overcommit stasht den Arbeitsbaum vor jedem Hook-Lauf

Bricht der Lauf ab, liegt die Arbeit in `stash@{0}` — und `git status` meldet einen **sauberen**
Baum. Wer das für Erfolg hält, committet nichts und merkt es nicht.

**Ausweg:** `git stash list | wc -l` als Kontrollgröße vor und nach dem Commit; bei Merges
`OVERCOMMIT_DISABLE=1` setzen und Lint sowie Tests von Hand fahren. Niemals blind `stash pop`.

---

## Rails und Anwendungscode

### `Game#data` ist überschrieben — Zuweisung ist ein stilles No-op

`app/models/game.rb:95` überschreibt den Lesezugriff und baut den Hash bei jedem Aufruf neu auf.
`game.data["x"] = y` verändert deshalb nur eine weggeworfene Kopie; gespeichert wird nichts, und
es gibt keinen Fehler.

**Ausweg:** `deep_merge_data!` verwenden. Die Methode existiert in zehn Modellen.
**Achtung:** `TableMonitor` hat diese Überschreibung **nicht** — dort verhält sich `data` normal.
Das Gegenbeispiel im selben Projekt ist der Grund, warum die Regel so leicht vergessen wird.

### CableReady `morph` braucht `children_only: true`

Ohne das Flag morpht CableReady das adressierte Element **selbst** und zerstört dabei dessen
`id` — der nächste Aufruf findet den Container nicht mehr.

**Beleg:** `app/reflexes/game_protocol_reflex.rb:457` (Begründung) und `:469` (Verwendung).

### `nil.to_i` ist 0

Ein blinder `to_i`-Vergleich behandelt „kein Wert" wie „Wert 0". Bei Rundenvergleichen heißt das
„kleiner als Runde 1" — ein nicht rundengeführtes Turnier wäre damit vollständig gesperrt.

**Ausweg:** zuerst `present?` bzw. `blank?` prüfen, dann vergleichen.
**Beleg:** `app/controllers/tournament_monitors_controller.rb:356`.

### `scenarios.rake` löscht das Rails-Root ohne Rückfrage

`lib/tasks/scenarios.rake:2538` führt `FileUtils.rm_rf(rails_root)` aus, wenn das Verzeichnis
existiert — aufgerufen aus zwei Stellen weiter unten. Alles, was dort liegt und nicht im Git
ist, ist danach weg.

### Die Geheimnis-Wache sieht nur getrackte Dateien

`lib/burned_secret_guard.rb` sammelt ihre Kandidaten mit `git ls-files` — gitignorierte Pfade
sind damit strukturell außerhalb des Scans, auch wenn dort Geheimnisse liegen.

**Ausweg:** die Wache nimmt Pfade als Argument. Für einen ignorierten Baum:

```bash
find <pfad> -type f -print0 | xargs -0 ruby bin/burned-secret-guard
```

**Und ihre Grenze:** sie prüft gegen eine Liste **bekannter verbrannter** Fingerprints. Ein
Geheimnis, das noch niemand gemeldet hat, findet sie nicht. Neuer Inhalt braucht einen
Lesedurchgang, keinen Automatismus.

---

## Methode

### Beide Seiten einer Bedingung testen

Ein Test, der nur den positiven Fall abdeckt, ist von `true` nicht zu unterscheiden. Dieselbe
Lücke hat einen Hinweis in der Oberfläche zweimal hintereinander falsch werden lassen: erst hing
er an einem Zustand statt an einem Ereignis, dann an „wurde geschrieben" statt an „wurde
geändert" — beide Male sah der grüne Test danach gleich aus.

Ebenso bei Werkzeugen: eine Löschfunktion, die im Testfall nichts löscht, beweist nichts, solange
nicht ein Fall existiert, in dem sie löschen **muss**.

### Zwei abweichende Zählungen desselben Dings sind ein Befund

Kein Rundungsfehler, keine Ungenauigkeit — ein Hinweis auf einen Fehler in einer der beiden
Messungen. Der `tar`-Fehler oben wurde ausschließlich dadurch sichtbar.

### Die Herkunft einer Zahl prüfen, bevor man die Differenz deutet

Weicht eine Messung von einer dokumentierten Zahl ab, ist die erste Frage nicht „warum die
Differenz?", sondern „wie wurde die dokumentierte Zahl ermittelt?". Misst sie einen Bestand oder
eine Veränderung? Zählt sie dasselbe mit?

**Beleg:** 580 Dateien schienen nur auf einem Rechner zu existieren. Nach drei Korrekturen an der
Messung blieben 15 — die übrigen lagen längst am Ziel, nur in einem Verzeichnis, das die
Erhebung bewusst ausgeschlossen hatte.
