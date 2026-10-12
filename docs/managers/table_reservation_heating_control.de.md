# Tischreservierung und Heizungssteuerung

Carambus hat kein eigenes Buchungssystem. Tische reserviert man im **Google-Kalender des Vereins**. Carambus liest diese
Termine regelmäßig und schaltet danach die Tischheizungen, zusätzlich je nachdem, ob das Scoreboard eines Tisches läuft.

## Voraussetzungen {#requirements}

Einmalig einzurichten, durch den Administrator des Vereinsservers:

- **Je Tisch eine schaltbare Steckdose** vom Typ TP-Link Kasa. Carambus schaltet sie über deren lokales Protokoll
  (Port 9999). Welche Geräte- und Firmware-Generationen das noch unterstützen, ist nicht geprüft.
- **Feste IP-Adressen** für Steckdosen und Scoreboards. Unter `/table_locals` (nur System-Admin) trägt man je Tisch
  die IP der Steckdose (`tpl_ip_address`) und die des Scoreboard-Geräts (`ip_address`) ein.
- **Google-Dienstkonto** mit Schreibrecht auf den Vereinskalender. In den Credentials des Servers stehen
  `google_service` (Schlüssel des Dienstkontos), `location_calendar_id` (der Kalender) und `location_id` (das
  Spiellokal).
- **Ein Crontab-Eintrag** für den Prüflauf `rake carambus:check_reservations`. Er steht nicht in
  `config/schedule.rb` und wird deshalb von Hand eingetragen, empfohlen alle 5 Minuten. Ohne ihn schaltet keine Heizung.
- Geschaltet wird nur auf dem produktiven Server (`RAILS_ENV=production`).

Den Zugang zum Kalender vergibt der Kalender-Administrator Ihres Vereins.

## 1. Tischreservierung {#reservation}

### Im Google-Kalender

Berechtigte Mitglieder tragen Termine direkt im Vereinskalender ein. Ändern und Löschen geht nur dort.

### Am Scoreboard

Auf der Startseite des Scoreboards führt **Reservierungen** zu den nächsten Terminen und zu **Neue
Tischreservierung** (Titel, Datum, von–bis, Speichern). Der Termin landet im selben Google-Kalender.

!!! warning "Winterzeit"
    Das Scoreboard-Formular rechnet die Uhrzeit fest mit UTC+2 (Sommerzeit) um. Zwischen Ende Oktober und Ende März
    liegt ein dort angelegter Termin deshalb eine Stunde zu früh. Im Winter lieber im Kalender reservieren.

### Titel des Termins {#title-format}

Aus dem Titel liest Carambus, welche Tische gemeint sind.

**Beispiele:**

- **„T6 Müller + Schmidt“**: ein Tisch
- **„T1, T4-T8 Clubabend“**: mehrere Tische
- **„T5, T7 Cadre 35/2 Klasse 5-6“**: Turnierreservierung, so legt sie die automatische Turnier-Reservierung an
- **„T1-T6 Vereinsmeisterschaft (!)“**: gesicherter Termin (siehe Regel 5)

**Regeln:**

- **Tischangabe:** ein großes „T“ direkt vor der Zahl (`T6`). „Tisch 6“ oder „t6“ werden nicht erkannt.
- **Was „T6“ bedeutet:** den **6. Tisch des Spiellokals in der Sortierung nach Tischname**, nicht den Tisch mit der 6 im
  Namen. Solange die Tische „Tisch 1“ bis „Tisch 9“ heißen, stimmt beides überein. Ab zehn Tischen („Tisch 10“ sortiert
  vor „Tisch 2“) oder bei gemischten Namen weicht es ab; prüfen Sie die Reihenfolge in der Tischliste des Spiellokals.
- **Mehrere Tische:** mit Komma (`T1, T4`) oder als Bereich (`T4-T8`, beide Enden mit T).
- **Nur vorhandene Tische** angeben. Eine T-Nummer größer als die Zahl der Tische lässt derzeit den ganzen Prüflauf
  abbrechen, dann schaltet für keinen Tisch die Heizung.
- **Beschreibung:** Der Text nach den Tischangaben ist frei und dient nur der Anzeige.
- **Gesicherte Termine:** „(!)“ irgendwo im Titel verhindert das automatische Abschalten während des Termins.

!!! danger "Termine ohne erkennbare Tischangabe werden gelöscht"
    Findet der Prüflauf in einem Titel keinen Tisch, löscht er den Termin aus dem Google-Kalender. Das betrifft
    derzeit auch Termine, die **nur Pool-Tische** nennen.
    Reine Hinweis-Einträge beginnen mit einem Wort und Doppelpunkt, z. B. `info: Club geschlossen`; sie bleiben
    stehen und heizen nicht.

## 2. Heizungssteuerung: die Regeln {#rules}

Jeder Prüflauf liest die kommenden Termine aus dem Kalender und fragt per Ping, ob das Scoreboard-Gerät eines Tisches im
Netz erreichbar ist. „Scoreboard an“ heißt im Folgenden genau das: Das Gerät unter der eingetragenen IP antwortet.

### Regel 1: Heizung an vor einer Reservierung

**Vorheizzeit:** 2 Stunden vor Beginn; 4 Stunden bei Tischen der Art „Match Billard“ oder „Snooker“. Pool-Tische
werden nicht nach Kalender geheizt.

**Beispiel:** Reservierung 18:00–22:00 an einem normalen Tisch → Heizung an ab 16:00.

**Große Tische:** Zwischen 4 und 2 Stunden vor Beginn schaltet der Prüflauf die Heizung derzeit ein und im selben Lauf
wieder aus, solange das Scoreboard nicht läuft. Zuverlässig an ist sie erst 2 Stunden vorher. Für volle 4 Stunden den
Termin mit „(!)“ versehen.

**Kurzfristige Termine:** Wird ein Termin innerhalb der Vorheizzeit eingetragen, schaltet der nächste Prüflauf die
Heizung ein.

### Regel 2: Heizung an bei spontanem Spiel

Sobald das Scoreboard eines Tisches an ist, schaltet der nächste Prüflauf die Heizung ein, auch ohne Reservierung
(und auch an Pool-Tischen mit eingetragener Steckdose). Ein Scoreboard, das nie ausgeschaltet wird, hält die Heizung
also dauerhaft an.

### Regel 3: Heizung aus, wenn das Scoreboard aus ist

- **Ohne laufende Reservierung:** Heizung aus beim nächsten Prüflauf.
- **Mit Reservierung:** In den 2 Stunden vor Beginn und in den ersten 30 Minuten danach bleibt die Heizung an; danach
  gilt Regel 4.
- Der Kalendertermin bleibt dabei unverändert.

### Regel 4: Heizung aus ohne Spiel nach Terminbeginn

Ist das Scoreboard 30 Minuten nach Terminbeginn noch aus, geht die Heizung aus (Grund im Log:
`inactivity detected`). Ausnahme: Termine mit „(!)“.

### Regel 5: Gesicherte Termine „(!)“

Mit „(!)“ im Titel bleibt die Heizung von der Vorheizzeit bis zum Terminende an, unabhängig vom Scoreboard.
Einsatz: Turniere und Veranstaltungen, bei denen die Heizung sicher laufen muss.

**Nach Terminende** schaltet der nächste Prüflauf die Heizung aus (Grund `event finished`), auch bei „(!)“. Ist das
Scoreboard dann noch an, schaltet sie der folgende Lauf nach Regel 2 wieder ein. Scoreboard nach dem Spiel ausschalten.

### Regel 6: Turnier-Reservierungen

Turniere trägt die Task `carambus:auto_reserve_tables` nach Meldeschluss in den Kalender ein, wenn sie per Crontab
eingerichtet ist. Details: [Automatische Tischreservierung](automatische_tischreservierung.md).

**Absage:** Alle Kalendereinträge des Turniers löschen (die Automatik kann mehrere angelegt haben; innerhalb von 7
Tagen nach Meldeschluss legt sie gelöschte neu an) und das Scoreboard ausschalten. Ein Umbenennen in „ABGESAGT: …“
stoppt eine bereits laufende Vorheizung nicht sofort.

### Regel 7: Geänderte Termine

Carambus erkennt geänderte Termine an Termin-ID, Beginn, Ende und Titel und übernimmt die neuen Daten beim nächsten
Prüflauf. Die Heizung richtet sich dann nach der neuen Zeit. Verschwindet ein Termin aus dem Kalender, wird er auch am
Tisch vergessen.

**Beispiel:** Termin „T5 Training, 14:30–15:30“ wird auf 15:40–16:40 verschoben → der nächste Lauf heizt nach der
neuen Zeit.

### Technische Details {#technical}

**Parameter:**

- **Prüfintervall:** so oft, wie die Crontab-Zeile es vorgibt (empfohlen: alle 5 Minuten)
- **Scoreboard-Prüfung:** Ping auf die IP-Adresse des Scoreboard-Geräts
- **Vorausschau:** Termine werden ab ihrer Vorheizzeit ausgewertet (2 bzw. 4 Stunden)
- **Vorheizzeiten:** Match Billard und Snooker 4 Stunden, andere Tische (Karambol) 2 Stunden, Pool keine
  kalenderbasierte Heizung

**Toleranzen:**

- **Vor Terminbeginn:** 120 Minuten (Heizung bleibt in der Vorheizphase an)
- **Nach Terminbeginn:** 30 Minuten (Zeit zum Einschalten des Scoreboards)

**Protokolle:**

- `log/events`: kommende Kalendertermine
- `log/table_status`: aktueller Zustand aller Tische
- Rails-Log des Servers: jede Schaltung mit Grund, markiert mit `🔥 HEATER ON` bzw. `🔥 HEATER OFF`
- dazu die Logdatei, die in der eigenen Crontab-Zeile angegeben ist

## 3. Fehlersuche {#troubleshooting}

### Heizung geht während des Spiels aus

**Mögliche Ursachen:**

1. **Scoreboard nicht erreichbar:** Der Ping schlägt fehl, Carambus hält das Scoreboard für aus.
2. **Termin zu Ende:** Das Reservierungsende ist überschritten (siehe Regel 5).
3. **Termin gelöscht oder geändert:** Der Termin steht nicht mehr so im Kalender.

**Lösung:** Im Rails-Log nach `🔥 HEATER OFF` suchen; der Eintrag nennt den Grund.

### Heizung geht nicht an

**Mögliche Ursachen:**

1. **Titel nicht erkannt:** z. B. „Tisch 6“ statt „T6“. Solche Termine hat der Prüflauf womöglich schon gelöscht.
2. **Termin zu weit in der Zukunft:** mehr als 2 Stunden bis Beginn (Match Billard/Snooker: 4 Stunden).
3. **Pool-Tisch:** Pool-Tische werden nicht nach Kalender geheizt.
4. **Anderer Tisch gemeint:** Die T-Nummer bezeichnet die Position in der Tischliste (siehe Titel des Termins).
5. **Kein Prüflauf:** Der Crontab-Eintrag für `carambus:check_reservations` fehlt.
6. **Keine Steckdose eingetragen** oder die Steckdose ist nicht erreichbar.

**Lösung:** Titel prüfen, dann `log/events`, `log/table_status` und die Logdatei der Crontab-Zeile ansehen.

### Heizung geht 30 Minuten nach Terminbeginn aus

**Ursache:** Das Scoreboard war bis dahin nicht erreichbar (Log: `HEATER OFF`, Grund `inactivity detected`).

**Lösung:**

- Scoreboard früher einschalten
- oder den Termin mit „(!)“ markieren
