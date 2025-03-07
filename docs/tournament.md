---
---
title: Turnierverwaltung
summary:
version:
published_at: !ruby/object:ActiveSupport::TimeWithZone
  utc: 2025-03-07 22:00:25.243335000 Z
  zone: !ruby/object:ActiveSupport::TimeZone
    name: Europe/Berlin
  time: 2025-03-07 23:00:25.243335000 Z
tags: []
metadata: {}
position: 0
id: 50000002
---

# Turnierverwaltung

## Account
Für das Carambus Turniermanagement ist ein Account mit Admin-Rechten auf dem Carambus Location Server erforderlich.
Dieser kann vom Club-Vorsitzenden oder [Carambus-Entwickler](mailto:gernot.ullrich@gmx.de) eingerichtet werden.
URL ist aus den URLs der Scoreboards ableitbar, z.B. in Wedel http://192.168.2.143:3131 .

## Abgleich mit der ClubCloud

Die Turniere findet man am besten über die `Regionaverbände -> Suchen -> Ansehen`.

Dort sind die aktuell bekannten Turniere der laufenden Saison gelistet. Das Turnier kann über den Titel  ausgewählt werden.
Sollte ein Turnier noch nicht gelistet sein, so kann das mehrere Gründe haben:

* Das Turnier ist noch nicht in der ClubCloud eingetragen
* Der zentrale Carambus API Server kennt das Turnier noch nicht.
* Das Turnier ist noch nicht auf den lokalen Location Server übertragen.


### Das Turnier ist noch nicht in der ClubCloud eingetragen
Aufgabe des Landessportwartes ist es, die Turniere mit den Teilnehmerlisten in der ClubCloud einzupflegen.

### Der zentrale Carambus API Server kennt das Turnier noch nicht.
Der Api Server wird derzeit vom Carambus-Entwickler (mailto: gernot.ullrich@gmx.de) betreut.  
Turnierdaten der Carambus nutzenden Regionen werden automatisiert täglich um 20:00 aus dem zugehörigen regionalen ClubCloud Server aktualisiert.

Lokale Server fordern Updates aus der ClubCloud immer über den zentralen API Server (api.carambus.de) an.
Dieser greift die Daten von den verschiedenen ClubCloud Instanzen ab.  Mit den spezifischen Updates werden immer auch alle Updates übertragen, die zwischenzeitlich auf dem API Server gemacht wurden.

### Das Turnier ist noch nicht auf den lokalen Location Server übertragen

Ein lokal nicht vorhandenes Turnier, welches aber auf dem API Server existiert, wird automatisch bei jeder Update-Anfrage an den API Server geladen, denn bei jeder Anfrage an den API Server wird der gesammte Datenbestand synchronisiert.
So eine explizite Anfrage kann z.B. das Aktualisieren der Club-Daten sein:
`Clubs -> Suchen -> Ansehen -> "Datenabgleich mit der ClubCloud mit allen Details"`

### Aktualisieren von Regionalverband, Club, Spieler, Turnier, Setzlisten
Beim expliziten Abholen von Daten werden auf dem API Server die angeforderten Daten mit der Billars Area abggeglichen.

Folgenden explizte Datenanfragen sind implementiert:

* `Club -> Datenabgleich mit der ClubCloud`
* `Club -> Datenabgleich mit der ClubCloud mit allen Details`
* `Regionalverband -> Datenabgleich mit der ClubCloud inkl. Clubs`
* `Regionalverband -> Datenabgleich mit der ClubCloud inkl. Clubs und Spieler`
* `Turnier -> Datenabgleich mit der ClubCloud`

## TurnierVerwaltung
Ein Turnier wird generell in folgenden Phasen verwaltet:

* Abgleich mit der ClubCloud
* Überprüfung der relevanten Daten
* Sortierung der Setzliste gemäss Rankings
* Auswahl des Turniermodus
* Lokale Anpassung der Turnierparameter
* Check der lokalen Scoreboards
* Start des Turniers
* Abgleich der Partieergebnisse mit den Spielprotokollen
* eMail mit den Spielergebnissen (csv) an den Turnierleiter
* Upload der Spielergebnisse (csv) in die ClubCloud
* Abgleich mit der ClubCloud zum letzten Check.

### Abgleich mit der ClubCloud
Wie oben beschrieben kann das Turnier erstmalig geladen werden z.B. durch Abgleich der Clubdaten

Wenn ein Turnier bereits lokal bekannt ist, kann jederzeit eine Aktualisierung erneut angefordert werden:
`Region -> Turnier -> Datenabgleich mit der ClubCloud`

### Überprüfung der relevanten Daten

Für den Ablauf eines Turnieres sind folgende Daten wichtig:

* Veranstalter (Regionalverband oder Club)
* Disziplin (für die Tischzuordnungen)
* Datum
* Saison
* Spielort (für die Tischzuordnungen)

Diese Daten werden in der Regel automatisiert von der ClubCloud gezogen. Ein Sonderfall ist der Spielort.
Leider ist bezgl. des Spielortes auf der ClubCloud eine freie Texteingaben möglich.
Für die Tischzuordnung ist in Carambus jedoch die Auswahl eines formal definierten Spielortes mit Konfigurierung der Tische notwendig (Tischnahme, Tischart)
Weiterhin ist anzugeben, ob es sich um ein Vorgabetournier handelt.

Diese Daten müssen über
`Turnier -> Edit -> Turnier aktualisieren`
ergänzt werden

###Sortierung der Setzliste gemäss Rankings

Mit dem BA-Abgleich wird die Teilnehmerliste (Setzliste) übertragen.

Für Vorgabeturniere können die Handicaps eingetragen werden:
`Tournament -> Setzliste aktualisieren`
Diese Liste kann jetzt lokal entsprechend der Spielerrankings sortiert werden:
`Tournament -> Ordne nach Rangliste bzw. Handicap`

Die Reihenfolge kann jetzt noch geändert werden durch Tausch von Plätzen mit den Pfeilen oben/unten.

Die Reihenfolge wird dann endgültig abgeschlossen mit
`Turnier -> Abschluss der Rangliste (nicht umkehrbar)`

### Auswahl des Turniermodus
Jetzt in die Turniermodusauswahl springen:
`Turnier -> Turniermodus festlegen`

In der Regel stehen mehrere Möglichkeiten zur Verfügung.  Der Tournierleiter kann einen Modus auswählen - in der Regel schon vom Landessportwart vorgegeben bei Turnieren der Regionalverbände.

Auswahl duch Klick z.B. `Weiter mit T07`

### Lokale Anpassung der Turnierparameter

Folgende Parameter können nun noch angepasst werden:

* Zuordnung der Tische (Mapping interner Tischname zu extern Namen)
* Ballziel (ggf. bereits für Turnier vorgegeben)
* Aufnahmebegrenzung (ggf. bereits für Turnier vorgegeben)
* Timeout in sec (0 oder keine eingabe, wenn keine Timeouts)
* Timeouts (n Timeoutverlängerungen maximal)
* Checkbox "Tournament manager checks results before acceptance"
* Einspielzeit
* verkürzte Einspielzeit (bei Wechsel an einen bereits bespielten Tisch)


Zur Checkbox:  Normalerweise können die Spieler des Spielstatus fortschreiben z.B. nach `Partie beendet - OK?`.
Wenn ein Check von Turniermanager erforderlich ist, wird dieses unterbunden und der Turnierleiter kann nach Abgleich mit dem Spielprotokoll den Tisch freigeben.

Die neuen Spielpaarungen erscheinen jeweils automatisch auf den Scoreboards.
Erst ganz am Ende:

###eMail mit den Spielergebnissen (csv) an den Turnierleiter

Nach Abschluss des Turniers erhält der Turnierleiter automatisch per eMail eine CSV-Datei mit den Ergebnissen in dem Format, welches für den Upload in die ClubCloud notwendig ist.
Diese Datei wird auch auf dem lokalen Server gespeichert ({carambus}/tmp/result-{ba_id}.csv)

###Upload der Spielergebnisse (csv) in die ClubCloud
Der Turnierleiter kann die CSV-Datei direkt in die ClubCloud hochladen (er weiss wie das geht ;-)

### Abgleich mit der ClubCloud zum letzten Check
Als letzten Schritt kann nocheinmal ein Abgleich mit der ClubCloud erfolgen.
Die damit heruntergeladenen Daten sind Grundlage für später ausgerechnete Rankings.
