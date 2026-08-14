# CI dauerhaft rot: zwei konkurrierende Workflows, einer strukturell defekt

**Erfasst:** 2026-08-14 · **Status:** offen
**Dringlichkeit:** mittel — kein Produktionsrisiko, aber die CI hat als Signal keinen Wert

## Symptom

Jeder PR zeigt gemischte Checks, z. B. bei PR #67:

```
lint   fail   ← .github/workflows/ci.yml
scan   fail   ← .github/workflows/ci.yml
test   fail   ← .github/workflows/ci.yml
build  pass   ← build-docs.yml
lint   pass   ← .github/workflows/tests.yml
test   pass   ← .github/workflows/tests.yml
```

Es existieren **zwei** Workflows mit gleichnamigen Jobs (`ci.yml` und `tests.yml`), die
gegensätzliche Ergebnisse liefern. In der PR-Ansicht steht `lint` und `test` deshalb je
zweimal — einmal grün, einmal rot.

## Ursachen (getrennt betrachten)

**1. `ci.yml` → `test` startet gar nicht.**
`.github/workflows/ci.yml:85` setzt `node-version-file: '.node-version'`, aber diese Datei
existiert im Repo **nicht**:

```
##[error]The specified node version file at: /home/runner/work/carambus/carambus/.node-version does not exist
```

Der Job bricht bereits im `Setup Node`-Schritt ab. **Der rote Haken bedeutet also nicht
„Tests fehlgeschlagen", sondern „nie ausgeführt".** Das ist die gefährlichste Variante:
Ein echter Testfehler wäre von einem Setup-Abbruch nicht zu unterscheiden.

**2. `ci.yml` → `lint` meldet repo-weite Altlasten.**
`bundle exec standardrb` (ohne Einschränkung auf geänderte Dateien) findet mehrere hundert
Verstöße in Bestandscode — überwiegend `Style/RescueStandardError`, `Layout/TrailingWhitespace`,
`Style/StringLiterals`. Beispiele quer durchs Repo: `app/controllers/api/ai_docs_controller.rb`,
`app/controllers/clubs_controller.rb`, `app/helpers/application_helper.rb`.

Solange dieser Job pauschal läuft, ist er dauerhaft rot und damit wertlos.

**3. `scan` (`bin/brakeman`, `ci.yml:26`) schlägt ebenfalls fehl** — nicht weiter untersucht.

## Warum das zählt

Während dieser Sitzung wurde CI als Entscheidungsgrundlage herangezogen („darf ich PR #67
mergen?"). Die Antwort ließ sich **nicht** an den Checks ablesen, sondern nur durch
manuelles Lesen der Job-Logs. Genau das soll CI abnehmen.

Konkret: Der Security-Fix `99ce08b9` (Absicherung des Administrate-Bereichs) wurde **ohne
verwertbares CI-Signal** gemergt — die lokalen Testläufe waren die einzige Absicherung.

## Mögliche Wege

| Ansatz | Bemerkung |
|---|---|
| `.node-version` anlegen | Kleinster Schritt; macht `ci.yml/test` überhaupt lauffähig. Danach zeigt sich, ob die Tests dort grün sind. Version an `tests.yml` angleichen. |
| Einen der beiden Workflows abschalten | `ci.yml` und `tests.yml` überlappen sich (beide `lint` + `test`). Doppelte Jobs mit gegensätzlichem Ergebnis sind der eigentliche Konstruktionsfehler. |
| `standardrb` nur auf geänderte Dateien | Macht Lint sofort brauchbar, ohne den Bestand aufräumen zu müssen. |
| Bestand aufräumen (`standardrb --fix`) | ~305 automatisch behebbare Verstöße; erzeugt einen sehr großen, aber mechanischen Diff. Getrennt von jeder inhaltlichen Änderung fahren. |

Empfehlung: erst entscheiden, **welcher** der beiden Workflows der maßgebliche sein soll,
und den anderen entfernen. Alles andere kuriert Symptome.

## Belege

- Fehlgeschlagener Run: `31795968924` (Jobs `lint`, `scan`, `test`)
- Grüner Run derselben Commits: `31795968909` (Jobs `lint`, `test`)
- Auf `master` liefen zuletzt am 2026-08-09 Runs (`9e060b44`); die Pushes vom 2026-08-14
  (`67dfa40f`, `098fce80`, `99ce08b9`) erzeugten keine sichtbaren Master-Runs — ebenfalls
  klärungsbedürftig, ggf. Trigger-Konfiguration.
