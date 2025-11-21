# Blank table_scores Bug Fix (2025-11-21)

## 🚨 Problem

Beim Starten eines neuen Spiels oder Reload der Tisch-Auswahl-Seite wurden alle `table_scores` Views komplett **BLANK** (nur Menü sichtbar).

### Symptome

- ✅ Scoreboards funktionierten einwandfrei
- ✅ Score Updates wurden synchronisiert
- ❌ `table_scores` Views wurden komplett leer
- ❌ Browser Console zeigte leeres HTML: `"<!-- BEGIN app/views/locations/_table_scores.html.erb --><!-- END app/views/locations/_table_scores.html.erb -->"`

## 🔍 Root Cause

### Variable Mismatch in Partial

**`app/views/locations/_table_scores.html.erb` (Zeile 2):**

```ruby
# ❌ VORHER (FALSCH):
location_ = table_monitor_.andand.location || @location
```

**Problem:**
- Das Partial wurde vom Job mit `locals: { location: location, table_kinds: location.table_kinds }` aufgerufen
- Das Partial schaute nach `@location` (Instance Variable)
- Aber `location` war eine **lokale Variable**, nicht `@location`
- Resultat: `location_` war `nil` → Partial renderte **nichts**

## ✅ Fix

```ruby
# ✅ NACHHER (KORREKT):
location_ = local_assigns[:location] || table_monitor_.andand.location || @location
table_kinds = local_assigns[:table_kinds] || location_.table_kinds
```

**Lösung:**
- Prüfe **zuerst** `local_assigns[:location]` (vom Job übergeben)
- **Fallback** zu `table_monitor_.location` (wenn TableMonitor übergeben wurde)
- **Fallback** zu `@location` (wenn als Instance Variable gesetzt)

## 📁 Geänderte Dateien

### 1. `app/views/locations/_table_scores.html.erb`

```ruby
# Zeile 2-4 geändert:
<%- location_ = local_assigns[:location] || table_monitor_.andand.location || @location %>
<%- if location_.present? %>
  <%- table_kinds = local_assigns[:table_kinds] || location_.table_kinds %>
```

## 🧪 Test

### Setup
- Browser A: Scoreboard Tisch 7
- Browser B: Scoreboard Tisch 7  
- Browser C: table_scores

### Erfolgreiches Verhalten
1. ✅ Reload in Browser C → table_scores zeigt alle Spiele
2. ✅ Score Update in A → B & C aktualisieren
3. ✅ Spiel beenden in A → B & C zeigen Ende
4. ✅ Neues Spiel starten → C zeigt sofort neues Spiel
5. ✅ Keine Blank Screens mehr!

## 🎯 Zusätzliche Fixes in diesem Chat

### 1. Warning Modal in Karambol fehlte

**Problem:** `_show.html.erb` hatte kein `modal-confirm-back` Modal

**Fix:** Modal-HTML von `_show_pool.html.erb` übernommen und in `_show.html.erb` eingefügt (innerhalb des `#full_screen_table_monitor_X` Containers)

**Dateien:**
- `app/views/table_monitors/_show.html.erb` (Zeile 65-85 hinzugefügt)

### 2. Enhanced Logging für Debugging

**Hinzugefügt:** Comprehensive Logging in:
- `app/models/table_monitor.rb` (🔔 after_update_commit)
- `app/jobs/table_monitor_job.rb` (📡 Job execution, HTML size)
- `app/javascript/channels/table_monitor_channel.js` (📥 Browser reception)

**Zweck:** Vollständige Traceability vom `save!` bis zum DOM-Update

**TODO:** Logging für Production bereinigen (siehe `docs/DEVELOPMENT_LOGGING_SETUP.md`)

## 📊 Architektur-Erkenntnisse

### Broadcast Redundancy funktioniert!

Das "Empty String Job" Pattern (`TableMonitorJob.perform_later(self, "")`) ist **essentiell**:

1. **Teaser Job:** Aktualisiert `#teaser_X` (kleine Updates für table_scores)
2. **Full Screen Job:** Aktualisiert `#full_screen_table_monitor_X` (aktive Scoreboards)

**Warum beide?**
- CableReady filtert per **DOM-Selector**
- Browser ohne `#teaser_X` ignorieren Teaser-Updates
- Browser ohne `#full_screen_table_monitor_X` ignorieren Full-Screen-Updates
- **Resultat:** Jeder Client bekommt nur relevante Updates!

Siehe auch: `docs/EMPTY_STRING_JOB_ANALYSIS.md`

## 🔗 Verwandte Dokumentation

- `WEBSOCKET_LIFECYCLE_ANALYSIS.md` - ActionCable/CableReady Architektur
- `EMPTY_STRING_JOB_ANALYSIS.md` - "Empty String Job" Pattern
- `SCOREBOARD_ARCHITECTURE.md` - Server-driven Architecture
- `DEVELOPMENT_LOGGING_SETUP.md` - File Logging Setup

## ✅ Ergebnis

**Alle Synchronisierungs-Tests bestanden!** 🎉

- ✅ Scoreboard ↔ Scoreboard synchron
- ✅ Score Updates → table_scores live
- ✅ Spiel Start/Ende überall synchronisiert
- ✅ Keine Blank Screens
- ✅ Kein Datenverlust

