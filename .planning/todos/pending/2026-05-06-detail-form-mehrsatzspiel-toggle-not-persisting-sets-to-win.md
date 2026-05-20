---
created: 2026-05-06T19:30:00Z
title: Detail-Form "Mehrsatzspiel"-Toggle persistiert sets_to_win/sets_to_play nicht
area: scoreboard / detail-form
files:
  - app/views/locations/scoreboard_free_game_karambol_new.html.erb (Detail-Form Multi-Set toggle UI)
  - app/controllers/table_monitors_controller.rb (start_game permit/coercion)
  - app/services/table_monitor/game_setup.rb (#perform_start_game, sets_to_win plumbing)
  - app/models/table_monitor.rb (bk2_state init — apparently DOES read multi-set intent for set_scores grid)
---

## Problem

Im Detail-Form für BK-2 (`scoreboard_free_game_karambol_new.html.erb`) gibt es einen "Mehrsatzspiel"-Toggle / Multi-Set-Pfad. Operator wählt im Detail-Form "Mehrsatzspiel" und konfiguriert ein Best-of-N-Match — z.B. BK-2 best-of-3 mit `balls_goal=70`.

**Beobachtetes Verhalten:** Beim Start des Matches wird `bk2_state.set_scores` korrekt mit Multi-Set-Scaffolding initialisiert (3 Slots: `{1, 2, 3}` für 3 Sätze), **aber** die top-level Match-Konfiguration `data["sets_to_win"]` und `data["sets_to_play"]` bleiben auf `1` stehen. Die UI zeigt also Multi-Set-Geometrie, aber die AASM-State-Machine sieht ein Single-Set-Match.

**Folge:**
- Set 1 endet (z.B. tied 70:70 in 1+1 Aufnahmen)
- ResultRecorder applied trailing-player-wins-Regel → ein Spieler gewinnt Set 1 → `sets_won_b = 1`
- `max_wins (1) >= sets_to_win (1)` → Match transitioniert sofort zu `:final_match_score`
- Operator erwartet aber Set 2, weil "Mehrsatzspiel" konfiguriert war

**Discovered during Phase 38.7 UAT 2026-05-06:** Erste TR-B-Runde fiel scheinbar durch (kein Tiebreak-Modal bei tied 70:70 in BK-2 best-of-3). Console-Dump `TableMonitor[50000002].data` zeigte:

```ruby
data["free_game_form"]   => "bk_2"
data["sets_to_win"]      => 1   # ← BUG: Operator wollte 2 (Mehrsatzspiel)
data["sets_to_play"]     => 1   # ← BUG: Operator wollte 3
data["bk2_state"]["set_scores"] => {"1"=>..., "2"=>..., "3"=>...}   # ← 3-Set-Scaffolding korrekt
data["bk2_options"]["serienspiel_max_innings_per_set"] => 5
```

UAT 2 wurde nach Wechsel auf BK2-Kombi-Quickstart-Preset (umgeht Detail-Form) bestanden — Bug ist also auf den Detail-Form-Pfad lokalisiert.

## Solution

TBD — Detail-Form-Code-Pfad muss systematisch durchgelesen werden:

1. **UI-Toggle finden:** Wo wird "Mehrsatzspiel" im `scoreboard_free_game_karambol_new.html.erb` gerendert? Welche Form-Inputs trägt das Form-Submit?
2. **Controller prüfen:** Wird `sets_to_win` / `sets_to_play` im permit-Whitelist von `TableMonitorsController#start_game` geführt?
3. **GameSetup-Plumbing:** Liest `TableMonitor::GameSetup#perform_start_game` die Werte aus `@options` und schreibt sie nach `tm.data`?
4. **bk2_state-Init prüfen:** Warum funktioniert `set_scores`-Scaffolding (3 Slots)? Welcher Pfad initialisiert das richtig — und warum derselbe Toggle nicht auf top-level data?

**Vermutung:** Das Multi-Set-Toggle setzt nur einen UI-Hint oder einen bk2-state-Slot, ohne `sets_to_win`/`sets_to_play` ins top-level `data` durchzureichen. Wahrscheinlich fehlt entweder:
- Ein hidden_field_tag im Detail-Form,
- Ein Permit-Eintrag im Controller, oder
- Ein Mapping-Schritt in GameSetup

Quickstart-Preset-Pfad funktioniert (carambus.yml.erb-Buttons setzen `sets_to_win: 2, sets_to_play: 3` direkt) — Detail-Form ist der alleinige Defekt.

**Schweregrad:** Mittel. Workaround: Operator nutzt Quickstart-Preset statt Detail-Form für Multi-Set-Spiele. Aber Detail-Form ist explizit für Custom-Setups gedacht; sollte Multi-Set ehrlich unterstützen.

**Reproduktion:**

1. Quick-Start → Quick-Game → Detail-Page öffnen
2. Disziplin: BK-2, balls_goal=70
3. "Mehrsatzspiel" / Multi-Set-Toggle ankreuzen
4. sets_to_win z.B. 2, sets_to_play 3 (oder sonstige Multi-Set-Konfig)
5. Speichern + Spiel starten
6. Im Spiel: tippe `bin/rails runner "puts TableMonitor.last.data.slice('sets_to_win', 'sets_to_play').to_json"`
7. Erwartet: `{"sets_to_win":2,"sets_to_play":3}`
8. Beobachtet: `{"sets_to_win":1,"sets_to_play":1}`

**Touches:**
- Detail-Form Multi-Set toggle UI (`scoreboard_free_game_karambol_new.html.erb`)
- TableMonitorsController `start_game` permit list
- GameSetup `perform_start_game` plumbing
- Kein direkter Konflikt mit Phase 38.5/38.7/38.8/38.9 — pre-existing, durch UAT 2026-05-06 entdeckt
