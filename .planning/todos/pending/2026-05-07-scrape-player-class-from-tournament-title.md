---
created: 2026-05-07T01:58:00Z
title: Beim Scrapen player_class aus Tournament-Titel extrahieren
area: scraping / tournament-data-import
files:
  - app/services/umb_scraper_v2.rb (UMB scraper — primary source for "Klasse N" titles like "NDM Cadre 35/2 Klasse 1")
  - app/services/cuesco_scraper.rb (Cuesco/Five&Six scraper — same title patterns observed)
  - app/models/tournament.rb (target attribute: player_class — already exists, accepts "I"/"II"/"III"/"1".."7" per app/views/tournaments/_form.html.erb:55-56)
  - app/models/discipline.rb (downstream consumer — Phase 39 parameter_ranges short-circuits when player_class.blank?)
---

## Problem

Bestands-Turniere aus dem Scraping-Pfad (UMB / Cuesco / SoopLive / Ko-Zoom) haben `tournament.player_class = nil`, obwohl die Klasse häufig direkt im Titel-String steht. Beispiel — Tournament 17401:

```
title:        "NDM Cadre 35/2 Klasse 1"
player_class: nil
```

**Folge:** Phase 39's `Discipline#parameter_ranges` short-circuited (RQ-03 defensive guard `return {} if tournament.player_class.blank?`) → Verifikations-Modal feuert für **alle gescrapten Turniere nicht**, obwohl DTP-Daten korrekt vorliegen. Discovered during Phase 39 UAT (Round 2, 2026-05-07): operator musste Tournament 17401 manuell mit `t.update!(player_class: "1")` patchen, damit der Modal feuerte.

## Solution

Im Scraper-Pfad einen Klassen-Extraktor einhängen, der den Titel-String parst und `player_class` setzt. Erkennungsmuster aus realen Daten:

- `"NDM Cadre 35/2 Klasse 1"` → `"1"`
- `"DM Dreiband Klasse 2"` → `"2"`
- `"Klasse III"` / `"Kl. III"` → `"III"`
- `"Klasse 5"` / `"Kl. 5"` / `"Kl 5"` → `"5"`
- Weitere Varianten zu prüfen: gezählter Index `"Klasse"` / `"Kl."` / `"Kl"` mit Leerzeichen-Toleranz

**Vorgehensvorschlag:**

1. **Helper extrahieren** — `Tournament#extract_player_class_from_title` (oder als Service `PlayerClassExtractor`) mit regex-basiertem Matcher:
   ```ruby
   PLAYER_CLASS_PATTERN = /\bKl(?:asse|\.)?\s+(I{1,3}|[1-7])\b/i.freeze
   ```
   Akzeptiert Werte aus dem Standard-Set `["I", "II", "III", "1", "2", "3", "4", "5", "6", "7"]` (matching `_form.html.erb:56`).

2. **Scraper-Integrationspunkte** — in jeder Scraper-Klasse beim Tournament-Persist (`tournament.save!`) den Helper aufrufen, sofern `player_class` noch leer:
   - `UmbScraperV2` (UMB-Pfad — primärer Verdächtiger für "NDM/DM Klasse N"-Titel)
   - `CuescoScraper` (Cuesco/Five&Six)
   - Andere Scraper bei Bedarf

3. **Daten-Migration für Bestands-Turniere** — separater Rails-Task / Quick-Task (z. B. `bin/rails carambus:backfill_player_class_from_titles`):
   ```ruby
   Tournament.where(player_class: nil).find_each do |t|
     extracted = PlayerClassExtractor.call(t.title)
     t.update_column(:player_class, extracted) if extracted
   end
   ```
   Use `update_column` to bypass LocalProtector callbacks for global-id'd tournaments — careful: this writes to records with `id < MIN_ID` on the central API server. Backfill should run only on the API server (or be guarded explicitly).

4. **Tests** — Unit-Tests für den Extraktor + Scraper-Integration-Tests die das Persist-Verhalten verifizieren.

5. **Constraint** — die Validierung darf den Scraping-Pfad nicht brechen, falls der Titel keine Klasse enthält. `nil` bleibt erlaubter Wert (RQ-03 Short-Circuit ist defensiv by-design für genau diesen Fall).

**Schweregrad:** Mittel-hoch. Phase 39 (DTP-backed Parameter Ranges) ist für gescrapte Turniere praktisch wirkungslos, solange dieses TODO nicht abgearbeitet ist. Workaround: Operator setzt `player_class` manuell vor Tournament-Start.

**Discovered during:** Phase 39 UAT, Round 2 (2026-05-07T01:56Z) — Tournament 17401 "NDM Cadre 35/2 Klasse 1".

**Touches:**
- Scraping-Layer (`app/services/*_scraper*.rb`)
- Tournament-Modell (kein neues Feld nötig — `player_class` existiert bereits)
- Optional: Daten-Migration für Bestands-Turniere (zentrale API-DB)
