# Phase 26: UmbScraper Service Extraction + V2 Absorption - Validation

**Extracted from:** 26-RESEARCH.md Validation Architecture section
**Created:** 2026-04-12

---

## Test Framework

| Property | Value |
|----------|-------|
| Framework | Minitest (Rails default) |
| Config file | `test/test_helper.rb` |
| Quick run command | `bin/rails test test/services/umb/` |
| Full suite command | `bin/rails test` |

## Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SCRP-06 | `Umb::PlayerResolver` finds/creates players by name and umb_player_id | unit | `bin/rails test test/services/umb/player_resolver_test.rb` | Wave 0 |
| SCRP-06 | `Umb::PlayerListParser` extracts seedings from PDF text | unit | `bin/rails test test/services/umb/pdf_parser/player_list_parser_test.rb` | Wave 0 |
| SCRP-06 | `Umb::GroupResultParser` extracts match pairs and creates Game records | unit | `bin/rails test test/services/umb/pdf_parser/group_result_parser_test.rb` | Wave 0 |
| SCRP-06 | `Umb::RankingParser` extracts final ranking positions | unit | `bin/rails test test/services/umb/pdf_parser/ranking_parser_test.rb` | Wave 0 |
| SCRP-06 | `Umb::DetailsScraper` processes tournament detail page HTML | unit | `bin/rails test test/services/umb/details_scraper_test.rb` | Wave 0 |
| SCRP-06 | `Umb::FutureScraper` returns integer count and saves tournaments | unit | `bin/rails test test/services/umb/future_scraper_test.rb` | Wave 0 |
| SCRP-06 | `Umb::ArchiveScraper` scans ID range and returns count | unit | `bin/rails test test/services/umb/archive_scraper_test.rb` | Wave 0 |
| SCRP-06 | `UmbScraper` thin wrappers preserve original public interface | regression | `bin/rails test test/characterization/umb_scraper_char_test.rb` | Existing |
| SCRP-07 | V2's PDF parsing behavior is preserved in `Umb::` services | unit | Covered by SCRP-06 tests above | Wave 0 |
| SCRP-07 | `umb_scraper_v2.rb` does not exist after phase | smoke | `bin/rails test test/characterization/umb_scraper_v2_char_test.rb` | DELETE this file |

## Sampling Rate

- **Per task commit:** `bin/rails test test/services/umb/` (new service tests only — fast)
- **Per wave merge:** `bin/rails test test/characterization/umb_scraper_char_test.rb test/services/umb/`
- **Phase gate:** `bin/rails test` full suite green before `/gsd-verify-work`

## Wave 0 Gaps

- [ ] `test/services/umb/player_resolver_test.rb` — covers SCRP-06 PlayerResolver
- [ ] `test/services/umb/pdf_parser/player_list_parser_test.rb` — covers SCRP-06/07 V2 absorption
- [ ] `test/services/umb/pdf_parser/group_result_parser_test.rb` — covers SCRP-06/07 V2 absorption
- [ ] `test/services/umb/pdf_parser/ranking_parser_test.rb` — covers SCRP-06 new implementation
- [ ] `test/services/umb/details_scraper_test.rb` — covers SCRP-06
- [ ] `test/services/umb/future_scraper_test.rb` — covers SCRP-06
- [ ] `test/services/umb/archive_scraper_test.rb` — covers SCRP-06
- [ ] `test/fixtures/pdf/umb_ranking_sample.pdf` (or text fixture) — needed by ranking_parser_test.rb
- [ ] `lib/tasks/umb_v2.rake` DELETE — Wave 0 deletion task alongside V2 removal

---

*Phase: 26-umbscraper-service-extraction-v2-absorption*
*Validation plan created: 2026-04-12*
