# Feature-Übersicht

Was Carambus heute kann, geordnet nach Einsatzbereich — und am Ende, was Carambus nicht kann. Jede Funktion auf
dieser Seite ist im Code nachgewiesen (Stand September 2026).

## Turniere (Karambol)

- **Turnierpläne:** die T-Pläne der Karambol-Turnierordnung und ein Jeder-gegen-Jeden-Plan für jede
  Teilnehmerzahl; KO- und Doppel-KO-Pläne; Gruppen mit anschließender KO-Runde oder Platzierungsspielen, je nach
  Plan
- **Gruppenrangfolge** nach Punkten, GD, direktem Vergleich, BED und Höchstserie; Stechen bei Gleichstand in
  KO-Spielen
- **Disziplinen:** Freie Partie, Cadre, Einband, Dreiband sowie Kegelbillard (BK-2, BK-2plus, BK-2kombi, BK50,
  BK100)
- **Einstellungen je Turnier:** Ballziel, Aufnahmebegrenzung, Bedenkzeit, Einspielzeit, Sätze, Anstoßwechsel,
  Nachstoß
- **Ablauf:** Setzliste aus der PDF-Einladung übernehmen, Spiele automatisch den Tischen zuordnen (auf Wunsch,
  sobald ein Tisch frei wird), Rundenwechsel automatisch
- **Turnier-Monitor:** Gruppen, laufende Spiele, KO-Baum, Ergebnisse und Rangliste; er zeigt auch, auf welche
  Spiele eine Runde noch wartet
- **Ohne ClubCloud:** Einzelmeisterschaften mit Meldeliste und Ergebnisliste über den Region Server des Verbands
  ([CC-loses Turniermanagement](../administrators/cc-less-tournament-management.md))

Handbuch: [Turnierverwaltung](../managers/tournament-management.md)

## Turnier-App {#turnier-app}

Eine Browser-App für die Turnierleitung, die der Vereinsserver unter `/app/` mit ausliefert. Sie führt ein Turnier
selbst, legt die Spiele auf die Scoreboards der Tische und bekommt die Ergebnisse von dort zurück; Ergebnisse
lassen sich auch direkt in der App eintragen.

- **Turnierformen:** KO-System (Einfach- und Doppel-KO nach den ClubCloud-Plänen, auch in Pool und Snooker),
  3-Band-Mannschaftsmeisterschaft (4 Mannschaften × 4 Spieler), Turnierpläne T01–T24 mit Gruppen und
  Finalrunde, Liga-Spieltag
- **Turnierstand:** Hängt ein Turnierplan an einem im Carambus angelegten Turnier, liegt der Stand auf dem Server;
  dann können mehrere Geräte und Turnierleiter daran arbeiten. Sonst liegt der Stand im Browser des Geräts.
- **Ergebnisarchiv:** Endstand und Partien gehen automatisch auf den Vereinsserver und stehen dort auf der
  Turnierseite (KO, Mannschaftsmeisterschaft, Turnierpläne).
- **Im Einsatz:** internationales Damenturnier im BC Wedel, August 2026 (Dreiband, Turnierplan). Pool- und
  Snooker-Turniere sind mit der App noch nicht gespielt worden.
- **Voraussetzungen:** Die Auslieferung wird in der Server-Konfiguration eingeschaltet; die App meldet sich mit
  einem Dienstkonto der Region an, das ein Admin anlegt. Ein App-Turnier im Carambus anzulegen verlangt heute
  Einstellungen, die man kennen muss (manuelle Spielzuordnung, Enddatum in der Zukunft).

## Scoreboards

- **Karambol:** Stand, Aufnahmen, GD, Höchstserie, Restbälle, Bedenkzeit-Uhr
- **Pool:** 8-, 9- und 10-Ball sowie 14.1 endlos (mit Foulzähler), Gewinnsätze, Winner- oder Wechsel-Break
- **Snooker:** Frames (Best-of), Break, Restpunkte, Farben im Spiel, 6, 10 oder 15 Rote, Foul-Eingabe
- Pool und Snooker laufen in freien Partien, an Ligaspieltagen und in KO-Turnieren der
  [Turnier-App](#turnier-app); der Turnier-Monitor führt nur Karambol-Turniere.
- **Am Tisch:** Raspberry Pi mit Monitor oder Touch-Display im Kiosk-Modus, oder jeder Browser; eine
  Bildschirmtastatur erlaubt die Anmeldung ohne angeschlossene Tastatur
- **Korrekturen:** Rücknahme am Scoreboard und Protokolleditor vor der Bestätigung; Spielprotokoll als PDF
- Alle Anzeigen aktualisieren sich in Echtzeit.

Handbuch: [Scoreboard-Anleitung](../players/scoreboard-guide.md)

## Liga

- Ligen, Mannschaften und Spieltage kommen aus der ClubCloud.
- **Party-Monitor** für den Spieltag: Aufstellung aus den spielberechtigten Spielern, Tisch- und
  Spielerzuordnung, Ergebnisbestätigung, Mannschaftsstand
- **Ligatabellen** für Karambol, Pool und Snooker

Handbuch: [Ligaverwaltung](../managers/league-management.md)

## ClubCloud

- Die Authority liest Turniere, Spieler, Vereine und Ligen aus der DBU-ClubCloud; Spieler werden über die
  DBU-Nummer zugeordnet.
- Die Teilnehmerliste lässt sich mit dem eigenen ClubCloud-Zugang abschließen.
- Ergebnisse gehen automatisch nach jedem Spiel oder am Ende als CSV-Datei in die ClubCloud.

Handbuch: [ClubCloud-Integration](../managers/clubcloud-integration.md)

## Im Vereinsheim

- **Tischreservierung** über den Google-Kalender des Vereins; nach dem Meldeschluss reserviert Carambus die Tische
  für ein Turnier automatisch ([Tischreservierung und Heizung](../managers/table_reservation_heating_control.md))
- **Heizungssteuerung:** Carambus schaltet die Tischheizungen über TP-Link-WLAN-Steckdosen — zum Vorheizen vor
  einer Reservierung, bei Scoreboard-Aktivität ein, bei Inaktivität aus
- **Training:** Trainingsspiele am Scoreboard werden gewertet; bei der Spielerauswahl stehen die Spieler oben, die
  zuletzt so trainiert haben
- **Streaming:** YouTube-Live-Übertragung der Tische mit Scoreboard-Overlay
  ([Streaming-Setup](../administrators/streaming-setup.md))
- **Scoreboard-Nachrichten** aus der Verwaltung an die Tische
- **Terminkalender** mit Turnieren und Liga-Spieltagen

## Suche und Assistenten

- **Filter** in den Listen (Spieler, Turniere, Vereine …) mit Eingabefeldern für Datum, Zahl und Auswahl
  ([Filter-Popup](../managers/filter_popup_usage.md))
- **KI-Suche:** übersetzt eine Frage in natürlicher Sprache in einen Listenfilter. Voraussetzung ist ein
  Anthropic-API-Schlüssel (laufende Kosten); die Suchanfrage geht an Anthropic.
- **ClubCloud-Assistent (MCP):** Sportwarte erledigen ClubCloud-Aufgaben per natürlicher Sprache in Claude Code.
  Voraussetzung sind Claude Code auf dem eigenen Rechner und ein Konto auf dem Carambus-Server der Region
  ([Quickstart](../managers/clubcloud-mcp-cloud-quickstart.md)).

## Ranglisten, Spieler, internationale Daten

- Ranglisten je Saison und Disziplin (Siege, Niederlagen, GD, Höchstserie, BED) und regionale Ranglisten über
  mehrere Saisons
- Öffentliches Spielerprofil mit Ranglisten und Turnierteilnahmen
- Internationale Turnierdaten (UMB, Cuesco) und Videos (Kozoom, YouTube)

## Schnittstellen

- **Bridge:** die JSON-Schnittstelle, über die die [Turnier-App](#turnier-app) — und andere Turnier-Apps — mit
  Carambus sprechen, mit Token-Anmeldung ([External Tournament Bridge](../managers/external-tournament-bridge.md))

## Benutzer und Rechte

- Rollen: Spieler, Vereins-Admin, System-Admin; dazu die Aufgaben Sportwart (Standort) und Landessportwart
  (Region) sowie die Turnierleitung je Turnier
- Vereinsmitglieder melden sich mit einer PIN an und pflegen ihre E-Mail-Adresse und Einwilligung selbst; die
  PIN-Sitzung endet nach Untätigkeit, nach wiederholten Fehlversuchen wird die Anmeldung vorübergehend gesperrt

## Sprachen

- Oberfläche und Dokumentation auf Deutsch und Englisch

<a id="nicht-enthalten"></a>
## Was Carambus nicht kann

Folgendes gibt es in Carambus nicht, auch wenn frühere Fassungen dieser Seite es nannten:

- Pool- und Snooker-Turniere mit Gruppen und Turnierplänen (KO geht über die Turnier-App) und das Schweizer System
- Ein Online-Buchungssystem mit eigener Kalender-Ansicht, Buchungsbestätigung und Stornierung — Reservierungen
  laufen über den Google-Kalender des Vereins
- Einen Offline-Modus der Carambus-Oberfläche, Installation auf dem Home-Screen und Push-Benachrichtigungen;
  Benachrichtigungen über anstehende Spiele
- Zwei-Faktor-Anmeldung und Anmeldung über Google oder Facebook
- Datenexport und Anonymisierung für Spieler; das Löschen von Spielerdaten, die aus der ClubCloud kommen
- Eine Änderungshistorie für Spielergebnisse mit Rückgängig-Funktion
- Statistik-Auswertungen (Turnier-, Vereins- und Head-to-Head-Statistiken), periodische Reports, CSV- oder
  PDF-Export von Listen
- Eine offene REST-API für Statistiken, Webhooks, ein Plugin-System
- Kommentare, Foto-Upload, Teilen in sozialen Netzwerken
