---
created: 2026-04-27T00:00:00.000Z
title: Detail-Page Disziplin-Zeile — KEGEL-Toggle entfaltet zweite Zeile
area: ui-detail-form
files:
  - app/views/locations/scoreboard_free_game_karambol_new.html.erb (Disziplin-Zeile + Kegel-Familien-Zeile)
  - test/system/bk2_scoreboard_test.rb (4 neue T-Kegel-* Tests, 3 obsolete entfernt)
---

## Wunsch (User, 2026-04-26 Abend)

Detail-Page Übersichtlichkeit verbessern:

**Vorher:**
- Disziplin-Zeile: 3BAND, FREI, 1BAND, 52/2, 35/2, EUROK
- BK-Variante-Zeile (immer sichtbar bei Small Billard): BK50, BK100, BK-2, BK-2plus, BK-2kombi

**Nachher:**
- Disziplin-Zeile: 3BAND, FREI, 1BAND, 52/2, 35/2, **KEGEL**
- Kegel-Familien-Zeile (NUR sichtbar wenn KEGEL gewählt): EUROK, BK50, BK100, BK-2, BK-2plus, BK-2kombi
- EUROK ist Default beim Wechsel auf KEGEL.

## Closed 2026-04-27

### Implementation

**View** (`app/views/locations/scoreboard_free_game_karambol_new.html.erb`):
- Alpine `x-data` erweitert um zwei Getter:
  - `is_kegel = discipline == 5`
  - `kegel_choice = bk_selected_form || (is_kegel ? 'eurok' : null)` — single source für Active-State des Sub-Buttons
- `x-effect` erweitert: clears `bk_selected_form` wenn User Disziplin verlässt (`if discipline != 5 && bk_selected_form { bk_selected_form = null }`)
- Disziplin-Display Index 5: "Eurok" → "Kegel" (parameters==0 only — parameters==1/2 behalten "Eurok", per User-Feedback "kommt nicht vor")
- BK-Variante-Block (vorher Plan 38.4-09 / 38.4-15) entfernt; ersetzt durch Kegel-Familien-Zeile mit 6 Buttons (EUROK + 5 BK)
- EUROK-Klick: setzt `bk_selected_form = null` → bestehender Karambol-Eurokegel-Pfad
- BK-Klick: setzt `bk_selected_form = 'bk50'/etc.` → bestehender BK-Pfad (`is_bk_family = true`); zusätzlich default `bk_balls_goal` und `innings = 5` für BK-2/BK-2plus/BK-2kombi (analog zum vorherigen `@change`-Handler)

**Tests** (`test/system/bk2_scoreboard_test.rb`):
- Neu (4): T-Kegel-discipline-row-uses-kegel-label, T-Kegel-row-eurok-button-present, T-Kegel-old-bk-variante-block-removed, T-Kegel-erb-compiles — alle 4 grün
- Entfernt (3): T-O6-bk-variante-row-alignment-v2, T-P2-bk-variante-fixed-width-buttons, T-P2-bk-variante-row-cols-5-rendered — testeten den entfernten BK-Variante-Block, durch T-Kegel-* abgedeckt

### Was bleibt unverändert
- Hidden Form-Inputs (`free_game_form`, `discipline_a`, `discipline_b`, `bk2_options[*]`) — gucken auf `is_bk_family`, funktionieren weiter
- Backend (`bk_family?`, `ResultRecorder`, `clamp_bk_family_params!`) — unverändert
- Quick-Game-Buttons (`_quick_game_buttons.html.erb`) — unverändert
- Punkt-Ziel + Aufnahmebegrenzung-Zeilen darunter — gucken auf `is_bk_family`, automatisch versteckt wenn EUROK aktiv
- `KARAMBOL_DISCIPLINE_MAP[5] = "Eurokegel"` — Backend-Disziplinname unverändert; nur das UI-Label auf dem Toggle-Button ist "Kegel"

### Browser-UAT (vom User noch durchzuführen)

1. Detail-Page öffnen (Small Billard) → Disziplin-Zeile zeigt "KEGEL" statt "EUROK" als 6. Button. Kegel-Familien-Zeile darunter ist NICHT sichtbar.
2. KEGEL klicken → Kegel-Familien-Zeile erscheint mit 6 Buttons. EUROK ist aktiv (blauer Hintergrund). Punkt-Ziel + Aufnahmebegrenzung zeigen Karambol-Defaults.
3. BK50 klicken → BK50-Button aktiv. is_bk_family wird true → Punkt-Ziel-Zeile zeigt [50] (BK-aware), Aufnahmebegrenzung zeigt [5, 7] + Counter.
4. Disziplin auf 3Band wechseln → Kegel-Familien-Zeile verschwindet. bk_selected_form auf null geclearet (x-effect). is_bk_family wieder false.
5. Zurück auf KEGEL → EUROK wieder Default (frisch).
6. Spiel starten in jeder Variante → korrekte Disziplin im neuen TableMonitor.