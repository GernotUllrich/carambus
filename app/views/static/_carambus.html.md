# Carambus Turnier Management

## Inhalt

1. [Einführung](#intro)

1. [Glossar](#glossar)

1. [Struktur](#structure)

1. [Carambus API.](#api)

1. [Regionales Turniermanagement.](#region_management)

1. [Lokales Spielmanagement.](#location_management)

## <a name="intro"></a>Einführung

Carambus zielt darauf, den gesamten Spielbetrieb auf Regional- und Vereinsebene zu automatisieren. Zunächst wird nur die Billardspielart Carambol in Deutschland mit den verschiedenen Disziplinen Freie Partie, Cadre, Einband und Dreiband in Einzelturnieren unterstützt. Mannschaftswettkämpfe und weitere Sportdisziplinen werden nach und nach hinzugefügt.

> Automatisierung mit Carambus bedeutet Unterstützung aller Phasen des Billardspiels von der Turnierplanung, der Festsetzung des Turniermodus, der Einteilung der Spielpaarungen entsprechend der Rang- und Setzlisten, der Tischzuordnung, der Realzeiterfassung der Spiele über die Anzeigetafeln bis zur Auswertung der Ergebnisse und Übertragung an die zentralen Verbände.

## <a name="glossar"></a>Glossar


## <a name="structure"></a>Struktur
Technisch gesehen ist Carambus eine Hierarchie von Webservices. An der Spitze steht ein Webserver, der nur dazu dient, externe Daten so Zeit aktuell und effizient wie möglich vorzuhalten. Konsumenten dieser Daten sind auf Regionalebene und am Veranstaltungsort, bzw. in den Clubheimen Webserver, die den lokalen Spielbetrieb verwalten.

Endgeräte dieser Webserver sind Webbrowser der Sportbeauftragten zur Planung und Abwicklung der Tourniere, sowie die verschieden Anzeige- und Eingabegeräte am Veranstaltungsort.

Da alles auf standardisierten HTML Protokollen basiert, ist Carambus weitgehend hardwareunabhängig.

## <a name="api"></a>Carambus API ##
Die Daten, die im Carambus API Server gespeichert werden, sind nur über spezielle REST URLs abrufbar.
Die Daten werden zur Übertragung verschlüsselt (SSL) und die zugreifenden regionalen Server müssen entsprechend autorisiert (auth0 Token) sein.
Folgende Daten werden vom API-Server zentral geliefert:

* Regionalverbände
    * BaId[1], Name, Kurzname, Logo, E-Mail, Adresse, Land
* Clubs
    * BaId, Region, Name, Kurzname, Adresse, Home-Page, E-Mail, Logo
* Spiellokale
    * Club, Region, Name, Adresse
* Tischausstattung
    * Tischarten, Zahl, Größe, Namen
* Spielerdaten
    * BaId, Club, Nachname, Vorname, Titel
* Saisonale Vereinszugehörigkeiten
    * Spieler, Saison, Club
* Turniere
    * BaId, Titel, Disziplin, Spielklasse, Modus, Zugangsbeschränkung, Datum, Akkreditierungsschluss, Spiellokal, Saison, Region, Schlussdatum, Aufnahmegrenze, Punktziel, Organisator (Club oder Region)
* Turniermoduspläne
    * Name, Regelsystem, Spielerzahl, Tischzahl, Beschreibung, Gruppenzahl, formaler Ablauf
* Turnier/Spieler Setzlisten
    * Spieler, Listenplatz, Turnier, ggf. Vorgaben bei Vorgabeturnieren
* Spiele
  * Turnier, Spielname, PlayerA, PlayerB
* Spielergebnisse
    * Spiel, Bälle, Aufnahmen, Höchstserie, Durchschnitt
* Spieler Rankings
    * Spieler, Disziplin, bester Einzeldurchschnitt, bester Turnierdurchschnitt

[1] Die BaId ist eine Zahl, die den jeweiligen Datensatz in der Billard-Area eindeutig beschreibt. Beispielsweise bezieht sich die BaId 121340 eines Spielers im Club mit der BaId 1573 im Regionalverband NBV auf die Webpage https://nbv.billardarea.de/cms_clubs/playerdetails/1573/121340.

## <a name="region_management"></a>Regionales Turniermanagement

Die Turnierverwaltung wird in folgenden Schritten vollzogen:

1. Aktualisierung der Turnierdaten.

    Vor dem Turnierstart sollte dafür gesorgt werden, dass das Turnier mit den Setzlisten in der Billard-Area aktualisiert ist. Die Synchronisierung mit dem lokalen Carambus Turniermanager kann dann angestoßen werden.
1. Festlegung der Setzliste:

    Mit der Synchronisierung wird die Liste der Teilnehmer übernommen. Aus den Ranglistenplätzen der Spieler wird die Setzliste abgeleitet. Der Spielleiter kann weitere Spieler zum Auffüllen von Ausfällen vornehmen und ggf. kleinere Umsetzungen vornehmen.

1. Auswahl des Turniermodus:

    Sobald die geordnete Spielerliste und damit auch die Zahl der Spieler feststeht, wird der Turniermodus ausgewählt.

    Im Allgemeinen gibt es mehrere Möglichkeiten (Gruppenspiele und Hauptrunde, ggf. mit Ausspielen der Plätze oder jeder gegen jeden etc.)

## <a name="location_management"></a>Lokales Spielmanagement

Sobald der Turniermodus festgelegt ist, kann das Turnier beginnen.

### Festlegung der Tische:
Aus der Menge der im Spiellokal zur Verfügung stehenden Tische werden die Tische 1-n aus dem Spielplan des Turniermodus zugeordnet.

###Festlegung einiger Parameter:
Vor dem Start können ggf. entsprechend der Turnierregeln noch folgende Parameter aktualisiert werden:

* Aufnahmebegrenzung
* Ballziel
* Einspielzeit an neuem Tisch
* Einspielzeit bei Rückkehr zu einem Tisch
* Bedenkzeit vor einem Stoß.

### Start und Ablauf des Spiels: 
Von nun an läuft alles automatisch ab. Auf den Anzeigetafeln erscheinen die Spielpaarungen mit Angabe der Gruppennummern und der Spielnamen (z. B. Gruppe 2 Spiel 2–4, also in der Gruppe 2 der 2. Spieler gegen den 4. Spieler).

Als erstes erscheint an den Anzeigetafeln die Aufforderung zum Einspielen mit entsprechenden Timern, z. B. 5 bzw. 3 Minuten.

Als nächstes erscheint die Aufforderung zum Anstoß. Im Ergebnis können die Spieler getauscht werden (Weiß stößt an, Gelb stößt nach).

Sobald Der anstoßende Spieler feststeht wird das Spiel gestartet.

Folgende Eingaben an den Anzeigetafeln sind möglich:

`+1`   Erhöhe die Ballzahl der laufenden Aufnahme um eins.

`-1`   Erniedrige die Ballzahl der laufenden Aufnahme um eins.

`nnn`  Setze die Ballzahl der laufenden Aufnahme. Zeige das Nummernfeld 0-9. 
        Eine belibige positive Zahl kann eingegeben werden. 
        Abschluss mit Enter oder Abbruch mit C

Die Aufnahme-Historie wird in der Anzeigetafel gezeigt und kann mit der Korrekturtaste auch noch vor Beendigung des Spiels korrigiert werden, s.u.

`DEL`   Mit einer Undo Taste kann auf eine beliebige Aufnahme zurückgegangen werden. Nach Korrektur mit +1, -1 oder nnn Eingabe wird durch mehrfachen Spielerwechsel bis zur aktuellen Aufnahme weitergeblättert.

`^v`    Spielerwechsel: Die aktuelle Ballzahl der beendeten Aufnahme wird gespeichert und der Summe hinzugefügt.  Der andere nun aktive Spieler wird an der Anzeigetafel markiert.

Der Schiedsrichter kann den Timer für die Bedenkzeit `>` starten, `o` beenden oder `||` anhalten

### Das Ende des Spiels 
wird anhand der Eingaben und der Aufnahme- bzw- Ballzahl automatisch erkannt.

An der Tafel wird ein Abschlussprotokoll angezeigt.  Die Spieler bestätigen das Ergebnis mit einer Eingabe auf der Anzeigetafel.
   
###Wechsel zur nächsten Runde
Sobald alle Spiele einer Runde beendet sind, startet automatisch die nächste Runde.  Die entsprechenden neuen Paarungen werden an den Anzeigetafeln angezeigt.

###Ende des Turniers
Sobald alle Spiele des Turniers abgeschlossen sind, wird ein Endprotokoll an den Spielleiter gesendet mit einer CSV-Datei, die dann direkt zum Upload der Ergebnisse in die Billard-Area genutzt werden kann.
