# LigaManager API — Fixtures (TBV, association_id=1)

Roh-Response-Bodies der öffentlichen LigaManager-API (`https://ligen.billard.center/api`),
aufgezeichnet 2026-07-13 in Phase 6 (Recon). Deterministische Fixtures für Phase 7 (Scraper)
und Phase 8 (Abgleich).

**Zugangs-Gate:** Die API antwortet anonym mit HTTP 403. Zum Neu-Aufzeichnen Browser-Header setzen:
`User-Agent: Mozilla/5.0 …`, `Referer: https://ligen.billard.center/landesverband-thueringen`,
`Origin: https://ligen.billard.center`.

| Datei | Endpunkt |
|-------|----------|
| `associations_public-show_id-1.json` | `/associations/public-show?id=1` |
| `seasons_status-2-3.json` | `/seasons?status[]=2&status[]=3` |
| `game-types.json` | `/game-types` |
| `leagues_season-1.json` | `/leagues?season_id=1` |
| `leagues_5.json` | `/leagues/5` |
| `clubs_public_association-1.json` | `/clubs/public?association_id=1` |
| `teams_league-5.json` | `/teams?league_id=5` |
| `match-plan_public_league-5.json` | `/match-plan/public?league_id=5` |
| `leagues_5_standings.json` | `/leagues/5/standings` |
| `leagues_5_ranking.json` | `/leagues/5/ranking` |
| `members_public_club-16.json` | `/members/public?club_id=16&per_page=200` |
| `results_by-matchplan_30.html` | `/results/public-view-by-matchplan?matchplan_id=30` (HTML!) |

**Hinweis:** Dies sind Roh-Bodies, keine VCR-YAML-Cassettes. Echte Cassettes entstehen in Phase 7
mit dem Scraper-Test (korrektes Request-URI-Matching). Referenzliga für Detail-Endpunkte:
League 5 „Mehrkampf Oberliga" (Season 1 Karambol), Club 16 „TuS Weida", Matchplan 30.
