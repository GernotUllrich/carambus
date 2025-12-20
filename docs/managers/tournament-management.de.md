# Turnierverwaltung

## Einführung

Carambus zielt darauf, den gesamten Spielbetrieb auf Regional- und Vereinsebene zu automatisieren. Es werden die wichtigsten Billarddisziplinen Karambol, Pool, Snooker und Kegel in Deutschland in Einzelturnieren und Mannschaftswettkämpfen unterstützt.

> **Automatisierung mit Carambus bedeutet Unterstützung aller Phasen des Billardspiels** von der Turnierplanung, der Festsetzung des Turniermodus, der Einteilung der Spielpaarungen entsprechend der Rang- und Setzlisten, der Tischzuordnung, der Realzeiterfassung der Spiele über die Anzeigetafeln bis zur Auswertung der Ergebnisse und Übertragung an die zentralen Verbände.

## Struktur

Technisch gesehen ist Carambus eine Hierarchie von Webservices. An der Spitze steht ein Webserver, der sog. Carambus API Server, der nur dazu dient, externe Daten so zeitaktuell und effizient wie möglich vorzuhalten. Konsumenten dieser Daten sind auf Regionalebene und am Veranstaltungsort, bzw. in den Clubheimen Webserver, die den lokalen Spielbetrieb verwalten.

Endgeräte dieser Webserver sind Webbrowser der Sportbeauftragten zur Planung und Abwicklung der Turniere, sowie Scoreboards mit Touch-Funktionalität am Veranstaltungsort zur Spielsteuerung durch die Spieler.

Im sog. Trainingsmodus werden die Scoreboards zur Aufzeichnung der Spielergebnisse genutzt. Zum Aufsetzen der Spiele werden Spielerlisten des Clubs aus der Carambus Datenbank genutzt. Spiele werden im lokalen Webserver aufgezeichnet, sodass Auswertungen über die Performanz von Spielern möglich werden.
 
Da alles auf standardisierten HTML Protokollen basiert, ist Carambus weitgehend hardwareunabhängig.

## Carambus API

Die Daten, die im Carambus API Server gespeichert werden amit den lokalen Webserver synchronisiert. Dabei kann der Datenbereich auf die Region und die überregionalen Turniere der DBU und deren Teilnehmer eingeschränkt werden.

Folgende Daten werden vom API-Server zentral geliefert:

### Regionalverbände
- ClubCloud-ID, Name, Kurzname, Logo, E-Mail, Adresse, Land

### Clubs
- ClubCloud-ID, Region, Name, Kurzname, Adresse, Home-Page, E-Mail, Logo

### Spiellokale
- ClubCloud-ID, Region, Name, Adresse

### Tischausstattung
- Tischarten, Zahl, Größe, Namen

### Spielerdaten
- ClubCloud-ID, Club, Nachname, Vorname, Titel

### Saisonale Vereinszugehörigkeiten
- Spieler, Saison, Club, Clubgäste

### Turniere
- ClubCloud-ID, Titel, Disziplin, Spielklasse, Modus, Zugangsbeschränkung, Datum, Akkreditierungsschluss, Spiellokal, Saison, Region, Schlussdatum, Aufnahmegrenze, Punktziel, Organisator (Club oder Region)

### Turniermoduspläne
- Name, Regelsystem, Spielerzahl, Tischzahl, Beschreibung, Gruppenzahl, formaler Ablauf

### Turnier/Spieler Setzlisten
- Spieler, Listenplatz, Turnier, ggf. Vorgaben bei Vorgabeturnieren

### Spiele
- Turnier, Spielname, PlayerA, PlayerB

### Spielergebnisse
- Spiel, Bälle, Aufnahmen, Höchstserie, Durchschnitt

### Spieler Rankings
- Spieler, Disziplin, bester Einzeldurchschnitt, bester Turnierdurchschnitt

### Ligen

### Mannschaftskader

### Spieltage

### Spieltagbegegnungen

> **Hinweis:** Ab 2022 wurde die BilardArea (BA) durch die ClubCloud abgelöst. Im Gegensatz zur BA gibt es nun nicht mehr eindeutige Identifier deutschlandweit. Die CC-IDs sind nur eindeutig innerhalb der regionalen ClubCloud-Instanzen.  Carambus bemüht sich, Mehrdeutigkeiten soweit aufzulösen, dass die Daten global sauber bleiben.

## Account

Für das Carambus Turniermanagement ist ein Account mit Admin-Rechten auf dem lokalen Carambus Server erforderlich. Dieser kann vom Club-Vorsitzenden oder [Carambus-Entwickler](mailto:gernot.ullrich@gmx.de) eingerichtet werden.

Die URL ist aus den URLs der Scoreboards ableitbar, z.B. in Wedel http://192.168.2.210:3131.

## Abgleich mit der ClubCloud

Die Turniere findet man am besten über die `Regionalverbände -> Suchen -> Ansehen`. Dort sind die aktuell bekannten Turniere der laufenden Saison gelistet. Das Turnier kann über den Titel ausgewählt werden.

Mit dem KI-Assistenten (ab Okt 2025) könntest Du auch einfach suchen mit "Turniere im NBV in der Saison 2025/2026 nicht älter als 2 Wochen"

Sollte ein Turnier noch nicht gelistet sein, so kann das mehrere Gründe haben:

* Das Turnier ist noch nicht in der ClubCloud eingetragen
* Der zentrale Carambus API Server kennt das Turnier noch nicht
* Das Turnier ist noch nicht auf den lokalen Location Server übertragen

### Das Turnier ist noch nicht in der ClubCloud eingetragen
Aufgabe des Landessportwartes ist es, die Turniere mit den Teilnehmerlisten in der ClubCloud einzupflegen.

### Der zentrale Carambus API Server kennt das Turnier noch nicht
Der API Server wird derzeit vom Carambus-Entwickler (mailto: gernot.ullrich@gmx.de) betreut. Turnierdaten der Carambus nutzenden Regionen werden automatisiert täglich aus dem zugehörigen regionalen ClubCloud Server aktualisiert.

Lokale Server fordern Updates aus der ClubCloud immer über den zentralen API Server (api.carambus.de) an. Dieser greift die Daten von den verschiedenen ClubCloud Instanzen ab. Mit den spezifischen Updates werden immer auch alle Updates übertragen, die zwischenzeitlich auf dem API Server gemacht wurden.

### Das Turnier ist noch nicht auf den lokalen Location Server übertragen
Ein lokal nicht vorhandenes Turnier, welches aber auf dem API Server existiert, wird automatisch bei jeder Update-Anfrage an den API Server geladen, denn bei jeder Anfrage an den API Server wird der gesamte Datenbestand synchronisiert - ggf. eingeschränkz bzgl. Region und DBU.

So eine explizite Anfrage kann z.B. das Aktualisieren der Club-Daten sein:
`Clubs -> Suchen -> Ansehen -> "Datenabgleich mit der ClubCloud mit allen Details"`

### Aktualisieren von Regionalverband, Club, Spieler, Turnier, Setzlisten
Beim expliziten Abholen von Daten werden auf dem API Server die angeforderten Daten mit der Billard Area abgeglichen.

Folgende explizite Datenanfragen sind implementiert:

* `Club -> Datenabgleich mit der ClubCloud`
* `Club -> Datenabgleich mit der ClubCloud mit allen Details`
* `Regionalverband -> Datenabgleich mit der ClubCloud inkl. Clubs`
* `Regionalverband -> Datenabgleich mit der ClubCloud inkl. Clubs und Spieler`
* `Turnier -> Datenabgleich mit der ClubCloud`

## Regionales Turniermanagement

Die Turnierverwaltung wird in folgenden Schritten vollzogen:

### Aktualisierung der Turnierdaten
Vor dem Turnierstart sollte dafür gesorgt werden, dass das Turnier mit den Setzlisten in der Billard-Area aktualisiert ist. Die Synchronisierung mit dem lokalen Carambus Turniermanager kann dann angestoßen werden.

### Festlegung der Setzliste
Mit der Synchronisierung wird die Liste der Teilnehmer übernommen. Aus den Ranglistenplätzen der Spieler wird die Setzliste abgeleitet. Der Spielleiter kann weitere Spieler zum Auffüllen von Ausfällen vornehmen und ggf. kleinere Umsetzungen vornehmen.

### Auswahl des Turniermodus
Sobald die geordnete Spielerliste und damit auch die Zahl der Spieler feststeht, wird der Turniermodus ausgewählt. Im Allgemeinen gibt es mehrere Möglichkeiten (Gruppenspiele und Hauptrunde, ggf. mit Ausspielen der Plätze oder jeder gegen jeden etc.)

## Lokales Spielmanagement

Sobald der Turniermodus festgelegt ist, kann das Turnier beginnen.

### Festlegung der Tische
Aus der Menge der im Spiellokal zur Verfügung stehenden Tische werden die Tische 1-n aus dem Spielplan des Turniermodus zugeordnet.

### Festlegung einiger Parameter
Vor dem Start können ggf. entsprechend der Turnierregeln noch folgende Parameter aktualisiert werden:

* Aufnahmebegrenzung
* Ballziel
* Einspielzeit an neuem Tisch
* Einspielzeit bei Rückkehr zu einem Tisch
* Bedenkzeit vor einem Stoß

### Start und Ablauf des Spiels
Von nun an läuft alles automatisch ab. Auf den Anzeigetafeln erscheinen die Spielpaarungen mit Angabe der Gruppennummern und der Spielnamen (z. B. Gruppe 2 Spiel 2–4, also in der Gruppe 2 der 2. Spieler gegen den 4. Spieler).

Als erstes erscheint an den Anzeigetafeln die Aufforderung zum Einspielen mit entsprechenden Timern, z. B. 5 bzw. 3 Minuten.

Als nächstes erscheint die Aufforderung zum Anstoß. Im Ergebnis können die Spieler getauscht werden (Weiß stößt an, Gelb stößt nach).

Sobald der anstoßende Spieler feststeht wird das Spiel gestartet.

Folgende Eingaben an den Anzeigetafeln sind möglich:

* **`+1`** - Erhöhe die Ballzahl der laufenden Aufnahme um eins. (Bei Touch Displays kann dies auch durch Klick auf die jeweilige Zahl ausgelöst werden)
* **`-1`** - Erniedrige die Ballzahl der laufenden Aufnahme um eins
* **`nnn`** - Setze die Ballzahl der laufenden Aufnahme. Zeige das Nummernfeld 0-9. Eine beliebige positive Zahl kann eingegeben werden. Abschluss mit Enter oder Abbruch mit C
* **`DEL`** - Mit einer Undo Taste kann auf eine beliebige Aufnahme zurückgegangen werden. Nach Korrektur mit +1, -1 oder nnn Eingabe wird durch mehrfachen Spielerwechsel bis zur aktuellen Aufnahme weitergeblättert
* **`^v`** - Spielerwechsel: Die aktuelle Ballzahl der beendeten Aufnahme wird gespeichert und der Summe hinzugefügt. Der andere nun aktive Spieler wird an der Anzeigetafel markiert. (Bei Touch Displays kann dieses auch durch Klick auf die Ballzahl des jeweiligen anderen Spielers ausgelöst werden)

Der Schiedsrichter kann den Timer für die Bedenkzeit **`>`** starten, **`o`** beenden oder **`||`** anhalten

## Bedienungskonzepte

Carambus unterstützt zwei Hauptkategorien der Bedienung:

### 1. Management-Bedienung (Laptop/PC)

Die Bedienung über Laptop oder PC mit ausklappbaren Menüs an der linken Seite ist die Hauptschnittstelle für:

* **Spielleiter beim Turniermanagement** - Planung und Durchführung von Turnieren, Verwaltung der Spielpläne, Tischzuordnungen und Turnierstatus
* **Anwender zur Recherche** - Zugriff auf Turnier- und Ligadaten, Spielerstatistiken, Vereins- und Regionalverbandsinfos
* **Administratoren** - Systemkonfiguration und Benutzerverwaltung

Diese Menüs können bei Bedarf ein- und ausgefahren werden, um maximale Übersichtlichkeit zu gewährleisten.

### 2. Spieler-Bedienung (Touch-Scoreboard)

Spieler steuern den Spielablauf direkt am Scoreboard mit Touch-Funktionalität:

* **Spielprotokollierung** - Eingabe von Punkten und Aufnahmen durch Touch-Eingabe
* **Spielerwechsel** - Durch Antippen der Ballzahl des anderen Spielers
* **Timer-Steuerung** - Start, Stopp und Timeout-Verwaltung
* **Direkter Zugriff** - Die Spieler haben durch Ausklappen des Menüs optional auch Zugriff auf Billarddaten (kein Regelfall, sondern ein Feature für Spezialisten)

Die Touch-Bedienung ist intuitiv und ermöglicht eine schnelle, unkomplizierte Spielführung ohne zusätzliche Hardware.

### Zukunftsprojekt: Vereinfachte Schiedsrichter-Bedienung

Für zukünftige Entwicklungen ist eine stark vereinfachte Bedienung durch Schiedsrichter und Schreiber geplant, die speziell auf die Anforderungen bei offiziellen Wettkämpfen zugeschnitten sein wird.

### Timeout Behandlung

Bei der Turnierplanung oder auch erst beim Turnierstart können die Länge der Bedenkzeit (Timeout), sowie die Zahl der möglichen Timeoutverlängerungen (Timeouts) vorgegeben werden. Am Scoreboard kann im laufenden Spiel der Timeoutzähler um eins verringert werden. Die restliche Bedenkzeit wird dann noch einmal um das vorgegebene Timeout verlängert.

Die Timer-Funktionen (Stop, Halt, Play, Timeout) sind über die Touch-Bedienung am Scoreboard zugänglich.

### Das Ende des Spiels
wird anhand der Eingaben und der Aufnahme- bzw. Ballzahl automatisch erkannt.

An der Tafel wird ein Abschlussprotokoll angezeigt. Die Spieler bestätigen das Ergebnis mit einer Eingabe auf der Anzeigetafel.

### Wechsel zur nächsten Runde
Sobald alle Spiele einer Runde beendet sind, startet automatisch die nächste Runde. Die entsprechenden neuen Paarungen werden an den Anzeigetafeln angezeigt.

### Ende des Turniers
Sobald alle Spiele des Turniers abgeschlossen sind, wird ein Endprotokoll an den Spielleiter gesendet mit einer CSV-Datei, die dann direkt zum Upload der Ergebnisse in die Billard-Area genutzt werden kann.

## Trainingsmodus
An den Scoreboards können die jeweiligen Tische ausgewählt werden. Abhängig vom Turnierstatus können freie Tische erkannt werden und für das freie Trainingsspiel genutzt werden.

Ad-Hoc-Spiele können über ein Parameterfeld initialisiert werden. Eingabemöglichkeiten sind dabei:

* **Disziplin** (entsprechend der jeweiligen Tischeigenschaften, für beide, kann für den einzelnen Spieler gesondert vorgegeben werden)
* **Zielballzahl** (für beide, kann für den einzelnen Spieler gesondert vorgegeben werden)
* **Aufnahmebegrenzung**
* **Timeout** (optional)
* **Timeouts** (optionale Anzahl der Timeoutverlängerungen)
* **Spieler** (Selektion aus den Clubspielern oder Gästen)
* **Individuelle Disziplin** bzw. Zielballzahl

Für eine zukünftige Erweiterung sind Statistiken über Trainingsspiele geplant (pro Spieler und pro Spielpaarung)

## Turnierverwaltung - Detaillierter Workflow

Ein Turnier wird generell in folgenden Phasen verwaltet:

* Abgleich mit der ClubCloud
* Überprüfung der relevanten Daten
* Sortierung der Setzliste gemäß Rankings
* Auswahl des Turniermodus
* Lokale Anpassung der Turnierparameter
* Check der lokalen Scoreboards
* Start des Turniers
* Abgleich der Partieergebnisse mit den Spielprotokollen
* eMail mit den Spielergebnissen (csv) an den Turnierleiter
* Upload der Spielergebnisse (csv) in die ClubCloud
* Abgleich mit der ClubCloud zum letzten Check

### Überprüfung der relevanten Daten

Für den Ablauf eines Turnieres sind folgende Daten wichtig:

* Veranstalter (Regionalverband oder Club)
* Disziplin (für die Tischzuordnungen)
* Datum
* Saison
* Spielort (für die Tischzuordnungen)

Diese Daten werden in der Regel automatisiert von der ClubCloud gezogen. Ein Sonderfall ist der Spielort. Leider ist bezgl. des Spielortes auf der ClubCloud eine freie Texteingabe möglich. Für die Tischzuordnung ist in Carambus jedoch die Auswahl eines formal definierten Spielortes mit Konfigurierung der Tische notwendig (Tischname, Tischart). Weiterhin ist anzugeben, ob es sich um ein Vorgabeturnier handelt.

Diese Daten müssen über `Turnier -> Edit -> Turnier aktualisieren` ergänzt werden

### Sortierung der Setzliste gemäß Rankings

Mit dem BA-Abgleich wird die Teilnehmerliste (Setzliste) übertragen.

Für Vorgabeturniere können die Handicaps eingetragen werden: `Tournament -> Setzliste aktualisieren`

Diese Liste kann jetzt lokal entsprechend der Spielerrankings sortiert werden: `Tournament -> Ordne nach Rangliste bzw. Handicap`

Die Reihenfolge kann jetzt noch geändert werden durch Tausch von Plätzen mit den Pfeilen oben/unten.

Die Reihenfolge wird dann endgültig abgeschlossen mit `Turnier -> Abschluss der Rangliste (nicht umkehrbar)`

### Auswahl des Turniermodus
Jetzt in die Turniermodusauswahl springen: `Turnier -> Turniermodus festlegen`

In der Regel stehen mehrere Möglichkeiten zur Verfügung. Der Turnierleiter kann einen Modus auswählen - in der Regel schon vom Landessportwart vorgegeben bei Turnieren der Regionalverbände.

Auswahl durch Klick z.B. `Weiter mit T07`

### Lokale Anpassung der Turnierparameter

Folgende Parameter können nun noch angepasst werden:

* Zuordnung der Tische (Mapping interner Tischname zu extern Namen)
* Ballziel (ggf. bereits für Turnier vorgegeben)
* Aufnahmebegrenzung (ggf. bereits für Turnier vorgegeben)
* Timeout in sec (0 oder keine Eingabe, wenn keine Timeouts)
* Timeouts (n Timeoutverlängerungen maximal)
* Checkbox "Tournament manager checks results before acceptance"
* Einspielzeit
* verkürzte Einspielzeit (bei Wechsel an einen bereits bespielten Tisch)

**Zur Checkbox:** Normalerweise können die Spieler den Spielstatus fortschreiben z.B. nach `Partie beendet - OK?`. Wenn ein Check von Turniermanager erforderlich ist, wird dieses unterbunden und der Turnierleiter kann nach Abgleich mit dem Spielprotokoll den Tisch freigeben.

Die neuen Spielpaarungen erscheinen jeweils automatisch auf den Scoreboards.

### eMail mit den Spielergebnissen (csv) an den Turnierleiter

Nach Abschluss des Turniers erhält der Turnierleiter automatisch per eMail eine CSV-Datei mit den Ergebnissen in dem Format, welches für den Upload in die ClubCloud notwendig ist. Diese Datei wird auch auf dem lokalen Server gespeichert (`{carambus}/tmp/result-{ba_id}.csv`)

### Upload der Spielergebnisse (csv) in die ClubCloud
Der Turnierleiter kann die CSV-Datei direkt in die ClubCloud hochladen (er weiß wie das geht ;-)

### Abgleich mit der ClubCloud zum letzten Check
Als letzten Schritt kann noch einmal ein Abgleich mit der ClubCloud erfolgen. Die damit heruntergeladenen Daten sind Grundlage für später ausgerechnete Rankings.
