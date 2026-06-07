# Tischreservierung und Heizungssteuerung

*BC Wedel, Gernot, 7. Mai 2024*  
*Aktualisiert: 17. Februar 2026*

## 1. Tischreservierung

### Zugang zum Google Calendar
Tischreservierungen können ab sofort von berechtigten Mitgliedern im zentralen Google Calendar "BC Wedel" vorgenommen werden.

**Zugangslinks erhalten Sie durch eine formlose E-Mail an:**
- gernot.ullrich@gmx.de
- wcauel@gmail.com

### Wichtige Formatierung für Carambus-Auswertung
**Der Titel der Reservierung muss einem spezifischen Format folgen, damit Carambus die Reservierung korrekt auswerten kann.**

#### Gültige Reservierungstitel-Beispiele:

- **"T6 Gernot + Lothar"** - Einzelne Tischreservierung
- **"T1, T4-T8 Clubabend"** - Mehrere Tische für Clubabend
- **"T5, T7 NDM Cadre 35/2 Klasse 5-6"** - Turnierreservierung (Cadre wird rot hervorgehoben)
- **"T1-T6 Vereinsmeisterschaft (!)"** - Gesicherter Termin (Heizung bleibt während gesamter Dauer AN)

### Formatierungsregeln:
- **Tischnummern:** Verwenden Sie "T" gefolgt von der Tischnummer (z.B. T1, T6)
- **Mehrere Tische:** Trennen Sie mit Komma (T1, T4) oder Bereich (T4-T8)
- **Beschreibung:** Fügen Sie nach den Tischnummern eine Beschreibung hinzu
- **Turniere:** Verwenden Sie spezielle Schlüsselwörter wie "Cadre" für automatische Erkennung
- **Gesicherte Termine:** Fügen Sie "(!)" im Titel hinzu, um automatisches Abschalten zu verhindern

## 2. Heizungssteuerung - Detaillierte Regeln

### Automatisierte Steuerung
Die Tischheizungen werden automatisch basierend auf Kalendereinträgen und Scoreboard-Aktivitäten geschaltet.

### Regel 1: Heizung EIN (Normale Reservierung)

**Wann:** 2 Stunden vor Reservierung (4 Stunden bei Match Billard/Snooker)

**Bedingung:** Aktuelle Zeit > (Start - Vorheizzeit) UND < Ende

**Beispiel:** 
- Reservierung 18:00-22:00, großer Tisch (Match Billard/Snooker) → Heizung AN ab 14:00
- Reservierung 18:00-22:00, normaler Tisch → Heizung AN ab 16:00

**Besonderheit:** Wenn ein Termin kurz vor Beginn eingetragen wird, schaltet die Heizung sofort ein (innerhalb von 5 Minuten durch Cron-Check)

### Regel 2: Heizung EIN (Spontanes Spiel ohne Reservierung)

**Wann:** Sofort wenn Scoreboard eingeschaltet wird

**Verzögerung:** Max. 5 Minuten (Cron-Intervall)

**Bedingung:** Keine Reservierung erforderlich

**Beispiel:** Spieler kommt spontan zum Club, schaltet Scoreboard ein → Heizung geht automatisch an

### Regel 3: Heizung AUS (Scoreboard ausgeschaltet)

**Wann:** Sofort (innerhalb 5 Minuten) wenn Scoreboard ausgeschaltet wird

**Aktion:** Laufende Reservierung wird als "nicht wahrgenommen" markiert und gelöscht

**Ausnahme:** Gilt NICHT für Events mit "(!)" im Titel

**Beispiel:** Spieler beendet Spiel, schaltet Scoreboard aus → Heizung geht aus, Reservierung wird als nicht genutzt markiert

### Regel 4: Heizung AUS (Keine Aktivität nach Event-Start)

**Wann:** 30 Minuten nach Event-Anfang

**Bedingung:** Scoreboard wurde nicht eingeschaltet

**Grund:** Event wurde wahrscheinlich nicht wahrgenommen oder vergessen

**Ausnahme:** Gilt NICHT für Events mit "(!)" im Titel

**Beispiel:** Reservierung um 18:00, aber um 18:30 ist Scoreboard immer noch aus → Heizung wird ausgeschaltet

### Regel 5: Gesicherte Termine (Ausnahmeregelung "(!)")

**Markierung:** "(!)" im Kalendertitel

**Verhalten:** Heizung bleibt während gesamter Reservierungszeit AN, unabhängig von Scoreboard-Aktivität

**Anwendung:** Wichtige Turniere, Veranstaltungen, bei denen die Heizung garantiert laufen muss

**Beispiel:** "T1-T6 Vereinsmeisterschaft (!)" → Heizung bleibt von Vorheizzeit bis Ende-Zeit durchgehend an

**Wichtig:** Nach Ende der Reservierung wird die Heizung AUSGESCHALTET, auch bei "(!)" Events

**Ablauf:**
1. Event "T5 Test (!)" 16:25-17:25
2. Heizung AN ab 14:25 (2h Vorheizung)
3. Heizung bleibt AN bis 17:25 (auch ohne Scoreboard-Aktivität)
4. Um 17:30: Event ist beendet → Event wird gelöscht → Heizung wird SOFORT AUSGESCHALTET
5. Heizung geht AUS auch wenn Scoreboard noch läuft (Spieler hat vergessen auszuschalten)

**Technische Details:**
- Protection gilt nur WÄHREND event_id present ist
- Nach Event-Ende: Sofortiges Ausschalten, kein Warten auf Scoreboard
- Grund: "event finished" statt "inactivity detected"

### Regel 6: Turnier-Reservierungen

**Automatisch:** Turniere werden automatisch im Kalender eingetragen

**Absage:** Turnier im Kalender löschen oder als "ABGESAGT:" markieren → Heizung wird beim nächsten Check ausgeschaltet

**Status:** Manuelles Löschen im Kalender ist aktuell der Mechanismus für Turnier-Absagen

### Regel 7: Änderung bestehender Einträge

**Verhalten:** System erkennt geänderte Events automatisch durch Vergleich von:
- Event-ID (neues Event erkannt)
- Start-Zeit (Zeit wurde geändert)
- End-Zeit (Dauer wurde geändert)
- Titel/Summary (Beschreibung wurde geändert)

**Aktion:** Alte Termin-Daten werden überschrieben, neue Zeiten gelten sofort beim nächsten Cron-Check (max. 5 Minuten)

**Event-Löschung:** Event wird aus dem Tisch-Speicher entfernt wenn nicht mehr im Kalender vorhanden

**Beispiel:**
1. Event erstellt: "T5 Test, 14:30-15:30"
2. User ändert: "T5 Test, 15:40-16:40" (kommt später)
3. System erkennt: Start-Zeit geändert → Aktualisiert alle Daten
4. Heizung schaltet entsprechend der **neuen** Zeit

**Vorteil:** Kein "Gedächtnis" alter Termine - immer aktueller Kalender-Stand ist maßgeblich

### Technische Details

#### System-Parameter
- **Cron-Intervall:** Alle 5 Minuten
- **Scoreboard-Check:** Network Ping zur IP-Adresse des Tisches
- **Event-Window:** Events werden bis zur jeweiligen Vorheizzeit im Voraus geprüft (bis zu 4 Stunden bei Match Billard/Snooker, sonst 2 Stunden)
- **Vorheizzeiten:**
  - Match Billard: 4 Stunden
  - Snooker: 4 Stunden
  - Pool: Keine automatische Heizung
  - Andere Tische (Karambol): 2 Stunden

#### Toleranz-Zeiten
- **Vor Event-Start:** 120 Minuten (Heizung bleibt an in Vorheizphase)
- **Nach Event-Start:** 30 Minuten (Zeit zum Einschalten des Scoreboards)
- **Scoreboard-Check:** Sofort bei Erkennung

#### Logging und Debugging
- **Debug-Modus:** Aktiviert für detailliertes Logging
- **Log-Dateien:** 
  - `log/events` - Anstehende Kalender-Events
  - `log/table_status` - Aktueller Status aller Tische
  - `log/production.log` - Detaillierte Heizungs-Aktionen

### Vorteile der automatisierten Steuerung

- **Energieeffizienz:** Heizungen werden nur bei Bedarf eingeschaltet
- **Komfort:** Automatische Vorheizung vor Reservierungen
- **Kosteneinsparung:** Vermeidung unnötiger Heizkosten bei ungenutzten Tischen
- **Benutzerfreundlichkeit:** Keine manuelle Bedienung der Heizungen erforderlich
- **Flexibilität:** Spontanes Spielen ohne Reservierung möglich
- **Sicherheit:** Gesicherte Termine für wichtige Events

## 3. Fehlersuche und Problemlösung

### Heizung geht während des Spiels aus

**Mögliche Ursachen:**
1. **Scoreboard-Verbindung verloren:** Netzwerk-Ping schlägt fehl → System denkt Scoreboard ist aus
2. **Event bereits beendet:** Reservierungs-Ende wurde überschritten
3. **Event wurde gelöscht/geändert:** Kalender wurde aktualisiert und Event ist nicht mehr vorhanden

**Lösung:** Prüfen Sie die Log-Dateien für genaue Ursache (mit 🔥 HEATER OFF Markierung)

### Heizung geht nicht an

**Mögliche Ursachen:**
1. **Falsches Titel-Format:** Tischnummer nicht erkannt (z.B. "Tisch 6" statt "T6")
2. **Event zu weit in Zukunft:** Mehr als 2-3 Stunden bis Start
3. **Pool-Tisch:** Pool-Tische haben keine automatische Heizung

**Lösung:** Titel-Format prüfen, Cron-Log kontrollieren

### Event wird als "nicht wahrgenommen" markiert

**Ursache:** Scoreboard wurde innerhalb 30 Minuten nach Event-Start nicht eingeschaltet

**Lösung:** 
- Entweder: Scoreboard früher einschalten
- Oder: Event mit "(!)" markieren für garantierte Heizung

---

*Diese Dokumentation beschreibt die Integration von Google Calendar Reservierungen mit der Carambus Scoreboard-Technologie für eine vollautomatisierte Tisch- und Heizungsverwaltung im BC Wedel.*
