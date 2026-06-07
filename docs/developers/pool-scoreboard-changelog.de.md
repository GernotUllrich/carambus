# Changelog: Pool Scoreboard & Liga-Spielverwaltung

## Version 2025-12-03

### Übersicht

Diese Version bringt umfangreiche Verbesserungen für das Pool Scoreboard und die Liga-Spielverwaltung (PartyMonitor). Die Änderungen umfassen Bugfixes, neue Features und Optimierungen.

---

## Neue Features

### 1. Pool Quickstart-Buttons

**Dateien:**
- `config/carambus.yml.erb`
- `app/views/locations/_quick_game_buttons.html.erb`
- `app/controllers/table_monitors_controller.rb`

**Beschreibung:**
Pool-Tische haben jetzt konfigurierbare Quickstart-Buttons ähnlich wie Karambol-Tische:

> **Hinweis (aktuelle Struktur):** Das ursprüngliche Release nutzte eine flache
> `pool:`-Map mit Disziplin-Schlüsseln und einem `sets:`-Key pro Button. Dies
> wurde später durch die unten gezeigte `quick_game_presets:`-Struktur abgelöst,
> die Presets nach `TableKind` (`small_billard` / `match_billard` / `pool` /
> `snooker`) als Liste von `{ category:, buttons: }`-Einträgen gruppiert und
> `sets:` in `sets_to_win:` umbenennt.

```yaml
quick_game_presets:
  pool:
    - category: "8-Ball"
      buttons:
        - { sets_to_win: 3, discipline: "8-Ball", kickoff_switches_with: "winner", label: "3 (W)" }
        - { sets_to_win: 4, discipline: "8-Ball", kickoff_switches_with: "winner", label: "4 (W)" }
        - { sets_to_win: 5, discipline: "8-Ball", kickoff_switches_with: "winner", label: "5 (W)" }
        - { sets_to_win: 3, discipline: "8-Ball", kickoff_switches_with: "set", label: "3 (A)" }
        - { sets_to_win: 4, discipline: "8-Ball", kickoff_switches_with: "set", label: "4 (A)" }
        - { sets_to_win: 5, discipline: "8-Ball", kickoff_switches_with: "set", label: "5 (A)" }
    - category: "9-Ball"
      buttons:
        - { sets_to_win: 5, discipline: "9-Ball", kickoff_switches_with: "winner", label: "5 (W)" }
        - { sets_to_win: 7, discipline: "9-Ball", kickoff_switches_with: "winner", label: "7 (W)" }
        - { sets_to_win: 9, discipline: "9-Ball", kickoff_switches_with: "winner", label: "9 (W)" }
        - { sets_to_win: 5, discipline: "9-Ball", kickoff_switches_with: "set", label: "5 (A)" }
        - { sets_to_win: 7, discipline: "9-Ball", kickoff_switches_with: "set", label: "7 (A)" }
        - { sets_to_win: 9, discipline: "9-Ball", kickoff_switches_with: "set", label: "9 (A)" }
    - category: "10-Ball"
      buttons:
        - { sets_to_win: 5, discipline: "10-Ball", kickoff_switches_with: "winner", label: "5 (W)" }
        - { sets_to_win: 7, discipline: "10-Ball", kickoff_switches_with: "winner", label: "7 (W)" }
        - { sets_to_win: 5, discipline: "10-Ball", kickoff_switches_with: "set", label: "5 (A)" }
        - { sets_to_win: 7, discipline: "10-Ball", kickoff_switches_with: "set", label: "7 (A)" }
    - category: "14.1 endlos"
      buttons:
        - { balls: 50, innings: 0, discipline: "14.1 endlos", label: "50" }
        - { balls: 75, innings: 0, discipline: "14.1 endlos", label: "75" }
        - { balls: 100, innings: 0, discipline: "14.1 endlos", label: "100" }
```

### 2. Pool Scoreboard Benutzerhandbuch

**Datei:** `docs/pool_scoreboard_benutzerhandbuch.de.md`

Vollständiges deutsches Benutzerhandbuch für Pool-Spieler mit:
- Anleitungen für alle Pool-Disziplinen (8-Ball, 9-Ball, 10-Ball, 14.1 endlos)
- Scoreboard-Layout-Diagramme
- Tastenbelegung und Touch-Bedienung
- Screenshots der wichtigsten Ansichten
- Fehlerbehebung

---

## Bugfixes

### 1. 14.1 endlos Rerack-Logik

**Datei:** `app/models/table_monitor.rb`

**Problem:** 
Bei 14.1 endlos wurde das Rerack (Neuaufstellen auf 15 Bälle) nicht korrekt angezeigt. Die Ball-Darstellung und der Counter-Stack wurden bei partiellen Updates nicht richtig aktualisiert.

**Lösung:**
- `ultra_fast_score_update?` und `simple_score_update?` geben für "14.1 endlos" immer `false` zurück
- Dadurch wird bei jedem Update ein vollständiges Re-Rendering durchgeführt
- Die `recompute_result` Methode berücksichtigt jetzt auch `innings_redo_list` beider Spieler

```ruby
def ultra_fast_score_update?
  return false if data.dig("playera", "discipline") == "14.1 endlos"
  # ... rest of method
end

def simple_score_update?
  return false if data.dig("playera", "discipline") == "14.1 endlos"
  # ... rest of method
end
```

### 2. Pool Scoreboard Syntax-Fehler

**Datei:** `app/views/table_monitors/_pool_scoreboard.html.erb`

**Problem:**
ERB-Syntax-Fehler durch multiple Assignment mit Bedingung und fehlendes `end`-Tag.

**Lösung:**
```erb
# Vorher (fehlerhaft):
<%- time_counter, ... = options[:timer_data] if fullscreen && options[:timer_data].present? %>

# Nachher (korrekt):
<%- if fullscreen && options[:timer_data].present? %>
  <%- time_counter, ... = options[:timer_data] %>
<%- end %>
```

### 3. PartyMonitor Game-Verknüpfung

**Datei:** `app/services/table_monitor/game_setup.rb`
(`TableMonitor#start_game` war ursprünglich inline in
`app/models/table_monitor.rb` implementiert; die Logik wurde später in den
Service `TableMonitor::GameSetup` ausgelagert und delegiert jetzt nur noch:
`def start_game(options_ = {}); TableMonitor::GameSetup.call(table_monitor: self, options: options_); end`)

**Problem:**
Beim Starten von Liga-Spielen über den PartyMonitor wurden neue Games erstellt, anstatt die bestehenden Party-Games zu verwenden. Dadurch wurden Spielergebnisse nicht korrekt im PartyMonitor angezeigt.

**Lösung:**
Die Game-Setup-Logik prüft jetzt, ob ein bestehendes Party/Tournament-Game vorhanden ist (in `GameSetup#perform_start_game`, mit Verzweigung in `setup_existing_party_game`):

```ruby
def perform_start_game
  # Check if we have an existing Party/Tournament game that should be preserved
  existing_party_game = @tm.game if @tm.game.present? && @tm.game.tournament_type.present?

  if existing_party_game.present?
    # Use the existing Party/Tournament game - don't create a new one
    setup_existing_party_game(existing_party_game)
  else
    # Create a new game for free games
    create_new_game
  end
  # ...
end
```

### 4. PartyMonitor Ergebnisspeicherung

**Datei:** `app/models/table_monitor.rb`

**Problem:**
Die `ba_results` wurden nur für freie Spiele in das Game gespeichert, nicht für Party/Tournament-Spiele.

**Lösung:**
```ruby
def prepare_final_game_result
  # ...
  # Save results to the game for both free games and tournament/party games
  if final_set_score? && game.present?
    game.deep_merge_data!("ba_results" => data["ba_results"])
    game.save!
  end
end
```

### 5. PartyMonitor Reset-Button

**Datei:** `app/reflexes/party_monitor_reflex.rb`

**Problem:**
Der "Spieltag-Monitor komplett zurücksetzen" Button funktionierte nicht, wenn `table_monitor.game` `nil` war.

**Lösung:**
```ruby
def reset_party_monitor
  # 1. Lösche Games der TableMonitors (nur wenn vorhanden)
  @party_monitor.table_monitors.each do |table_monitor|
    table_monitor.game&.destroy  # Safe navigation operator
  end
  # 2. Lösche alle TableMonitors
  @party_monitor.table_monitors.destroy_all
  # 3. Lösche alle Party-Games
  @party_monitor.party.games.destroy_all
  # 4. Lösche Test-Seedings
  @party_monitor.party.seedings.where("id > 5000000").destroy_all
  # 5. Setze den PartyMonitor zurück
  @party_monitor.reset_party_monitor
  flash[:notice] = "Party Monitor komplett zurückgesetzt"
rescue StandardError => e
  flash[:alert] = "Fehler beim Zurücksetzen: #{e.message}"
end
```

### 6. Liga-Spielparameter editierbar

**Dateien:**
- `app/views/party_monitors/_party_monitor.html.erb`
- `app/reflexes/party_monitor_reflex.rb`
- `app/models/discipline.rb`

**Problem:**
Die Spielparameter (z.B. Punkteziel 80 für 14.1 endlos) waren vor dem Spielstart nicht editierbar.

**Lösung:**
- Parameter-Buttons sind jetzt in den States `seeding_mode`, `table_definition_mode` und `next_round_seeding_mode` editierbar
- `Discipline::GAME_PARAMETERS` für "14/1e" wurde um weitere Punkteziele (60, 70, 80) und Aufnahmelimits erweitert
- Die `start_round` Methode parst jetzt korrekt Score-Werte aus Strings wie "Hauptrunde 80"

---

## JavaScript-/View-Änderungen

### balls_left Klick-Verarbeitung

**Dateien:**
- `app/views/table_monitors/_pool_scoreboard.html.erb`
- `app/reflexes/table_monitor_reflex.rb` (`TableMonitor#balls_left`)

**Problem:**
Klicks auf Bälle in der Kontrollleiste (14.1 endlos) zeigten keine Wirkung.

**Lösung:**
Der Klick wird deklarativ in der View verdrahtet, nicht über eine explizite
Stimulus-Controller-Methode. Jedes Ball-Element trägt die StimulusReflex-Action
sowie die vom Reflex benötigten Daten:

```erb
<%= content_tag "div",
                data: {
                  controller: "table-monitor",
                  action: "click->table-monitor#balls_left",
                  ball_no: n,
                  id: table_monitor.id
                },
                ... do %>
  <%= image_tag "p#{n}.png" %>
<%- end %>
```

StimulusReflex bildet die Action `table-monitor#balls_left` direkt auf den
Reflex `TableMonitor#balls_left` ab; eine explizite `balls_left()`-Methode in
`table_monitor_controller.js` ist nicht erforderlich. Der Reflex liest
`dataset[:ball_no]`, um die Anzahl der verbleibenden Bälle zu ermitteln.

> **Hinweis:** Eine frühere Fassung dieses Changelogs beschrieb das Hinzufügen
> einer expliziten `balls_left()`-Methode in `table_monitor_controller.js`.
> Diese Methode wurde nie committet — der oben beschriebene deklarative
> View-Weg ist der tatsächlich verwendete Mechanismus.

---

## Entfernte Features

### Duplizierter Undo-Button

**Datei:** `app/views/table_monitors/_pool_scoreboard.html.erb`

Der Undo-Button unterhalb des Tischnamens wurde entfernt, da bereits ein Undo/Redo im oberen Menü vorhanden ist.

---

## Getestete Szenarien

1. **Pool Quickstart**: Alle Disziplinen (8-Ball, 9-Ball, 10-Ball, 14.1 endlos) mit verschiedenen Parametern
2. **14.1 endlos Rerack**: Korrektes Neuaufstellen bei 1 oder 0 verbleibenden Bällen
3. **Liga-Spielverwaltung**: Kompletter Workflow vom Seeding bis zum Spielabschluss
4. **PartyMonitor Reset**: Zurücksetzen über UI-Button und Rails Console
5. **Ergebnisanzeige**: Korrekte Anzeige der Spielergebnisse im PartyMonitor

---

## Commits

1. `feature/pool-scoreboard-quickstart` → `master` (Merge)
2. Fix PartyMonitor game results display
3. Fix PartyMonitor reset button

---

## Betroffene Models

- `TableMonitor`
- `PartyMonitor`
- `Game`
- `GameParticipation`
- `Discipline`

## Betroffene Views

- `_pool_scoreboard.html.erb`
- `_quick_game_buttons.html.erb`
- `_party_monitor.html.erb`
- `_game_row.html.erb`

## Betroffene Controller/Reflexes

- `table_monitors_controller.rb`
- `party_monitor_reflex.rb`
- `table_monitor_reflex.rb`

## Betroffene JavaScript

- `table_monitor_controller.js`

---

## Dokumentation

- `docs/pool_scoreboard_benutzerhandbuch.de.md` - Neues Benutzerhandbuch
- `docs/CHANGELOG_POOL_SCOREBOARD.md` - Diese Datei



