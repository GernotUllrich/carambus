# Logging Patch für WebSocket Synchronisierungs-Debug

## Manuelle Änderungen erforderlich

### 1. app/models/table_monitor.rb

Füge nach Zeile 71 `after_update_commit lambda {` folgende Zeilen ein:

```ruby
  after_update_commit lambda {
    Rails.logger.info "🔔 ========== after_update_commit TRIGGERED =========="
    Rails.logger.info "🔔 TableMonitor ID: #{id}"
    Rails.logger.info "🔔 Previous changes: #{previous_changes.inspect}"
    
    # Skip callbacks if flag is set (used in start_game to prevent redundant job enqueues)
    if skip_update_callbacks
      Rails.logger.info "🔔 Skipping callbacks (skip_update_callbacks=true)"
      Rails.logger.info "🔔 ========== after_update_commit END (skipped) =========="
      return
    end

    #broadcast_replace_later_to self
    relevant_keys = (previous_changes.keys - %w[data nnn panel_state pointer_mode current_element updated_at])
    Rails.logger.info "🔔 Relevant keys: #{relevant_keys.inspect}"
    
    get_options!(I18n.locale)
    if tournament_monitor.is_a?(PartyMonitor) &&
      (relevant_keys.include?("state") || state != "playing")
      Rails.logger.info "🔔 Enqueuing: party_monitor_scores job"
      TableMonitorJob.perform_later(self,
                                    "party_monitor_scores")
    end
    if previous_changes.keys.present? && relevant_keys.present?
      Rails.logger.info "🔔 Enqueuing: table_scores job (relevant_keys present)"
      TableMonitorJob.perform_later(self, "table_scores")
    else
      Rails.logger.info "🔔 Enqueuing: teaser job (no relevant_keys)"
      TableMonitorJob.perform_later(self, "teaser")
    end
    TableMonitorJob.perform_later(self, "")  # Was macht diese Zeile??
    Rails.logger.info "🔔 ========== after_update_commit END =========="
    # broadcast_replace_to self
  }
```

**ACHTUNG:** Zeile 88 `TableMonitorJob.perform_later(self, "")` mit leerem String - sollte das entfernt werden?

### 2. Bereits angewendet

✅ `app/javascript/channels/table_monitor_channel.js` - Erweitertes Logging
✅ `app/jobs/table_monitor_job.rb` - Logging am Anfang und Ende

## Test-Strategie

Nach dem Logging einbauen:

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
**Check:** Wo wird das Model gespeichert? Wird `skip_update_callbacks` gesetzt?

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


