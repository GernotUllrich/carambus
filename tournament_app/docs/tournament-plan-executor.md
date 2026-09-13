# TournamentPlan / `executor_params` — Spezifikation (App-seitige Interpretation)

> Ziel: ein **datengetriebenes Schema**, das beliebige Carambus-`TournamentPlan`s
> (T01–T24, Default*, KO_*, DKO_*) **offline in der App** ausführt. Quelle der
> Wahrheit ist die Carambus-Engine (`app/services/tournament_monitor/*`,
> `app/models/tournament_plan.rb`); diese Datei hält die portierte Spezifikation
> fest. **Bitte Regel-Interpretation (Abschnitt „Ranking") gegenchecken.**

## Datenquelle

`GET /api/external_tournament/disciplines?region=…` liefert (Phase 20):
- `tournament_plans` (Dict, Key = Plan-Name): `players, tables, ngroups, nrepeats,
  rulesystem, executor_class, executor_params` (roher JSON-String), Beschreibungen.
- `disciplines[].parameters[]`: `{ tournament_plan, players, player_class, points, innings }`
  → pro (Disziplin × Plan × Klasse × Spielerzahl) die offiziellen Ziel-Werte.

## `executor_params` — DSL (JSON)

Top-Level-Keys: **`g<N>`** (Gruppen), **Platzierungs-/KO-Spiele** (`hf1`, `fin`,
`p<5-6>`, `qf1`, `8f1`, `w1.1`, `l1.1`, …), **`RK`** (Endplatzierung), **`GK`** (Spielzahl),
optional **`rules`** (benannte Regel-Ausdrücke).

### Gruppen `g<N>`
```jsonc
"g1": { "pl": 5, "rs": "eae", "sq": {
  "r1": {"t1":"2-4","t2":"1-5"}, "r2": {"t1":"1-4","t2":"2-3"}, … } }
```
- `pl` = Spielerzahl der Gruppe, `rs` = Rulesystem (`eae`, `eae_ma`, …).
- `sq` = Spielplan: **Runde** `r<k>` → **Tisch-Token** → **Paarung** `"<pos>-<pos>"`
  (Gruppen-Positionen, 1-basiert).
- (Default-Pläne nutzen `sq` auch als **Array** von `"a - b"`-Strings ohne Runden/Tische.)
- Spiel-Name (gname): **`group<N>:<pos>-<pos>`** (z. B. `group1:2-4`).

### Platzierungs-/KO-Spiele
```jsonc
"hf1":     { "r4": { "t-rand-1-2": ["g1.rk1","g2.rk2"] } },
"p<5-6>":  { "r4": { "t3":         ["g1.rk3","g2.rk3"] } },
"fin":     { "r5": { "t-admin-1-3":["hf1.rk1","hf2.rk1"] } }
```
- Form: `name → { runde → { tisch-token → [refA, refB] } }`.
- KO-Familien-Namen: `64f,32f,16f,8f,qf,hf,fin` (Single-KO), `w<l>.<i>`/`l<l>.<i>`
  (Doppel-KO), `p<a-b>` (Platzierungsspiel um Plätze a..b).

### Tisch-Tokens
- `t1`,`t2`,… = fester Tisch. `t-rand-1-2` = zufällig aus Tischen 1–2.
  `t-admin-1-3` = Operator wählt aus 1–3. `t-rand*` = beliebiger Tisch.
- App: Tisch-Token bestimmt nur die **Tisch-Zuteilung** beim Start; für die
  Graph-/Ergebnislogik irrelevant.

### Refs (Spieler-/Platz-Verweise)
- `sl.rk<n>` = Setzliste Platz n.
- `g<N>.rk<n>` = Platz n der **Gruppe N** (nach Gruppen-Standings, s. u.).
- `<spiel>.rk1` / `.rk2` = **Sieger / Verlierer** des Spiels (z. B. `hf1.rk1`).
- Zusammengesetzt: `(g1.rk4 + g2.rk4 + g3.rk4).rk2` = 2.-Bester aus den genannten
  Gruppen-Rängen (gruppenübergreifend, geordnet wie Inter-Group, s. u.).
  Variante `.rk-rand-1-4` = zufällige Zuordnung innerhalb der Menge.
- `rule<k>` = benannter Ausdruck aus `executor_params["rules"]`.

### `RK` / `GK`
- `RK` = geordnete Ref-Liste → finale Platzierung (Platz 1 = `RK[0]`).
- `GK` = Gesamt-Spielzahl (Sanity-Check gegen erzeugte Spiele).

## Ranking (KRITISCH — bitte gegenchecken)

**Gruppen-Standings** (`g<N>.rk<n>`): pro Spieler über seine Gruppenspiele akkumuliert
(`add_result_to` / `accumulate_results`):
- `points` = Summe der **Matchpunkte** je Spiel: **Sieg = 2, Remis = 1, Niederlage = 0**
  (`result_processor.rb#update_game_participations_for_game`). Sieg/Remis/Niederlage wird
  über `rank = result / balls_goal × 100` entschieden (Erreichungsgrad — bei Handicap
  ausschlaggebend; bei gleichem `balls_goal` = reiner Bälle-Vergleich). Bei Mehrsatz
  (`sets_to_play > 1`) zählt die Zahl der gewonnenen Sätze.
- `result` = Summe Bälle, `innings` = Summe Aufnahmen, **`gd` = result/innings** (2 NK).
- `hs` = höchste Serie, `bed` = beste Einzel-GD (HGD).
- `gd_pct` = `100 * gd / (balls_goal/innings_goal)` (nur Handicap).

**Sortierung** (`TournamentMonitor.ranking`, lexikografisch absteigend):
- Standard: **`[points, gd]`** (erst Punkte, dann GD).
- `gd_has_prio?`: `[gd, points]`. Handicap (`handicap_tournier?`): `gd`→`gd_pct`.
- Inter-Group (zusammengesetzte Refs) nutzt dieselbe Ordnung.

**Einzelspiel-Sieger** (`.rk1`/`.rk2`): höhere Bälle = Sieger (bei Remis/Gleichstand →
Sonderregel/Operator — wie im Doppel-KO).

## Engine-Aufgaben (App)

1. **Parse** `executor_params` → Spielgraph (Gruppen-Spiele + Platzierungsspiele + RK).
2. **Setzliste → Gruppen** verteilen (`PlayerGroupDistributor`, `group_sizes` aus `g<N>.pl`).
3. **Refs auflösen** nach jedem Ergebnis: Gruppen-Standings + Sieger/Verlierer + RK.
4. **Lebenszyklus**: bereite Spiele an freien Tischen starten, Ergebnisse erfassen,
   Folge-Spiele freischalten (wie Doppel-KO, aber generisch).

## Referenzen (carambus_master)
- `app/models/tournament_plan.rb` (Plan-Generatoren Default/KO/DKO, `group_sizes`, `rounds_count`).
- `app/services/tournament_monitor/result_processor.rb` (`accumulate_results`, `add_result_to`, `update_ranking`).
- `app/services/tournament_monitor/ranking_resolver.rb` (Ref-Auflösung).
- `app/services/tournament_monitor/player_group_distributor.rb` (Setzliste→Gruppen).
- `app/models/tournament_monitor.rb#ranking` (Sortierung).
- Fixtures: `test/fixtures/tournament_plans.yml` (T04, T06 — Referenz-Beispiele).
