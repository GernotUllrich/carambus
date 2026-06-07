# WebSocket-Synchronisierungs-Logging (Referenz)

Dieses Dokument erklärt, wie das WebSocket-Synchronisierungs-Logging funktioniert
und wie man es liest. **Das Logging ist bereits im Code vorhanden** — es muss
nichts mehr eingebaut werden. Die folgenden Abschnitte zeigen, wo die Log-Zeilen
sitzen und was sie bedeuten.

## Wo das Logging sitzt

### 1. app/models/table_monitor.rb

Der `after_update_commit`-Block beginnt bei **Zeile 85** und enthält das
🔔-Logging. Steuerung und wichtige Bezeichner:

- **Suppression-Flag:** `suppress_broadcast` (`attr_writer` bei Zeile 79, Getter
  bei Zeile 81). Wird von `GameSetup` während Batch-Saves gesetzt, um redundante
  `TableMonitorJob`-Enqueues zu verhindern. Achtung: **nicht** `skip_update_callbacks`.
- **Geloggter Changeset:** Das Logging gibt `@collected_changes` und
  `@collected_data_changes` aus (nicht `previous_changes`). Die Job-Entscheidungen
  nutzen zusätzlich `relevant_keys`, abgeleitet aus `previous_changes.keys`.
- **Job-Enqueue:** Jobs werden über `TableMonitorJob.perform_later(id, ...)`
  eingereiht (es wird die `id` übergeben, kein Model-Objekt).

Auszug aus dem aktuellen Code (ab Zeile 85):

```ruby
  after_update_commit lambda {
    # Skip callbacks if flag is set (used in start_game to prevent redundant job enqueues)
    if suppress_broadcast
      Rails.logger.info "🔔 Skipping callbacks (suppress_broadcast=true)"
      Rails.logger.info "🔔 ========== after_update_commit END (skipped) =========="
      return
    end

    # Skip cable broadcasts on API Server (no scoreboards running)
    unless ApplicationRecord.local_server?
      Rails.logger.info "🔔 Skipping callbacks (API Server - no scoreboards)"
      Rails.logger.info "🔔 ========== after_update_commit END (API Server) =========="
      return
    end

    Rails.logger.info "🔔 ========== after_update_commit TRIGGERED =========="
    Rails.logger.info "🔔 TableMonitor ID: #{id}"
    Rails.logger.info "🔔 Previous changes: #{@collected_changes.inspect}"
    Rails.logger.info "🔔 Previous data changes: #{@collected_data_changes.inspect}"

    relevant_keys = (previous_changes.keys - %w[data nnn panel_state pointer_mode current_element updated_at])
    Rails.logger.info "🔔 Relevant keys: #{relevant_keys.inspect}"

    get_options!(I18n.locale)
    if tournament_monitor.is_a?(PartyMonitor) &&
       (relevant_keys.include?("state") || state != "playing")
      Rails.logger.info "🔔 Enqueuing: party_monitor_scores job"
      TableMonitorJob.perform_later(id, "party_monitor_scores")
    end
    if previous_changes.keys.present? && relevant_keys.present?
      Rails.logger.info "🔔 Enqueuing: table_scores job (relevant_keys present)"
      TableMonitorJob.perform_later(id, "table_scores")
      Rails.logger.info "🔔 Enqueuing: teaser job (for tournament_scores page)"
      TableMonitorJob.perform_later(id, "teaser")
    elsif @collected_changes.present? || @collected_data_changes.select(&:present?).present?
      Rails.logger.info "🔔 Enqueuing: teaser job (no relevant_keys)"
      TableMonitorJob.perform_later(id, "teaser")
    end
    # ... weitere Fast-Path-Zweige (ultra_fast_score_update?, simple_score_update?) folgen
  }
```

### 2. Weitere Logging-Stellen

✅ `app/javascript/channels/table_monitor_channel.js` — Client-Logging (📥, 🔌)
✅ `app/jobs/table_monitor_job.rb` — Logging am Anfang und Ende (📡)

## Test-Strategie

So liest man das vorhandene Logging im Betrieb:

1. **Tail logs in production:**
   ```bash
   tail -f /var/www/carambus_bcw/current/log/production.log | grep -E "(🔔|📡|📥|🔌)"
   ```

2. **Browser Console öffnen** (auf allen beteiligten Browsern)

3. **Spielende testen:**
   - Spiel an Browser A schließen
   - Erwartung: Browser B (table_scores) sollte Update bekommen

4. **Logs analysieren:**
   - Wird `after_update_commit` getriggert?
   - Welche `relevant_keys` werden erkannt?
   - Wird Job enqueued?
   - Läuft Job durch?
   - Wird broadcast aufgerufen?
   - Kommt broadcast an Clients an?

## Erwartete Log-Sequenz

```
# SERVER LOGS
🔔 ========== after_update_commit TRIGGERED ==========
🔔 TableMonitor ID: 50000001
🔔 Previous changes: {"state"=>["playing", "finished"], "game_id"=>[123, nil]}
🔔 Relevant keys: ["state", "game_id"]
🔔 Enqueuing: table_scores job (relevant_keys present)
🔔 ========== after_update_commit END ==========

📡 ========== TableMonitorJob START ==========
📡 TableMonitor ID: 50000001
📡 Operation Type: table_scores
📡 Stream: table-monitor-stream
📡 Reloaded state: finished, game_id: 
📡 Calling cable_ready.broadcast...
📡 Enqueued operations: 1
📡 Broadcast complete!
📡 ========== TableMonitorJob END ==========

# BROWSER A (Scoreboard) CONSOLE
🔌 TableMonitor Channel connected
📥 TableMonitor Channel received: {timestamp: "...", hasCableReady: true, operationCount: 1, type: "broadcast"}
📥 CableReady operation #1: {type: "innerHTML", selector: "#full_screen_table_monitor_50000001", htmlSize: "...", selectorExists: true}
✅ CableReady operations performed

# BROWSER B (table_scores) CONSOLE
🔌 TableMonitor Channel connected
📥 TableMonitor Channel received: {timestamp: "...", hasCableReady: true, operationCount: 1, type: "broadcast"}
📥 CableReady operation #1: {type: "innerHTML", selector: "#table_scores", htmlSize: "...", selectorExists: true}
✅ CableReady operations performed
```

## Wenn Updates nicht ankommen

### Szenario 1: Kein after_update_commit Log
**Problem:** `save!` wird nicht aufgerufen oder Callback wird unterdrückt  
**Check:** Wo wird das Model gespeichert? Wird `suppress_broadcast` gesetzt (z.B. durch `GameSetup` während Batch-Saves)? Läuft der Code auf einem API-Server (`local_server?` false) — dann werden Broadcasts bewusst übersprungen.

### Szenario 2: after_update_commit läuft, aber falsche relevant_keys
**Problem:** Wichtige Attribute sind in exclude-Liste  
**Fix:** Attribute aus exclude-Liste entfernen

### Szenario 3: Job wird nicht enqueued
**Problem:** Logik-Fehler in Callback-Bedingungen  
**Fix:** Bedingungen prüfen und korrigieren

### Szenario 4: Job läuft, aber kein broadcast Log
**Problem:** Exception im Job oder broadcast wird nicht aufgerufen  
**Check:** Gibt es Exceptions? Wird case-Statement erreicht?

### Szenario 5: broadcast Log vorhanden, aber Client empfängt nichts
**Problem:** WebSocket disconnected oder Redis Problem  
**Check:**
- Browser Console: Ist Channel `connected`?
- Redis: `redis-cli PUBSUB CHANNELS *` zeigt Stream?
- Nginx timeout?

### Szenario 6: Client empfängt, aber Selector nicht gefunden
**Problem:** `selectorExists: false` in Browser Console  
**Check:** Ist Element wirklich im DOM? Console: `document.querySelector("#table_scores")`


