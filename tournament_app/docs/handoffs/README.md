# Handoffs zwischen Turnier-App und Carambus

Hier liegen die Übergabedokumente zwischen den beiden Seiten der Turnier-App:

| Dateiname beginnt mit | Richtung | geschrieben von |
|---|---|---|
| `HANDOFF-to-carambus-…` | App → Carambus | der App-Seite: Befund, Analyse, Empfehlung |
| `HANDOFF-from-carambus-…` | Carambus → App | der Carambus-Seite: was gebaut wurde, was nicht, und warum |

Zusammengehörige Dokumente tragen **dasselbe Thema im Namen** und verweisen aufeinander. Die
Dateinamen sind deshalb Teil des Inhalts — beim Verschieben oder Umbenennen bitte die Verweise
in den Dokumenten mitziehen.

## Warum einige davon hier liegen und andere nicht

Die Turnier-App war bis zum 2026-09-13 ein eigenes Repo (`3band-turnier`, privat) und ist mit
`53bcfbf0` als `tournament_app/` ins Carambus-Repo gewandert. Bis Oktober 2026 wurde weiter im
Checkout `carambus_app` entwickelt und die Arbeit einzeln herübergeholt — diese Commits tragen
`(aus carambus_app <sha>)` im Betreff. **Seit 2026-10-20 ist `carambus_app` stillgelegt:**
der Code liegt nur noch hier in `tournament_app/`.

**Hier liegen die Handoffs zu Fixes, die in DIESEM Repo stehen.** Wer in fünf Jahren wissen
will, warum in `_teaser.html.erb` ein `1.4em` statt einer Pixelzahl steht, sucht neben dem
Code — nicht in einem zweiten Repo. Die beiden Antwortdokumente erklären `32617de2` und
`fc69e12b`; die zugehörigen Anfragen stehen daneben, weil eine Antwort ohne ihre Frage nicht
lesbar ist.

**Die vollständige Historie liegt im App-Repo.** Dort stehen alle 44 Dokumente, auch die 40
älteren aus der Zeit der zwei Repos (Mai bis August 2026). Sie bleiben dort, und zwar aus einem
inhaltlichen Grund: viele nennen Hosts, interne IP-Adressen, Service-Account-Adressen und
Abläufe mit Bearer-Tokens. **Das Carambus-Repo ist öffentlich**, das App-Repo privat — und
Betriebliches gehört in kein öffentliches Repo (siehe `docs/developers/fallstricke.de.md`).

Die vier Dokumente hier sind daraufhin geprüft: keine Hosts, keine IP-Adressen, keine
Zugangsdaten. Sie handeln von ERB-Zeilen, Pixelmaßen und den Wappen-URLs der Verbandsseiten.

## Wenn ein neues Handoff dazukommt

1. Es entsteht **hier** in `tournament_app/docs/handoffs/` (nicht mehr in `carambus_app`).
2. **Vorher prüfen, was drinsteht.** Ein Blick auf Hosts, IP-Adressen, Zugangsdaten und
   Token-Abläufe. Die Geheimnis-Wache (`bin/burned-secret-guard`) prüft nur 32 *bekannte*
   verbrannte Fingerprints — ein unbekanntes Zugangsdatum als Prosa findet sie nicht.
