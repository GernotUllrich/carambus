# Turniermanager-Dokumentation

Willkommen zur Carambus-Dokumentation für Turniermanager! Hier finden Sie die Informationen zur Durchführung von Billardturnieren und Ligaspieltagen mit Carambus.

## 🎯 Ihre Rolle als Turniermanager

Als Turniermanager sind Sie verantwortlich für:
- ✅ **Turniervorbereitung**: Turnier aus der ClubCloud laden, Setzliste übernehmen, Teilnehmerliste prüfen und abschließen
- ✅ **Turniermodus**: den passenden Turnierplan wählen; die Paarungen ergeben sich daraus
- ✅ **Turnierdurchführung**: Tische zuordnen, Turnier starten, den Turnier-Monitor beobachten
- ✅ **Ergebniskontrolle**: Die Spieler erfassen und korrigieren am Scoreboard; Sie greifen bei Problemen ein
- ✅ **Abschluss**: Endrangliste im Turnier-Monitor, Ergebnisse in die ClubCloud übertragen

## 🚀 Schnellstart: Turnier synchronisieren und durchführen in 10 Schritten

1. **Turnier aus ClubCloud synchronisieren** → [Schritt 2](tournament-management.md#step-2-load-clubcloud)
2. **Setzliste übernehmen** → [Schritt 3](tournament-management.md#step-3-seeding-list)
3. **Teilnehmerliste prüfen und ergänzen** → [Schritt 4](tournament-management.md#step-4-participants)
4. **Teilnehmerliste abschließen** → [Schritt 5](tournament-management.md#step-5-finish-seeding)
5. **Turniermodus auswählen** → [Schritt 6](tournament-management.md#step-6-mode-selection)
6. **Start-Parameter ausfüllen** → [Schritt 7](tournament-management.md#step-7-start-form)
7. **Tische zuordnen und Turnier starten** → [Schritt 8–9](tournament-management.md#step-8-tables)
8. **Warmup und Spielbeginn** → [Schritt 10–11](tournament-management.md#step-10-warmup)
9. **Ergebnisse verfolgen und finalisieren** → [Schritt 12–13](tournament-management.md#step-12-monitor)
10. **Ergebnis-Upload nach ClubCloud** → [Schritt 14](tournament-management.md#step-14-upload)

➡️ **[Zur vollständigen Durchführungs-Anleitung](tournament-management.md#walkthrough)**

## 📚 Hauptthemen

### 1. Turnierverwaltung

**Einzel-Turniere organisieren**:
- Turnierpläne aus der Karambol-Turnierordnung (T-Pläne) und der dynamische Jeder-gegen-Jeden-Plan `Default{n}`
- Gruppenphasen, KO-Runden und Platzierungsspiele, so wie der gewählte Plan sie vorsieht
- Setzliste aus der Einladung oder aus der Rangliste
- Stechen bei unentschiedenen KO-Partien

➡️ **[Turnierverwaltungs-Handbuch](tournament-management.md)**  
➡️ **[Einzelturnier-Verwaltung](single-tournament.md)**  
➡️ **[Kurzreferenz](tournament-quick-reference.md)**

### 2. Ligaspieltage

**Mannschaftswettbewerbe durchführen**:
- Ligen, Mannschaften und Spieltage kommen aus der ClubCloud (TBV aus dem LigaManager, BBV aus NuLiga)
- Spieltage am Party-Monitor durchführen
- Tabellen auf der Liga-Seite

➡️ **[Liga-Management-Handbuch](league-management.md)**

### 3. Spielerverwaltung

**Teilnehmer verwalten**:
- Spieler kommen per Scraping aus der ClubCloud
- Teilnehmerliste prüfen und ergänzen, auch um Nachmeldungen am Turniertag
- Spieler-Dubletten zusammenführen (auf der Authority)

➡️ **[Teilnehmerliste prüfen und ergänzen](tournament-management.md#step-4-participants)**  
➡️ **[Spieler-Nachmeldung am Turniertag](tournament-management.md#appendix-nachmeldung)**  
➡️ **[Duplikate](clubcloud-integration.md)**

### 4. Ergebniserfassung & -kontrolle

**Ergebnisse verwalten**:
- Die Spieler erfassen die Ergebnisse am Scoreboard
- Korrekturen vor der Bestätigung im Protokolleditor am Scoreboard (z. B. ein vergessener Nachstoß)
- Bei Scoreboard-Ausfall: Ergebnisse von Papierprotokollen im Turnier-Monitor nachtragen
- Nach dem Start: „Turnier neu starten“ statt Zurücksetzen

➡️ **[Beobachten und bei Bedarf eingreifen](tournament-management.md#step-12-monitor)**  
➡️ **[Turnier bereits gestartet — und etwas läuft schief](tournament-management.md#ts-already-started)**

### 5. Admin-Rollen & Berechtigungen

**Rollen und Rechte**:
- Rollen in Carambus: Spieler, Vereins-Admin, System-Admin
- Sportwart- und Landessportwart-Persona sowie Turnierleitung für Schreibaktionen in der ClubCloud; die Persona setzt ein System-Admin

➡️ **[Admin-Rollen-Handbuch](admin-roles.md)**  
➡️ **[ClubCloud-Rollenmodell](clubcloud-scenarios/cc-roles.md)**

### 6. ClubCloud-Integration

**DBU ClubCloud anbinden**:
- Turniere, Spieler, Vereine und Ligen aus der ClubCloud übernehmen
- Teilnehmerliste in der ClubCloud abschließen (mit eigenem CC-Zugang)
- Ergebnisse hochladen (automatisch je Spiel oder per CSV)

➡️ **[ClubCloud-Integrations-Leitfaden](clubcloud-integration.md)**  
➡️ **[Eigener ClubCloud-Zugang](clubcloud-eigener-zugang.md)**

### 7. Suche & Filter

**Daten effizient finden**:
- Filter-Popup in den Listen, mit Eingabefeldern passend zum Feldtyp
- KI-gestützte Suche

➡️ **[Filter-Popup-Anleitung](filter_popup_usage.md)**  
➡️ **[KI-Suche](../players/ai-search.md)**

### 8. Tischreservierung

**Vereinszeiten verwalten**:
- Reservierungen im Google-Kalender des Vereins
- Automatische Tischreservierung für Turniere nach dem Meldeschluss
- Vorheizen der Tische vor Reservierungsbeginn

➡️ **[Automatische Tischreservierung](automatische_tischreservierung.md)**  
➡️ **[Tischreservierung & Heizungssteuerung](table_reservation_heating_control.md)**

## 🎮 Turniermodi

### Turnierpläne

Den Ablauf eines Turniers bestimmt der **Turnierplan**. Carambus bietet in Schritt 6 die Pläne an, die zur Teilnehmerzahl passen: die T-Pläne der Karambol-Turnierordnung mit fester Spielstruktur und Tischanzahl und den dynamisch erzeugten Jeder-gegen-Jeden-Plan `Default{n}`. Der in der Einladung angegebene Plan ist in der Regel verbindlich.

➡️ **[Turniermodus auswählen](tournament-management.md#step-6-mode-selection)**

### Gruppen, KO und Platzierungsspiele

Je nach Plan folgt auf eine Gruppenphase (jeder gegen jeden) eine KO-Runde oder es folgen Platzierungsspiele. Die Rangfolge in der Gruppe folgt der Turnierordnung (§4.4.2: Punkte, Generaldurchschnitt, direkter Vergleich, bester Einzeldurchschnitt, Höchstserie). Eine unentschiedene KO-Partie entscheidet ein Stechen.

➡️ **[Turnier abschließen](tournament-management.md#step-13-finalize)**

## 🛠️ Wichtige Funktionen

### Automatische Spielzuordnung

**Features**:
- Die Paarungen jeder Runde ergeben sich aus dem Turnierplan
- Spielfreie Runden (Freilos) ergeben sich ebenfalls aus dem Plan
- Optional: „Spiele zuordnen, sobald Tische frei werden“

**Tischzuordnung**:
- Vor dem Start ordnen Sie die Tische des Plans den Tischen Ihres Spiellokals zu
- Nach dem Start ist diese Zuordnung fest; ein Scoreboard lässt sich aber auf einen anderen Tisch umstellen

➡️ **[Tischzuordnung](tournament-management.md#step-8-tables)**

### Turnier-Monitor

**Turnier-Überwachung in Echtzeit**:
- Spiele der laufenden Runde mit Bällen, Aufnahmen, Höchstserie und Generaldurchschnitt
- Tisch-Scoreboards in eigenen Browser-Tabs öffnen
- Rundenwechsel automatisch, sobald das letzte Spiel der Runde bestätigt ist

**Anzeige-Optionen**:
- Turnier-Monitor (Einzelturniere)
- Party-Monitor (Ligaspieltage)
- Scoreboard (pro Tisch)

➡️ **[Beobachten und bei Bedarf eingreifen](tournament-management.md#step-12-monitor)**

### Ergebnis-Korrektur

**Wie korrigieren?**:
- Vor der Bestätigung im Protokolleditor am Scoreboard

Eine Änderungshistorie für Spielergebnisse führt Carambus nicht.

➡️ **[Nachstoß am Scoreboard vergessen](tournament-management.md#ts-nachstoss-forgotten)**

### Auswertungen

**Verfügbar**:
- Endrangliste im Turnier-Monitor
- Spielprotokoll einer Partie als PDF
- Ergebnis-CSV für den ClubCloud-Upload
- Tabellen auf der Liga-Seite

➡️ **[Turnier abschließen](tournament-management.md#step-13-finalize)**

## 🎓 Best Practices

### Vorbereitung

**Eine Woche vorher**:
- ✅ Turnier in der ClubCloud prüfen und in Carambus laden
- ✅ Tische prüfen (Heizung!)

**Einen Tag vorher**:
- ✅ Teilnehmerliste prüfen
- ✅ Turnierplan laut Einladung bereitlegen
- ✅ Displays testen

**Am Turniertag**:
- ✅ 1 Stunde vorher: System hochfahren
- ✅ Turnier-Monitor auf Beamer
- ✅ Scoreboards an Tischen aktivieren
- ✅ Testspiel durchführen

### Während des Turniers

**Kontinuierliche Aufgaben**:
- 🔍 Spielfortschritt am Turnier-Monitor überwachen
- 🔍 Technische Probleme beheben
- 🔍 Spieler-Fragen beantworten
- 🔍 Pausen koordinieren

**Bei Problemen**:
- Ruhe bewahren
- Regelwerk konsultieren
- Änderungen dokumentieren

### Nach dem Turnier

**Abschluss-Aufgaben**:
- ✅ Ergebnisse zu ClubCloud hochladen
- ✅ Endrangliste in der ClubCloud pflegen ([Anleitung](tournament-management.md#appendix-rangliste-manual))
- ✅ Feedback einholen
- ✅ Erkenntnisse dokumentieren

## 🆘 Häufige Probleme & Lösungen

### Vor dem Turnier

- **Spieler fehlen in der ClubCloud-Meldeliste** → [Lösung](tournament-management.md#ts-player-not-in-cc)
- **Einladungs-PDF lässt sich nicht hochladen** → [Lösung](tournament-management.md#ts-invitation-upload)
- **Falscher Turniermodus gewählt** → [Lösung](tournament-management.md#ts-wrong-mode)

### Während des Turniers

- **Turnier gestartet, und etwas läuft schief** → [Lösung](tournament-management.md#ts-already-started)
- **Nachstoß am Scoreboard vergessen** → [Lösung](tournament-management.md#ts-nachstoss-forgotten)
- **Spieler zieht während des Turniers zurück** → [Lösung](tournament-management.md#ts-player-withdraws)
- **Spieler erscheint nicht zum Turnier** → [Lösung](tournament-management.md#appendix-missing-player)
- **Stechen nötig** → [Lösung](tournament-management.md#ts-shootout-needed)
- **Scoreboard fällt aus** → ein freies Scoreboard am Nachbartisch auf den ausgefallenen Tisch umstellen ([Tischzuordnung](tournament-management.md#step-8-tables))

### Nach dem Turnier

- **Endrangliste fehlt in der ClubCloud** → [Lösung](tournament-management.md#ts-endrangliste-missing)
- **CSV-Upload in die ClubCloud funktioniert nicht** → [Lösung](tournament-management.md#ts-csv-upload)
- **Automatischer Upload fehlgeschlagen** → [ClubCloud Upload-Feedback](clubcloud_upload_feedback.md)

## 📱 Geräte-Empfehlungen

### Für den Turniermanager

**Desktop/Laptop**:
- Große Übersicht über alle Spiele
- Mehrere Tabs parallel (Turnier-Monitor und Tisch-Scoreboards)

**Tablet**:
- Mobil im Vereinsheim
- Ideal für kleinere Turniere

### Für Anzeigen

**Turnier-Monitor**:
- TV/Beamer mit HDMI
- Browser im Vollbild, z. B. auf einem Raspberry Pi

**Scoreboards**:
- Im Vereinsbetrieb: Raspberry Pi mit Touch-Display im Kiosk-Modus
- Sonst jeder Browser (Tisch-Monitor, Smartphone, Web-Client)
- Netzwerkverbindung zum Carambus-Server

➡️ **[Raspberry Pi Quickstart](../administrators/raspberry-pi-quickstart.md)**

## 🔐 Berechtigungen & Delegation

### Rollen-System

**System-Admin**: volle Verwaltung, vergibt Rollen und Personas  
**Vereins-Admin**: Vereinsdaten und Turniere  
**Spieler**: kein Management

Dazu kommen die **Personas** Sportwart und Landessportwart sowie die **Turnierleitung** eines Turniers. Sie bestimmen, wer Schreibaktionen in der ClubCloud ausführen darf.

➡️ **[Detaillierte Rollen-Beschreibung](admin-roles.md)**

### Aufgaben delegieren

**Sie können einsetzen** (als Sportwart im eigenen Wirkbereich oder als Admin):
- **Turnierleiter** für ein bestimmtes Turnier. Ohne eigenen ClubCloud-Zugang kann er den Zugang des Sportwarts erben, der ihn eingesetzt hat ([Eigener ClubCloud-Zugang](clubcloud-eigener-zugang.md))

**Best Practice**: 
- Mindestens 2 Personen mit Manager-Rechten
- Klare Kommunikation über Zuständigkeiten

## 📞 Support & Ressourcen

### Dokumentation

- **[Turnierverwaltung](tournament-management.md)**: Vollständiges Handbuch
- **[Liga-Management](league-management.md)**: Ligaspieltage organisieren
- **[Admin-Rollen](admin-roles.md)**: Berechtigungen verwalten
- **[ClubCloud](clubcloud-integration.md)**: Integration nutzen
- **[Glossar](../reference/glossary.md)**: Alle Fachbegriffe

### Hilfe bei Problemen

**Während des Turniers**:
- Dokumentation durchsuchen
- Andere Manager im Verein fragen
- Notfallkontakt: gernot.ullrich@gmx.de

**Nicht-dringend**:
- GitHub Issues: [https://github.com/GernotUllrich/carambus/issues](https://github.com/GernotUllrich/carambus/issues)
- E-Mail: gernot.ullrich@gmx.de

## 🔗 Alle Manager-Dokumente

1. **[Turnierverwaltung](tournament-management.md)** - Komplettes Handbuch für Einzelturniere
2. **[Kurzreferenz](tournament-quick-reference.md)** - Turnierablauf auf einen Blick
3. **[Einzelturnier-Verwaltung](single-tournament.md)** - Der Turnier-Wizard im Detail
4. **[Liga-Management](league-management.md)** - Ligaspieltage und Mannschaftswettbewerbe
5. **[Automatische Tischreservierung](automatische_tischreservierung.md)** - Reservierung und Vorheizen für Turniere
6. **[Admin-Rollen](admin-roles.md)** - Benutzer und Berechtigungen verwalten
7. **[ClubCloud-Integration](clubcloud-integration.md)** - DBU ClubCloud anbinden
8. **[ClubCloud-MCP Cloud-Quickstart](clubcloud-mcp-cloud-quickstart.md)** - Turnierarbeit per KI-Assistent
9. **[Externe Turnier-App (Bridge)](external-tournament-bridge.md)** - Mehrere Turniere an einer Location
10. **[Filter-Popup](filter_popup_usage.md)** - Effizient Daten finden

---

**Viel Erfolg bei Ihren Turnieren! 🏆**

*Tipp: Fügen Sie diese Seite zu Ihren Lesezeichen hinzu. Sie dient als zentrale Anlaufstelle für alle Turniermanagement-Aufgaben.*
