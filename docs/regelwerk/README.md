# Regelwerk

Verbandsordnungen, gegen die die Turnierabwicklung geprueft wird.

| Datei | Inhalt | Stand | Geltungsbereich |
|-------|--------|-------|-----------------|
| `nbv-sport-turnierordnung-karambol-2026-06.pdf` | NBV Sport- & Turnierordnung, Besonderer Teil Karambolage | Juni 2026 | **nur NBV, nur Karambol** |

## Herkunft

Heruntergeladen am 2026-09-03 von <https://ndbv.de/downloads.php?p=20-8-21-->
("01 NBV Satzung und Ordnungen" → "03 NBV Sportordnungen"), Originalname
`04_Sport- Turnierordnung-BT-Karambol (2026_06).pdf`.

Die Datei liegt hier als Kopie, weil die Ordnung jaehrlich neu veroeffentlicht wird und
Plaene den jeweils geprueften Stand zitieren muessen. Bei einer neuen Ausgabe die alte
Datei **behalten** und die neue mit ihrem Stand daneben legen — sonst laesst sich nicht
mehr nachvollziehen, gegen welche Fassung eine Implementierung geprueft wurde.

## Andere Verbaende

Andere Landesverbaende haben eigene Ordnungen. Sie werden derzeit **nicht** unterstuetzt;
der Code darf NBV-Regeln vorerst als gegeben annehmen. Sollte das aufgeweicht werden,
gehoert die Verbandszugehoerigkeit zuerst zu einem expliziten Parameter gemacht.

## Text durchsuchen

Das PDF ist nicht grepbar. Bei Bedarf eine Textfassung erzeugen (nicht einchecken):

```bash
pdftotext docs/regelwerk/nbv-sport-turnierordnung-karambol-2026-06.pdf - | less
```
