---
name: scenario-management
description: Regelt die Arbeit in den mehreren Carambus-Checkouts (carambus_bcw, carambus_api, carambus_phat, carambus_nbv, carambus_gu) — ein Repository, mehrere gleichberechtigte Arbeitsverzeichnisse. Use when modifying code, committing, creating feature branches, coordinating between scenarios, or when the user mentions scenarios or deployments.
---

# Scenario Management

**Ein Git-Repository, mehrere Checkouts — einer je Szenario.** Sie sind **gleichberechtigt**:
Es gibt keinen ausgezeichneten Ort, an dem Code entstehen müsste. Was zählt, ist
`origin/master`.

```
/Users/gullrich/DEV/carambus/
├── carambus_api/      # Authority
├── carambus_bcw/      # BC Wedel — lokaler Server
├── carambus_phat/     # PHAT — lokaler Server
├── carambus_nbv/      # NBV — ClubCloud-Pflege
├── carambus_gu/       # Trainingssystem
└── carambus_data/     # Szenario-Konfigurationen (keine Code-Edits erwartet)
```

---

## Die eine Regel

> **Nicht an mehreren Stellen gleichzeitig dieselbe Sache ändern.**

Alle Szenarien basieren auf derselben Carambus-Basis. Von wo aus committet und gepusht wird,
ist gleichgültig — der eigentliche Fehler ist **Mehrfach-Bearbeitung**, nicht der Checkout
selbst. Zwei Checkouts, die parallel dieselbe Datei anfassen, erzeugen Konflikte, die niemand
mehr sauber auflösen kann.

*(Betreiber-Formulierung vom 2026-06-07, seit v0.3.5 die Kernregel dieses Skills.)*

Daraus folgt alles Weitere:

- **Vor dem ersten Edit ansagen, wo gearbeitet wird.** Ein Satz genügt: „Ich arbeite in
  `carambus_bcw` auf `scenario/bcw/<topic>`." Das ist ein Abgleich, kein
  Genehmigungsverfahren — „ja, hier weiterarbeiten" ist die übliche Antwort.
- **Läuft anderswo schon etwas am selben Thema, erst dort abschließen.** Ein halbfertiger
  Stand in einem anderen Checkout ist der einzige Grund, den Ort zu wechseln.

---

## Wo eine Änderung ihre Heimat hat

Eine **Voreinstellung, keine Sperre**. Sie sagt, wo eine Änderung sinnvoll getestet werden
kann und wer sie kennt — nicht, dass ein anderer Checkout sie nicht machen dürfte.

| Checkout | Heimat für |
|---|---|
| `carambus_api` | Globale Records (`id < MIN_ID`), Authority-Logik, Scraping der Verbandsquellen |
| `carambus_bcw`, `carambus_phat` | Lokaler Spielbetrieb am jeweiligen Standort (`id >= MIN_ID`), Scoreboards, TableMonitor |
| `carambus_nbv` | ClubCloud-Pflege des NBV |
| `carambus_gu` | Trainingssystem |
| **kein bestimmter** | **Szenarioübergreifendes**: `rake scenario:*`, `bin/`-Skripte, `.agents/skills/`, CI-Workflows, `docs/` |

Belegt aus den `.paul/PROJECT.md` der jeweiligen Checkouts. Der entscheidende Punkt: **Wer
etwas ändert, sollte es testen können.** Authority-Code testet man in `carambus_api`,
Spielbetrieb an einem lokalen Server-Szenario — dort steht die passende Datenbank.

**Szenarioübergreifendes hat keine Heimat** — Werkzeuge, Skills, CI und Doku betreffen alle
Checkouts gleichermaßen. Sie werden dort geändert, wo gerade gearbeitet wird. Dafür wiegt die
Regel oben umso schwerer: Weil eine solche Änderung **jeden** Checkout erreicht, ist eine
parallele Bearbeitung an zwei Stellen hier besonders teuer. Ansagen, dann anfangen.

---

## Feature-Branches

Bewährt und in Gebrauch — aktuell 15 Branches aus vier Szenarien.

**Namenskonvention (verbindlich):**

```
scenario/<szenario>/<topic>
```

Beispiele: `scenario/bcw/rfid-table-monitor`, `scenario/api/disk-cleanup`,
`scenario/phat/streaming-overlay`. Das Präfix macht auf einen Blick sichtbar, welcher
Checkout den Branch angelegt hat, und verhindert versehentliches Auschecken im falschen Baum.

**Wann ein Feature-Branch, wann direkt auf `master`:**

| Situation | Weg |
|---|---|
| Riskanter Umbau, längere Arbeit, mehrere Schritte | Feature-Branch |
| Etwas, das erst am echten Szenario getestet werden muss | Feature-Branch |
| Kleiner, klar abgegrenzter Fix | Direkt auf `master` ist in Ordnung |

**Anlegen:**

```bash
cd /Users/gullrich/DEV/carambus/<szenario>
git fetch origin
git checkout -b scenario/<szenario>/<topic> origin/master
# … Edits, Tests, Commits …
git push -u origin scenario/<szenario>/<topic>
```

**Drift vermeiden:** Mindestens wöchentlich oder vor jedem größeren Commit `origin/master`
in den Branch mergen. Konflikte werden **im Feature-Branch** gelöst, nie auf `master`.

```bash
git fetch origin master
echo "$(git rev-list --count HEAD..origin/master) Commits hinter master"
git merge --no-ff origin/master -m "Merge master into scenario/<szenario>/<topic>"
```

---

## Merge zurück nach master

**Der Merge findet in dem Checkout statt, in dem du gerade arbeitest.** Es gibt keinen
Checkout, in den man dafür wechseln müsste.

```bash
cd /Users/gullrich/DEV/carambus/<szenario>
git checkout scenario/<szenario>/<topic>
git fetch origin master
git merge --no-ff origin/master        # letzter Abgleich, Konflikte hier lösen
# Tests laufen lassen
git checkout master
git pull --rebase origin master
git merge --no-ff scenario/<szenario>/<topic> -m "Merge scenario/<szenario>/<topic> into master"
git push origin master
```

`--no-ff` bleibt Pflicht: Der Merge-Commit macht den Branch in `git log --graph` sichtbar.

**`git pull --rebase origin master` vor jedem Push** — das ist der ganze Konfliktschutz, den
es braucht. Bei einem Entwickler an einer Maschine ist das Kollisionsrisiko ohnehin klein;
was tatsächlich passiert ist, war nie ein Konflikt, sondern ein Checkout, der zurückblieb.

**Die anderen Checkouts ziehen nach, wenn sie wollen** (`git pull`). Es gibt keine
automatische Weitergabe und keine Pflicht, sie synchron zu halten — ein Checkout, der einen
Stand hinterherhinkt, ist normal.

---

## Abstimmung zwischen Szenarien: Handoffs

Ein Befund aus einem Szenario, der ein anderes betrifft, wandert als **Handoff** dorthin —
nicht über einen gemeinsamen Ort, sondern als Dokument.

```
<ziel-checkout>/.paul/HANDOFF-<kontext>.md
```

Der Handoff enthält alles, was der Empfänger braucht, ohne den Vorkontext des Absenders:
Befund mit Messwerten, wie man ihn nachvollzieht, Handlungsoptionen, Randbedingungen. Er wird
beim nächsten `/paul:resume` gelesen und nach der Bearbeitung nach
`.paul/handoffs/archive/` verschoben.

**Beleg, dass das trägt:** Am 2026-09-08 ging ein Firewall-Befund von `carambus_phat` nach
`carambus_bcw` — dort read-only nachgemessen, umgesetzt, archiviert. Kein gemeinsamer
Checkout war beteiligt.

Handoffs regeln, **wer was weiß**. Sie regeln nicht, wer wann schreibt — dafür gilt die eine
Regel oben.

---

## Vor dem ersten Edit

Ein kurzer Blick auf den Zielbaum. Andere Checkouts müssen nicht geprüft werden.

```bash
cd /Users/gullrich/DEV/carambus/<szenario>
git fetch -q origin
echo "Branch: $(git rev-parse --abbrev-ref HEAD)"
git rev-list --left-right --count origin/master...HEAD   # behind / ahead
git status --short
```

**Anhalten und nachfragen, wenn:**

- der Branch nicht der ist, auf dem gearbeitet werden soll
- der Arbeitsbaum unerwartete Änderungen enthält (generierte Artefakte wie `public/docs/`
  sind normal — sie gehören nie in einen Commit; **niemals `git add -A`**, sondern die
  geänderten Dateien einzeln stagen)
- lokale Commits ungepusht sind und ein Rebase oder Reset bevorsteht

---

## Deployment

```
Commit auf master → der Betreiber pullt im Ziel-Checkout → der Betreiber deployt
```

- Der Betreiber pullt selbst, wenn er bereit ist — es gibt keine automatische Weitergabe.
- Deploys führt der Betreiber aus (`rake "scenario:deploy[<szenario>]"`).
- **Auf Produktionsservern nur read-only arbeiten.** Änderungen dort brauchen eine
  ausdrückliche Freigabe und werden vom Betreiber ausgeführt.

Szenario-Konfigurationen liegen in `carambus_data/scenarios/<szenario>/config.yml`
(Hosts, Ports, Datenbank, Deploy-Ziel).

---

## Häufige Fehler

1. Dieselbe Sache gleichzeitig in zwei Checkouts ändern — der Fehler, um den es hier geht.
2. Einen Branch ohne `scenario/<szenario>/`-Präfix anlegen.
3. Einen Feature-Branch wochenlang treiben lassen, ohne `master` einzumergen.
4. Konflikte auf `master` lösen statt im Feature-Branch.
5. `git add -A` in einem Baum mit generierten Artefakten.
6. Auf einem Produktionsserver schreibend eingreifen.

---

## Historie: warum es keinen Master-Checkout mehr gibt

Bis September 2026 verlangte dieser Skill, dass Code entweder in einem Checkout
`carambus_master` oder in einem Feature-Branch entsteht, mit dem Merge-back zwingend in
`carambus_master`.

Das hat sich nicht bewährt: Wer dort editiert, muss dort auch testen können — und sinnvoll
testen lässt sich nur an einem lokalen Server-Szenario oder in `carambus_api`. Am 2026-09-08
wurde gemessen, was daraus geworden war: Der Master-Checkout hing zwei Commits hinter den
vier Deployment-Checkouts, war kein PAUL-Projekt und trug nichts Einzigartiges — sauberer
Arbeitsbaum, nichts Ungepushtes, alle 28 lokalen Branches auch auf `origin`. Die Praxis
hatte die Regel längst überstimmt.

Milestone v0.3.5 hat daraus die Konsequenz gezogen: Die Werkzeuge (`rake scenario:*`, die
`bin/`-Skripte) wurden vom Nachbarverzeichnis gelöst, dieser Skill neu gefasst und
`carambus_master` stillgelegt. Das **Feature-Branch-Modell blieb** — es wird gelebt und
funktioniert; verloren ging nur ein Ort, kein Verfahren.

---

## Weiterführend

`docs/developers/scenario-management.de.md` — Szenario-Konfiguration, Datenbanken,
Deployment im Detail. (Beschreibt die Konfiguration, nicht die Checkout-Disziplin.)
