# Handoffs zwischen Turnier-App und Carambus

Hier liegen die Übergabedokumente zwischen den beiden Seiten der Turnier-App:

| Dateiname beginnt mit | Richtung | geschrieben von |
|---|---|---|
| `HANDOFF-to-carambus-…` | App → Carambus | der App-Seite: Befund, Analyse, Empfehlung |
| `HANDOFF-from-carambus-…` | Carambus → App | der Carambus-Seite: was gebaut wurde, was nicht, und warum |

Zusammengehörige Dokumente tragen **dasselbe Thema im Namen** und verweisen aufeinander. Die
Dateinamen sind deshalb Teil des Inhalts — beim Verschieben oder Umbenennen bitte die Verweise
in den Dokumenten mitziehen.

## Warum sie seit 2026-10-18 hier liegen

Die Turnier-App war bis zum 2026-09-13 ein eigenes Repo (`3band-turnier`) und ist mit
`53bcfbf0` als `tournament_app/` ins Carambus-Repo gewandert. Entwickelt wird weiter im
Standalone-Checkout `carambus_app`, und die Arbeit kommt einzeln herüber — die Commits tragen
dann `(aus carambus_app <sha>)` im Betreff.

**Die Handoffs sind bei diesem Umzug liegengeblieben.** Das alte Remote wurde am 2026-09-17
archiviert und ist seither schreibgeschützt; alles, was danach im Standalone-Checkout entstand,
lag nur auf einer Platte — auch die Anfragen vom 17. und 18.10., die zwei Tage Analyse
enthalten.

Deshalb ist dieser Ordner der neue Ort: **hier sind die Dokumente versioniert, pushbar und in
jedem Carambus-Checkout zu finden.**

## Was hier (noch) nicht liegt

Die **40 älteren Handoffs** aus der Zeit der zwei Repos (Mai bis August 2026) stehen weiter in
`carambus_app/` im Standalone-Checkout. Sie sind erledigt und beantwortet; sie nachzuholen ist
eine eigene, unabhängige Aufgabe.

⚠️ Wer dort nachsieht: dieser Checkout lässt sich nicht pushen. Neue Dokumente gehören in
diesen Ordner, nicht dorthin.
