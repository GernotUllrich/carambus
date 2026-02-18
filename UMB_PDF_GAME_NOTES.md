# UMB PDF Game Parsing Notes

## PDF Typen

### 1. Players List (A. Players List.pdf)
- ✅ Bereits implementiert
- → Seedings

### 2. Group Results (D. GroupResults_PPPQ.pdf)
- Enthält die eigentlichen **Spiele**!
- Format:
  ```
  Group A
    Match Players          T-Car  T-Inn  Avg   MP   1st HR  2nd HR
    Player 1               30     26     1.153  2    5       4
    Player 2               22     26     0.846  0    4       3
  ```
- **T-Car** = Total Carambolages (Punkte)
- **T-Inn** = Total Innings (Aufnahmen)
- **Avg** = Average (Durchschnitt)
- **MP** = Match Points (2 für Sieg, 0 für Niederlage)
- **1st HR / 2nd HR** = High Runs (Höchste Serien)

### 3. Groups Ranking (E. Groups_Ranking_PPPQ.pdf)
- Gesamtübersicht der Gruppen
- Finale Platzierungen pro Gruppe

## Was wir brauchen

### Game Model
- `tournament_id` → Tournament
- `player_a_id`, `player_b_id` → Players
- `score_a`, `score_b` → T-Car (Punkte)
- `innings_a`, `innings_b` → T-Inn
- `gd` → General Average (wird berechnet)
- `hs_a`, `hs_b` → 1st HR (High Run)
- `type` → 'InternationalGame' (STI)
- `data` → { group: 'A', round: 'PPPQ', ... }

### GameParticipation
- `game_id` → Game
- `player_id` → Player
- `points` → T-Car
- `innings` → T-Inn
- `average` → Avg
- `highrun` → 1st HR
- Für Rankings!

## Parsing Strategy

1. **Group identifizieren**: "Group A", "Group B"
2. **Match Pairs erkennen**: 2 aufeinanderfolgende Zeilen mit Spielerdaten
3. **Game erstellen**: Mit beiden Spielern
4. **GameParticipations erstellen**: Für jeden Spieler

## Beispiel Match

```
JEONGU Park                 30       14     2.142      2        9        4
KIYOTA Atsushi             17       14     1.214      0        8        2
```

→ Game:
- player_a: JEONGU Park, score_a: 30, innings_a: 14, hs_a: 9
- player_b: KIYOTA Atsushi, score_b: 17, innings_b: 14, hs_b: 8
- winner: JEONGU Park (MP=2)
