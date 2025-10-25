# Verwaltung von Ligaspieltagen

### Wichtige Begriffe und Konzepte

#### League (Liga)
Eine **Liga** ist ein Mannschaftswettbewerb über eine Saison mit mehreren Teams.

#### LeagueTeam (Mannschaft)
Ein **LeagueTeam** ist eine Mannschaft innerhalb einer Liga. Jedes Team besteht aus mehreren Spielern.

#### Party (Spieltag)
Ein **Party** (Spieltag) ist eine Begegnung zwischen **zwei LeagueTeams** an einem bestimmten Datum und Ort.

**Wichtig:** In einer Liga gibt es typischerweise:
- **Hinrunde:** Jedes Team spielt einmal gegen jedes andere (zu Hause oder auswärts)
- **Rückrunde:** Die gleichen Begegnungen, mit getauschtem Heimrecht

Beispiel: Team A vs. Team B
- Hinrunde: Party 1 (bei Team A)
- Rückrunde: Party 2 (bei Team B)

#### PartyGame (Einzelspiel innerhalb eines Spieltags)
Ein **PartyGame** ist ein einzelnes Spiel zwischen zwei Spielern während eines Spieltags (Party).

An einem Spieltag werden **mehrere PartyGames** nach einem festgelegten Muster ausgetragen:
- Jeder Spieler aus Team A spielt gegen mehrere Spieler aus Team B
- Die Anzahl und Reihenfolge ist durch den **Game Plan** vorgegeben
- Typisch: 6-12 Einzelspiele pro Spieltag

**Zusammenfassung:**
```
League (Liga)
  └── LeagueTeam (Mannschaften)
        └── Party (Spieltag zwischen 2 Teams)
              └── PartyGame (Einzelspiele innerhalb des Spieltags)
                    └── Spieler A vs. Spieler B
```

**Beispiel:** Bundesliga Nord, 1. Spieltag
- **League:** Bundesliga Nord
- **LeagueTeam:** BC Hamburg, BV Wedel
- **Party:** BC Hamburg vs. BV Wedel (Spieltag am 15.10.2024)
- **PartyGames:** 
  - Spiel 1: Spieler Müller (Hamburg) vs. Schmidt (Wedel)
  - Spiel 2: Spieler Meyer (Hamburg) vs. Wagner (Wedel)
  - ... (insgesamt z.B. 8 Spiele)

### Überblick

Die Behandlung von Ligabegegnungen läuft grundlegend verschieden verglichen mit Einzelturnieren und wird daher auch speziell unterstützt. Die Struktur der Ligabegegnungen ist für die einzelnen Ligen vorgegeben und ändert sich nicht im Laufe einer Saison.

Folgende Phasen werden im allgemeinen durchlaufen:

* Planung der Spieltage und Mannschaften
* Zu Beginn eines Spieltages Festlegung der Spieler durch die Kapitäne
* Pro Runde Festlegung der Spieltische zu den einzelnen Spielen
* Zuordnung der Spieler zu den einzelnen Spielen pro Runde
* Start der Runden und Übertragung der Daten an die Scoreboards
* Bedienung der Scoreboards
* Übergabe der Ergebnisse an den Matchday-Monitor und ggf. an Übersichtsboards
* Automatischer Abschluss einer Runde, Start einer weiteren Runde und ggf. Start eines Shootout bei Gleichstand
* Übertragung der Ergebnisse an die ClubCloud

### Planung der Spieltage und Mannschaften

Die Struktur der Spieltage einer Liga wird zu Saisonbegin auf DBU- oder Landesebene festgelegt und in der ClubClud formal eingetragen. Die Terminierung der einzelnen Spieltage wird ebenfalls in der ClubCloud geführt. Weiterhin werden die in den einzelnen Mannschaften spielberechtigten Spieler festgelegt.

Diese Daten bilden die Grundlage für das Carambus Matchday Management. Der Spielleiter findet diese Daten am einfachsten über das Spiellokal, wo alle Begegnungen aufgelistet sind.

Nach öffen der Spieltagansicht gibt es einen Link zum Matchday Monitor. In dessen Ansicht wird der gesammte Spieltagablauf gesteuert.

### Festlegung der Spieler eines Spieltages

Carambus bietet aus den Eintragungen in der ClubCloud zur Auswahl die Spieler des entsprechenden Teams und zusätzlich Spieler aus untergeordneten Ligen. Nach der Auswahl, ist die Menge der am Spieltag verfügbaren Spieler unveränderbar festgelegt.

### Zuordnung der Tische

In Carambus können die in einem Spiellokal verfügbaren Tische mit Name und Typ (Karambol groß, mittel, klein, Pool, Snooker) definiert werden. Rundenweise müssen aus dieser Menge Tische den einzelnen Spielen zugeordnet werden.

### Zuordnung der Spieler zu Spielen

Nach der Zuordnung der Tische müssen nun die einzelnen Spielpaarungen besetzt werden. Erst wenn alle Spiele einer Runde belegt sind, kann die Runde gestartet werden.

### Übertragundg der Daten an die Scoreboards

Mit dem Start der Runde erscheinen an den Scoreboards die einzelnen Spielpaarungen. Nach Abschluss eines Matches bleinen die Ergebnisse solange stehen, bis die nächste Paarung aufgerufen wird.

### Bedienung der Scoreboards

Die Bedienung der Scoreboards erfolgt über Touch-Eingabe. Per Undo können Eingaben beliebig zurückgenommen werden. Das gilt auch nach Ende der Partie, solange die Partie nicht endgültig vom Spielleiter abgeschlossen wurde.

### Steuerung am Matchday Monitor

Die gesammte Überwachung der Spieltages kann am Matchday-Monitor vorgenommen werden. Die Ergebnisse werden life in der Monitoransicht aktualisiert. Am Ende muss das Ergebnis der einzelnen Paarungen bestätigt werden.

### Automatischer Rundenabschluss und -start

Wenn alle Spiele einer Runde bestätigt sind, wird automatisch zur nächsten Runde, bzw. ggf zum Shootout übergegangen. Die Zwischenrgebnisse und das Endergebnis können bei Bedarf an jedem Scoreboards eingesehen werden (Start -> Turniere -> Turnier).

### Upload in die ClubCloud

Zum Upload in die ClubCloud wird das Formular angeboten, genau so wie auch im Adminbereich der ClubCloud. Damit das funktioniert, ist ein Login in die ClubCloud mit demselben Browser notwendig. 
