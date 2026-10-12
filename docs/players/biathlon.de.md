# Biathlon am Scoreboard

Biathlon kombiniert **Dreiband** und **5-Kegel** in einer Partie (DBU-Regeln Biathlon §3,
[billardregel.de](https://billardregel.de/kegel/biathlon/03-spiel-partie/)). Diese Seite beschreibt,
wie eine Biathlon-Partie in Carambus eingestellt und am Scoreboard gezählt wird.

## Die Regel in Kürze {#regel}

1. Gespielt wird zuerst **Dreiband** — bis zur **Teildistanz** oder bis zur
   **Aufnahmebegrenzung**. Es gibt **keinen Nachstoß**.
2. Beim Wechsel werden die Dreibandpunkte **mit 6 multipliziert** (Verrechnungsfaktor).
3. Danach wird **5-Kegel** gespielt, weiter vom Stand aus Schritt 2, bis zur **Gesamtpunktzahl**.
   Überschüssige Punkte des letzten Stoßes zählen nicht. Wer zuerst die Gesamtpunktzahl erreicht,
   gewinnt — ohne Nachstoß.

Der Wechsel gilt für **die ganze Partie**: sobald **ein** Spieler die Teildistanz erreicht oder
**beide** die Aufnahmebegrenzung gespielt haben. Der folgende Spieler beginnt mit Kegel.

Eine Variante wird als **Teildistanz / Aufnahmen Dreiband / Gesamtziel** geschrieben:

| Variante | Dreiband | Faktor | Kegel bis |
|---|---|---|---|
| 15/30/180 | 15 Punkte in 30 Aufnahmen | ×6 | 180 |
| 15/20/180 | 15 Punkte in 20 Aufnahmen | ×6 | 180 |
| 10/20/120 | 10 Punkte in 20 Aufnahmen | ×6 | 120 |
| 10/15/120 | 10 Punkte in 15 Aufnahmen | ×6 | 120 |

## Partie einstellen {#einstellen}

### Schnellstart {#schnellstart}

Auf einem **Matchbillard** zeigt der Schnellstart die Kategorie **Biathlon** mit den vier
Varianten aus der Tabelle. Knopf wählen, Spieler auswählen, fertig.

!!! note "Knöpfe fehlen?"
    Die Schnellstart-Knöpfe stehen in der `carambus.yml` des Servers. Ein Vereins-Admin trägt sie
    im Admin-Bereich unter **Einstellungen → Quick Game Presets** bei `match_billard` ein:
    `{"category": "Biathlon", "buttons": [{"balls": 180, "innings": 0, "balls_3b": 15, "innings_3b": 30, "discipline": "Biathlon", "allow_follow_up": false}, …]}`
    — danach die Anwendung neu starten. Das Feld enthält die **ganze** Preset-Liste: die übrigen
    Kategorien mitkopieren, sonst verschwinden sie vom Schnellstart. Und auf dem richtigen Server
    eintragen — jeder Server hat seine eigene `carambus.yml`.

### Detailseite {#detailseite}

Auf der Detailseite eines Matchbillards **BIATHL** wählen. Dann erscheinen drei Zeilen:

| Zeile | Bedeutung | Vorbelegung |
|---|---|---|
| **Gesamtziel** | Punktzahl, mit der die Partie endet (Kegel-Phase) | 180 |
| **Dreiband-Distanz** | Teildistanz der Dreiband-Phase | 15 |
| **Aufnahmen Dreiband** | Aufnahmebegrenzung der Dreiband-Phase | 30 |

Jeder Wert lässt sich auch über **−/+** frei einstellen. Eine Aufnahmebegrenzung für die ganze
Partie und ein Nachstoß werden bei Biathlon nicht verwendet, auch wenn sie eingestellt sind.

### Im Turnier {#turnier}

Bei einem Turnier mit der Disziplin Biathlon zeigt die Startseite zusätzlich
**Biathlon: Dreiband-Distanz** und **Biathlon: Aufnahmen Dreiband** (Vorbelegung 15/30). Das
**Bälle-Ziel** des Turniers ist das Gesamtziel; das **Aufnahmen-Limit** bleibt auf 0. Die
Variante gilt für alle Partien des Turniers. Siehe [Turnierverwaltung](../managers/tournament-management.md#start-parameters).

### Turnier-App {#turnier-app}

Die Turnier-App setzt die Variante **pro Spiel** — beim DBU Grand Prix z. B. andere Werte für
Gruppenphase, Achtelfinale und Finale. Siehe [Turnier-App](../managers/tournament-app.md#gp-biathlon).

## Zählen am Scoreboard {#zaehlen}

### Dreiband-Phase {#dreiband}

- In der Mitte steht **Biathlon/3B**.
- **Ziel** zeigt die **Teildistanz** (z. B. „Ziel: 10“), unter der Aufnahmezahl steht die
  Aufnahmebegrenzung der Dreiband-Phase („of 15“).
- Eingegeben wird wie bei Dreiband: **+1** je Punkt. Die große Zahl zeigt die **rohen
  Dreibandpunkte** — nicht ×6.
- Eine Eingabe über die Teildistanz hinaus wird auf die Teildistanz gekappt.
- Erreicht ein Spieler die Teildistanz, **endet seine Aufnahme automatisch**, und die Partie
  wechselt auf 5-Kegel. Der Gegner bekommt in Dreiband keinen Nachstoß.
- Sind **beide** Spieler bei der Aufnahmebegrenzung angekommen, wechselt die Partie ebenfalls —
  egal, wer angestoßen hat.

### Der Wechsel {#wechsel}

- Beide Stände werden mit 6 multipliziert (aus 10 werden 60).
- In der Mitte steht jetzt **Biathlon/5K** und darunter das **3B-Ergebnis**, z. B.
  „10(60) / 4(24)“ — Dreibandpunkte und in Klammern der multiplizierte Wert.
- Der folgende Spieler beginnt mit Kegel, aus der hinterlassenen Ballstellung.

### Kegel-Phase {#kegel}

- **Ziel** zeigt jetzt das **Gesamtziel** (z. B. „Ziel: 120“); eine Aufnahmebegrenzung gibt es
  nicht mehr.
- Eingegeben wird wie beim 5-Kegel-Billard. Überschüssige Punkte des letzten Stoßes werden auf
  das Gesamtziel gekappt.
- Die Partie **endet sofort**, wenn ein Spieler das Gesamtziel erreicht. Ein Unentschieden ist
  dadurch ausgeschlossen.

### Korrigieren (Undo) {#undo}

**Undo** nimmt wie gewohnt die letzte Eingabe bzw. Aufnahme zurück. Wird die Aufnahme
zurückgenommen, die den Wechsel ausgelöst hat, kehrt die Partie in die **Dreiband-Phase** zurück
— mit den rohen Dreibandpunkten, ohne Faktor 6.

## Ergebnis {#ergebnis}

- **Ergebnis** ist der Gesamtstand: Dreibandpunkte ×6 plus Kegelpunkte, höchstens das Gesamtziel.
- **Aufnahmen** zählt die Aufnahmen beider Teile zusammen; ein GD (Ergebnis ÷ Aufnahmen) ist damit
  vergleichbar.
- Zusätzlich gespeichert werden **3B-Ergebnis** und **3B-Aufnahmen** (Stand beim Wechsel).

## Häufige Fragen {#faq}

**Die große Zahl zeigt in der Dreiband-Phase nur 7 — müsste da nicht 42 stehen?**
Nein. In der Dreiband-Phase stehen die rohen Punkte, damit die +1-Eingabe nachvollziehbar bleibt.
×6 wird beim Wechsel gerechnet.

**Ein Spieler hat in der letzten Dreiband-Aufnahme mehr Punkte gemacht, als zur Teildistanz
fehlten.** Die Eingabe wird auf die Teildistanz gekappt — so wie die Regel es vorsieht.

**Im Turnier steht ein Aufnahmen-Limit von 30 — endet die Partie nach 30 Aufnahmen?**
Nein. Bei Biathlon gilt die Aufnahmebegrenzung nur für die Dreiband-Phase (Feld „Biathlon:
Aufnahmen Dreiband“). Das Aufnahmen-Limit des Turniers wird ignoriert; trotzdem besser auf 0
lassen, damit die Startseite eindeutig ist.

**Ein Rückspiel (Training) — bleibt die Variante?** Ja, das Rückspiel übernimmt Teildistanz und
Aufnahmebegrenzung der ersten Partie.
