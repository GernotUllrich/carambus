# ClubCloud Automatischer Upload

## Überblick

Das Carambus-System kann Spielergebnisse automatisch in die ClubCloud übertragen. Nach jedem abgeschlossenen Spiel werden die Daten direkt in die ClubCloud eingetragen, ohne dass der Admin manuell eingreifen muss.

## Features

### ✅ Automatischer Upload
- **Nach jedem Spiel**: Sobald ein Spiel beendet ist, wird das Ergebnis automatisch hochgeladen
- **Keine Intervention nötig**: Der Admin muss nichts tun
- **Duplikat-Schutz**: Mehrfache Aufrufe führen nur zu einem Upload
- **Fehlerbehandlung**: Bei Fehlern wird das Turnier nicht unterbrochen

### ✅ Sicheres Credential-Management
- **Verschlüsselt**: Zugangsdaten in Rails Credentials gespeichert
- **Lokal**: Credentials werden nicht über API-Server synchronisiert
- **Pro-Environment**: Unterschiedliche Credentials für Development/Production

### ✅ Intelligentes Name-Mapping
- **Gruppe 1** → **Gruppe A**
- **Platz 5-6** → **Spiel um Platz 5**
- **hf1** → **Halbfinale**
- **fin** → **Finale**

### ✅ Admin-Feedback
- **Fehler sichtbar**: Upload-Fehler werden im Tournament-UI angezeigt
- **Konsistente Logs**: Alle Logs mit `[CC-Upload]` Prefix
- **Klare Meldungen**: Deutsche, verständliche Fehlermeldungen

## Setup

### 1. ClubCloud Credentials einrichten

Die ClubCloud-Zugangsdaten müssen **lokal und verschlüsselt** gespeichert werden:

```bash
# Development
EDITOR=vim rails credentials:edit --environment development

# Production (auf dem Server)
EDITOR=vim RAILS_ENV=production rails credentials:edit --environment production
```

Füge folgende Struktur hinzu:

```yaml
clubcloud:
  nbv:
    username: "ihre-email@example.com"
    password: "ihr-passwort"
```

**Wichtig**: Die `.key` Dateien sind lokal und werden **NICHT** committet!

### 2. Turniervorbereitung

Beim Reset des Tournament-Monitors (`do_reset_tournament_monitor`) werden automatisch:

1. **ClubCloud-Login** getestet
2. **Gruppen-Mappings** von ClubCloud geladen
3. **Spielnamen validiert** gegen ClubCloud-Gruppen

Bei Problemen erscheint eine Warnung:

```
WARNING: Missing ClubCloud group mappings for games: group1:1-2, Platz 5-6
```

### 3. Turnierstart

Beim Start eines Turniers wird der ClubCloud-Zugriff validiert:

```
ClubCloud-Zugriff validiert ✓
```

Falls der Login fehlschlägt:

```
ClubCloud-Login fehlgeschlagen: Invalid credentials. 
Bitte prüfen Sie die ClubCloud-Zugangsdaten.
```

### 4. Automatischer Upload während des Turniers

Nach jedem Spiel:

```
[CC-Upload] ✓ Successfully uploaded game[123] (Spieler1 vs Spieler2, group1:1-2)
```

Bei Duplikaten:

```
[CC-Upload] ⊘ Skipping game[123] - already uploaded at 20:30:15
```

Bei Fehlern:

```
[CC-Upload] ✗ Upload failed: Gruppe 'group1:1-2' konnte nicht zugeordnet werden
```

## Name-Mapping

### Gruppen

| Carambus | ClubCloud |
|----------|-----------|
| group1:1-2 | Gruppe A |
| Gruppe 1 | Gruppe A |
| group2:1-2 | Gruppe B |
| Gruppe 2 | Gruppe B |
| group3:1-2 | Gruppe C |
| ... | ... |

### Platzierungsspiele

| Carambus | ClubCloud |
|----------|-----------|
| Platz 3-4 | Spiel um Platz 3 |
| p<3-4> | Spiel um Platz 3 |
| Platz 5-6 | Spiel um Platz 5 |
| p<5-6> | Spiel um Platz 5 |
| Platz 7-8 | Spiel um Platz 7 |
| ... | ... |

### Halbfinale & Finale

| Carambus | ClubCloud |
|----------|-----------|
| hf1 | Halbfinale |
| hf2 | Halbfinale |
| Halbfinale | Halbfinale |
| fin | Finale |
| Finale | Finale |

## Fehlerbehandlung

### Upload-Fehler anzeigen

Fehler werden in `tournament.data["cc_upload_errors"]` gespeichert und können im UI angezeigt werden:

```ruby
# In der Tournament-Show-View
<% if @tournament.data["cc_upload_errors"].present? %>
  <div class="alert alert-warning">
    <h4>⚠️ ClubCloud Upload-Fehler</h4>
    <ul>
      <% @tournament.data["cc_upload_errors"].each do |game_id, error_data| %>
        <li>
          <strong>Spiel <%= error_data["game_gname"] %></strong>
          <br>
          <%= error_data["error"] %>
          <br>
          <small><%= Time.parse(error_data["timestamp"]).strftime("%d.%m.%Y %H:%M:%S") %></small>
        </li>
      <% end %>
    </ul>
  </div>
<% end %>
```

### Häufige Fehler

#### 1. Gruppe konnte nicht zugeordnet werden

**Ursache**: Das Name-Mapping zwischen Carambus und ClubCloud fehlt.

**Lösung**: 
- Turniervorbereitung erneut durchführen
- Prüfen ob die Gruppe in ClubCloud existiert
- Name-Mapping testen: `bin/test-cc-name-mapping.rb`

#### 2. Spieler nicht in ClubCloud registriert

**Ursache**: Spieler hat keine `cc_id` oder `ba_id`.

**Lösung**:
- Spieler in ClubCloud-Teilnehmerliste eintragen
- Daten vom API-Server aktualisieren

#### 3. ClubCloud login failed

**Ursache**: Zugangsdaten falsch oder Session abgelaufen.

**Lösung**:
- Credentials prüfen: `rails credentials:edit --environment production`
- Manuell testen: `Setting.login_to_cc`

#### 4. Upload fehlgeschlagen (HTTP 404)

**Ursache**: ClubCloud-URL ist falsch.

**Lösung**:
```ruby
region_cc = RegionCc.find_by(context: "nbv")
region_cc.base_url # Sollte https://...club-cloud.de/ sein
```

### Logs filtern

```bash
# Alle ClubCloud-Logs
tail -f log/production.log | grep "\[CC-Upload\]"

# Nur Fehler
tail -f log/production.log | grep "\[CC-Upload\].*✗\|Exception\|failed"

# Nur erfolgreiche Uploads
tail -f log/production.log | grep "\[CC-Upload\].*✓"
```

### Manueller Retry

Falls ein Upload fehlgeschlagen ist:

```ruby
game = Game.find(123)
table_monitor = TableMonitor.find_by(game_id: game.id)

# Upload erneut versuchen
result = Setting.upload_game_to_cc(table_monitor)

if result[:success]
  puts "✓ Upload erfolgreich"
else
  puts "✗ Fehler: #{result[:error]}"
end
```

### Fehler löschen

```ruby
tournament = Tournament.find(123)

# Einen Fehler löschen
Setting.clear_cc_upload_error(tournament, game)

# Alle Fehler löschen
tournament.unprotected = true
tournament.data["cc_upload_errors"] = {}
tournament.data_will_change!
tournament.save!
```

## Monitoring

### Fehler-Statistik

```ruby
# Turniere mit Upload-Fehlern
Tournament.where("data->'cc_upload_errors' IS NOT NULL").each do |t|
  error_count = t.data["cc_upload_errors"]&.size || 0
  puts "#{t.title}: #{error_count} Fehler"
end
```

### Upload-Status prüfen

```ruby
game = Game.find(123)

# Wann wurde hochgeladen?
if game.data["cc_uploaded_at"].present?
  uploaded_at = Time.parse(game.data["cc_uploaded_at"])
  puts "Hochgeladen: #{uploaded_at.strftime('%d.%m.%Y %H:%M:%S')}"
else
  puts "Noch nicht hochgeladen"
end
```

## Technische Details

### Duplikat-Schutz

Jedes Spiel wird nur einmal hochgeladen:

1. Nach erfolgreichem Upload wird `game.data["cc_uploaded_at"]` gesetzt
2. Bei erneutem Aufruf wird geprüft ob Upload < 5 Minuten her
3. Falls ja: Upload wird übersprungen
4. Falls nein (> 5 Min): Upload wird wiederholt

**Vorteil**: Mehrfache `report_result`-Aufrufe führen nur zu einem Upload.

### Session-Management

- **Login**: Automatisch beim ersten Upload
- **Session-Validierung**: Prüft ob Session noch gültig ist
- **Automatischer Retry**: Bei Session-Verlust wird Logout + Login durchgeführt
- **Session-Speicherung**: In `Setting.data["session_id"]`

### Ablauf eines Uploads

```
1. finalize_game_result (TournamentMonitorState)
   ↓
2. Setting.upload_game_to_cc(table_monitor)
   ↓
3. Duplikat-Check (cc_uploaded_at < 5 Min?)
   ↓ Nein
4. Login-Check (ensure_logged_in)
   ↓
5. Name-Mapping (game.gname → ClubCloud-Gruppe)
   ↓
6. Spieler-Check (cc_id/ba_id vorhanden?)
   ↓
7. HTTP POST zu createErgebnisSave.php
   ↓
8. Erfolg: mark_game_as_uploaded
   ↓
9. Fehler löschen (clear_cc_upload_error)
```

## Weitere Dokumentation

- [ClubCloud Credentials Setup](../docs/clubcloud_credentials.md)
- [ClubCloud Upload Feedback](../docs/clubcloud_upload_feedback.md)
- [Name-Mapping Test](../bin/test-cc-name-mapping.rb)

## Siehe auch

- [Tournament Management](tournament-management.md)
- [ClubCloud Integration](clubcloud-integration.md)
- [API Server Synchronization](api-server-sync.md)





