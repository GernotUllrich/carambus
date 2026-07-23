# Phase 38 I18N-02 Audit

**Generated:** 2026-04-15
**Scope:** `app/views/tournaments/*.html.erb` (22 files, **excluding** `_wizard_steps_v2.html.erb` per CONTEXT.md §D-11 which was already fully i18n'd by Phase 36B)
**Requirement:** I18N-02 (G-04) — close DE-only hardcoded-string debt on tournament views

## Method

- Step 1: CONTEXT.md §D-13 starter grep (`Aktuelle|Turnier|Starte|zurück`)
- Step 2: Broader sweep for common German UI words (Spieler/Teilnehmer/Runde/Setzliste/…)
- Step 3: Manual classification of each finding (user-visible vs developer-facing vs code)
- Step 4: Namespace assignment per CONTEXT.md §D-12
- Step 5: Proposed DE + EN key tree

## Summary

- **Total files scanned:** 22
- **Files with findings:** 14
- **Files with zero findings:** 8 (`_balls_goal.html.erb`, `_search.html.erb`, `_party_record.html.erb`, `_tournaments_table.html.erb`, `_wizard_step.html.erb` [one placeholder fixed], `_bracket.html.erb` [one string], `_groups.html.erb` [3 strings], `_groups_compact.html.erb` [1 string] — technically some of these have findings but are tiny)
- **Total hardcoded user-visible strings to localize:** ~180 (after false-positive filtering)
- **New i18n keys to add:** ~180 (grouped into ~20 namespace leaves)
- **False positives skipped:** ERB comments (`<%# … %>`), Ruby code comments (`<%- # … %>`), JavaScript developer log messages (`console.warn`/`console.error` — not user-visible), placeholder fallback strings inside `I18n.t(…, default: "…")` calls (already localized with fallback)

## Namespace Assignment per CONTEXT.md §D-12

Per file → target namespace:

| File | Namespace |
|------|-----------|
| `tournament_monitor.html.erb` | `tournaments.monitor.*` |
| `_tournament_status.html.erb` | `tournaments.monitor.*` (monitor-adjacent) |
| `_groups.html.erb` | `tournaments.monitor.*` (monitor-adjacent) |
| `_groups_compact.html.erb` | `tournaments.monitor.*` (monitor-adjacent) |
| `_bracket.html.erb` | `tournaments.monitor.*` (monitor-adjacent) |
| `_balls_goal.html.erb` | n/a (no strings) |
| `_party_record.html.erb` | n/a (no strings) |
| `show.html.erb` | `tournaments.show.*` |
| `_show.html.erb` | `tournaments.show.*` |
| `_admin_tournament_info.html.erb` | `tournaments.show.*` (admin subsection) |
| `index.html.erb` | `tournaments.index.*` |
| `_tournaments_table.html.erb` | n/a (English column labels already in place) |
| `_search.html.erb` | n/a (only renders `_tournaments_table` partial) |
| `_form.html.erb` | `tournaments.form.*` |
| `_wizard_step.html.erb` | `tournaments.wizard_step.*` |
| `edit.html.erb` | `tournaments.edit.*` |
| `new.html.erb` | (already i18n'd, nothing to add) |
| `new_team.html.erb` | `tournaments.new_team.*` |
| `compare_seedings.html.erb` | `tournaments.compare_seedings.*` |
| `define_participants.html.erb` | `tournaments.define_participants.*` |
| `finalize_modus.html.erb` | `tournaments.finalize_modus.*` (extends the existing subtree) |
| `parse_invitation.html.erb` | `tournaments.parse_invitation.*` |

## Findings by File

### app/views/tournaments/tournament_monitor.html.erb

| Line | Current text | New key |
|------|--------------|---------|
| 45 | "Zuordnung der Tische" | `tournaments.monitor.table_assignment_heading` |
| 81 | "Tisch " (label prefix) | `tournaments.monitor.table_prefix` |
| 84, 87 | "Small Billard" → "kleiner Tisch", "Match Billard" → "großer Tisch" | leave as-is (inline gsub on scraped table_kind names; mixing i18n here is a code refactor, not a string move) — document as false positive |
| 95 | "Turnier Parameter" | `tournaments.monitor.tournament_parameters_heading` |
| 149 | "Back to Mode Selection" | `tournaments.monitor.back_to_mode_selection` |

### app/views/tournaments/_tournament_status.html.erb

| Line | Current text | New key |
|------|--------------|---------|
| 6 | "📊 Turnier-Status: " (prefix) | `tournaments.monitor.status_heading` |
| 13 | "Aktuelle Phase" | `tournaments.monitor.current_phase` |
| 21 | "Runde %{round}" | `tournaments.monitor.round_label` (interpolated) |
| 31 | "Spiele-Fortschritt" | `tournaments.monitor.games_progress` |
| 39 | "%{finished} / %{total} Spiele" | `tournaments.monitor.games_count` (interpolated) |
| 48 | "Aktuelle Spiele" | `tournaments.monitor.current_games` |
| 90 | "▶️ Läuft" | `tournaments.monitor.game_running` |
| 96 | "Keine aktiven Spiele" | `tournaments.monitor.no_active_games` |
| 106 | "🎮 Tournament Monitor öffnen" | `tournaments.monitor.open_tournament_monitor` |
| 112 | "🔄 Test Update" | `tournaments.monitor.test_update_button` |
| 128 | "📺 Scoreboards anzeigen (read-only)" | `tournaments.monitor.show_scoreboards` |
| 140 | "Gruppen" | `tournaments.monitor.groups_heading` |
| 152 | "Aktuelle Platzierungen" | `tournaments.monitor.current_rankings` |
| 206 | "📋 Setzliste" | `tournaments.monitor.seeding_heading` |
| 211 | "Pos." | `tournaments.monitor.position_short` |
| 212 | "Spieler" | `tournaments.monitor.player` |
| 213 | "Club" | `tournaments.monitor.club` |
| 215 | "Vorgabe (Ballziel)" | `tournaments.monitor.handicap_balls_goal` |
| 217 | "Ranking" | `tournaments.monitor.ranking` |
| 245 | "💡 Alle Rankings:" | `tournaments.monitor.all_rankings_label` |
| 246 | "%{org} Rangliste %{discipline}" | `tournaments.monitor.region_ranking_link` (interpolated) |

### app/views/tournaments/_groups.html.erb

| Line | Current text | New key |
|------|--------------|---------|
| 10 | "Gruppe %{n}" | `tournaments.monitor.group_number` (interpolated) |
| 21 | "Keine Spieler" | `tournaments.monitor.no_players` |
| 29 | "Keine Gruppenbildung verfügbar" | `tournaments.monitor.no_groups` |

### app/views/tournaments/_groups_compact.html.erb

| Line | Current text | New key |
|------|--------------|---------|
| 6 | "Gr. %{n}" | `tournaments.monitor.group_short` (interpolated) |
| 27 | "Keine Gruppenzuordnung" | `tournaments.monitor.no_group_assignment` |

### app/views/tournaments/_bracket.html.erb

Note: the `Freilos / Bye`, `Sieger #{src}`, `Verlierer #{src}` strings are inside a Ruby helper method (`display_player`) that returns labels for bracket positions. These are user-visible in the rendered bracket. Also the `bracket_groups << { title: "🏆 Gewinnerrunde" }` etc. are user-visible group titles.

| Line | Current text | New key |
|------|--------------|---------|
| 164 | "Freilos / Bye" | `tournaments.monitor.bracket_bye` |
| 168 | "Sieger %{src}" | `tournaments.monitor.bracket_winner_of` (interpolated) |
| 171 | "Verlierer %{src}" | `tournaments.monitor.bracket_loser_of` (interpolated) |
| 189 | "🏆 Gewinnerrunde" | `tournaments.monitor.bracket_winner_round` |
| 190 | "💥 Verliererrunde" | `tournaments.monitor.bracket_loser_round` |
| 191 | "👑 Finalrunde" | `tournaments.monitor.bracket_final_round` |
| 193 | "🏆 Turnierbaum" | `tournaments.monitor.bracket_tree` |

### app/views/tournaments/show.html.erb

| Line | Current text | New key |
|------|--------------|---------|
| 21 | "Turnier ist schreibgeschützt" | `tournaments.show.readonly_heading` |
| 23 | "Dieses Turnier hat bereits..." (multi-line explanation) | `tournaments.show.readonly_body_html` (HTML-safe; has `<strong>` markup) |
| 179 | "📝 Teilnehmerliste bearbeiten" | `tournaments.show.edit_participants_button` |
| 183 | "Teilnehmer hinzufügen, bearbeiten oder entfernen" (title attribute) | `tournaments.show.edit_participants_title` |

Strings on lines 195-211, 221-237 are already inside `I18n.t(…, default: "…")` calls — those have fallbacks and are technically already localized (just missing DE key entries). We will add the missing DE+EN keys as backing for those fallback calls to make them proper lookups.

| Line | Default text | New key (adds backing for existing fallback) |
|------|--------------|---------|
| 195 | "Aktueller Status:" | `tournaments.show.reset_tournament_modal.state_line` |
| 196 | "Gespielte Spiele:" | `tournaments.show.reset_tournament_modal.games_line` |
| 199 | "Achtung: Alle lokalen Setzlisten..." | `tournaments.show.reset_tournament_modal.body` |
| 208 | "Turnier-Monitor zurücksetzen" | `tournaments.show.reset_tournament_modal.title` |
| 210 | "Ja, zurücksetzen" | `tournaments.show.reset_tournament_modal.confirm` |
| 225 | "DATENVERLUST: Alle lokalen Setzlisten..." | `tournaments.show.force_reset_tournament_modal.body` |
| 234 | "Turnier-Monitor zwangsweise zurücksetzen" | `tournaments.show.force_reset_tournament_modal.title` |
| 236 | "Ja, zwangsweise zurücksetzen" | `tournaments.show.force_reset_tournament_modal.confirm` |

### app/views/tournaments/_show.html.erb

| Line | Current text | New key |
|------|--------------|---------|
| 46 | "Turnierdaten anzeigen" | `tournaments.show.show_tournament_data` |
| 62 | "📊 Turnier-Daten: " (modal title prefix) | `tournaments.show.tournament_data_modal_title` |
| 81 | "Schließen" | `tournaments.show.close` |
| 172 | "Last Sync:" | `tournaments.show.last_sync` |

Note: Line 8 `'Edit'` is an English string passed to `button_to` — we'll i18n it too. Note: Line 164 `"Kick-Off Player"` is a fallback label for `tournament.fixed_display_left` — leave as-is (it's an English default label, not a German-only string).

| Line | Current text | New key |
|------|--------------|---------|
| 8 | "Edit" | `tournaments.show.edit_button` |

### app/views/tournaments/_admin_tournament_info.html.erb

| Line | Current text | New key |
|------|--------------|---------|
| 6 | "🔧 Spielleiter-Informationen" | `tournaments.show.admin_heading` |
| 13 | "📄 Geparste Einladung" | `tournaments.show.parsed_invitation_heading` |
| 15 | "Datei:" | `tournaments.show.file_label` |
| 20 | "Extrahierter Turniermodus:" | `tournaments.show.extracted_mode_label` |
| 27 | "Extrahierte Gruppenbildung anzeigen" | `tournaments.show.show_extracted_groups` |
| 35 | "Position %{pos}" | `tournaments.show.position_fallback` (interpolated) |
| 46 | "⚠️ Keine Einladung hochgeladen" | `tournaments.show.no_invitation_uploaded` |
| 53 | "📋 Setzliste" | `tournaments.show.seeding_heading` |
| 62 | "Pos." | `tournaments.show.position_short` |
| 63 | "Spieler" | `tournaments.show.player` |
| 65 | "Vorgabe" | `tournaments.show.handicap_short` |
| 84 | "... und %{count} weitere Spieler" | `tournaments.show.more_players` (interpolated) |
| 92 | "🔗 Schnellzugriff" | `tournaments.show.quick_links_heading` |
| 95 | "🎮 Tournament Monitor" | `tournaments.show.tournament_monitor_button` |
| 101 | "📄 Einladung prüfen" | `tournaments.show.review_invitation_button` |
| 106 | "✏️ Teilnehmer bearbeiten" | `tournaments.show.edit_participants_button_admin` |

### app/views/tournaments/index.html.erb

| Line | Current text | New key |
|------|--------------|---------|
| 8 | "API Server - Nur-Lese-Modus" | `tournaments.index.api_server_readonly_heading` |
| 10-13 | "Dies ist der zentrale API Server..." (multi-line HTML body) | `tournaments.index.api_server_readonly_body_html` |
| 25 | "New Tournament" (hardcoded English label for button) | `tournaments.index.new_tournament_button` (DE: "Neues Turnier", EN: "New Tournament") |

### app/views/tournaments/_form.html.erb

| Line | Current text | New key |
|------|--------------|---------|
| 130 | "ClubCloud URL" (form label) | `tournaments.form.clubcloud_url` |
| 133 | "Importiertes Turnier - Bearbeitung eingeschränkt" | `tournaments.form.imported_tournament_note` |
| 138 | "Lokale Konfiguration" (form label) | `tournaments.form.local_config_label` |
| 143 | "Save Tournament" | `tournaments.form.save_tournament` |

### app/views/tournaments/_wizard_step.html.erb

| Line | Current text | New key |
|------|--------------|---------|
| 46 | "Dieser Schritt ist noch offen" | `tournaments.wizard_step.pending_default` |
| 53 | "💡 Was macht dieser Schritt?" | `tournaments.wizard_step.help_summary` |
| 79 | "Erst verfügbar nach vorherigem Schritt" | `tournaments.wizard_step.pending_hint` |

### app/views/tournaments/edit.html.erb

| Line | Current text | New key |
|------|--------------|---------|
| 4 | "Edit Tournament" | use existing `tournaments.edit.editing_tournament` |
| 5 | "Cancel" | `tournaments.edit.cancel` |

### app/views/tournaments/new.html.erb

| Line | Current text | New key |
|------|--------------|---------|
| 5 | "Cancel" | `tournaments.new.cancel` |

### app/views/tournaments/new_team.html.erb

| Line | Current text | New key |
|------|--------------|---------|
| 6 | "Neues TurnierTeam" | `tournaments.new_team.heading` |
| 9 | "Player%{n} BaID:" | `tournaments.new_team.player_ba_id_label` (interpolated) |
| 9 | "player %{n} BA ID" (placeholder) | `tournaments.new_team.player_ba_id_placeholder` (interpolated) |
| 11 | "Add Team to Seedings List" | `tournaments.new_team.add_team_button` |

### app/views/tournaments/compare_seedings.html.erb

| Line | Current text | New key |
|------|--------------|---------|
| 7 | "Setzliste übernehmen: " (prefix) | `tournaments.compare_seedings.heading` |
| 9 | "← Zurück" | `tournaments.compare_seedings.back` |
| 14 | "💡 So funktioniert's:" | `tournaments.compare_seedings.how_it_works` |
| 16 | "Laden Sie die offizielle Einladung (PDF oder Screenshot) hoch" | `tournaments.compare_seedings.step_1_html` |
| 17 | "Carambus extrahiert automatisch die Setzliste" | `tournaments.compare_seedings.step_2_html` |
| 18 | "Sie prüfen und bestätigen die erkannten Spieler" | `tournaments.compare_seedings.step_3` |
| 19 | "Die Reihenfolge wird übernommen" | `tournaments.compare_seedings.step_4` |
| 25 | "📧 Offizielle Einladung hochladen" | `tournaments.compare_seedings.upload_heading` |
| 32 | "✅ Einladung vorhanden: " | `tournaments.compare_seedings.invitation_present` |
| 36 | "Erneut parsen" | `tournaments.compare_seedings.reparse` |
| 51 | "Datei hier ablegen" | `tournaments.compare_seedings.drop_file_here` |
| 67 | "Datei auswählen" | `tournaments.compare_seedings.choose_file` |
| 72 | "PDF oder Screenshot (PNG, JPG)" | `tournaments.compare_seedings.file_types` |
| 73 | "💡 Oder Datei hierher ziehen (z.B. aus E-Mail)" | `tournaments.compare_seedings.or_drag_file` |
| 77 | "Unterstützte Formate: PDF, PNG, JPEG" | `tournaments.compare_seedings.supported_formats` |
| 78 | "Die Setzliste wird automatisch extrahiert!" | `tournaments.compare_seedings.auto_extract_note` |
| 83 | "Hochladen & automatisch parsen" | `tournaments.compare_seedings.upload_and_parse` |
| 85 | "Wird verarbeitet..." | `tournaments.compare_seedings.processing` |
| 92 | "📊 Alternative: Mit ClubCloud-Meldeliste weitermachen" | `tournaments.compare_seedings.alt_clubcloud_heading` |
| 97-98 | "Falls keine Einladung vorliegt..." body text | `tournaments.compare_seedings.alt_clubcloud_body_html` |
| 102 | "Zwei Möglichkeiten:" | `tournaments.compare_seedings.two_options_label` |
| 104 | "Nach Rangliste sortiert..." (list item) | `tournaments.compare_seedings.option_by_ranking_html` |
| 105 | "Wie in ClubCloud..." (list item) | `tournaments.compare_seedings.option_as_clubcloud_html` |
| 110 | "🔗 ClubCloud öffnen (zum Vergleich)" | `tournaments.compare_seedings.open_clubcloud` |
| 118 | "ClubCloud-Meldeliste (%{count} Spieler):" | `tournaments.compare_seedings.clubcloud_list_heading` (interpolated) |
| 127 | "→ Mit Meldeliste zu Schritt 3 (nach Rangliste sortiert)" | `tournaments.compare_seedings.use_clubcloud_by_ranking` |
| 131 | "Meldeliste von ClubCloud..." (confirm message) | `tournaments.compare_seedings.confirm_use_clubcloud_by_ranking` |
| 135 | "Diese Reihenfolge übernehmen (wie in ClubCloud)" | `tournaments.compare_seedings.use_clubcloud_as_is` |
| 137 | "ClubCloud-Reihenfolge exakt..." (confirm message) | `tournaments.compare_seedings.confirm_use_clubcloud_as_is` |
| 143 | "⚠️ Keine ClubCloud-Daten verfügbar." | `tournaments.compare_seedings.no_clubcloud_data` |
| 144 | "Bitte zuerst in Schritt 1..." | `tournaments.compare_seedings.load_clubcloud_hint` |
| 154 | "✏️ Alternative: Manuell sortieren" | `tournaments.compare_seedings.alt_manual_heading` |
| 157 | "Oder sortieren Sie die Liste automatisch nach aktueller Rangliste:" | `tournaments.compare_seedings.manual_sort_body` |
| 160 | "Nach Rangliste sortieren" | `tournaments.compare_seedings.sort_by_ranking` |

JavaScript error messages inside the inline `<script>` block (lines 274, 302, 303, 319, 333, 350) are developer-facing (console) or user-facing (alert) strings. The `alert(...)` calls are user-visible, but they're inside a JS block — localizing them requires either passing i18n values via data-attributes or server-rendered strings. Out of scope for a pure ERB/YAML i18n pass (they're JS logic, not ERB template literals). **False positives — skip.**

### app/views/tournaments/define_participants.html.erb

| Line | Current text | New key |
|------|--------------|---------|
| 16 | "Teamliste" (heading suffix) | `tournaments.define_participants.team_list_heading` |
| 20 | "Team" (column header) | `tournaments.define_participants.col_team` |
| 21 | "Teilnahme" (column header) | `tournaments.define_participants.col_participation` |
| 22 | "Punktziel bzw. Ranking" (column header) | `tournaments.define_participants.col_points_or_ranking` |
| 26 | "zurück" | `tournaments.define_participants.back` |
| 41 | "Neues Team" | `tournaments.define_participants.new_team` |
| 82 | "Teilnehmerliste" (heading suffix) | `tournaments.define_participants.heading` |
| 83 | "zurück" | same as line 26 |
| 87 | "📝 Teilnehmerliste bearbeiten" | `tournaments.define_participants.edit_heading` |
| 89 | "✓ Haken setzen/entfernen..." | `tournaments.define_participants.tip_check_boxes_html` |
| 90 | "Vorgaben (Punktziel) anpassen..." / "Änderungen werden sofort gespeichert" | `tournaments.define_participants.tip_handicap_html` / `tournaments.define_participants.tip_auto_save` |
| 91 | "🔢 Setzreihenfolge ändern: ..." | `tournaments.define_participants.tip_position_html` |
| 92 | "📊 Ranking-Spalte: ..." | `tournaments.define_participants.tip_ranking_html` (interpolated with discipline name) |
| 93 | "➕ Kurzfristig nachmelden?" | `tournaments.define_participants.tip_late_registration` |
| 100 | "Pos." | `tournaments.define_participants.col_pos` |
| 101 | "Neue Pos." | `tournaments.define_participants.col_new_pos` |
| 102 | "Reihenfolge" | `tournaments.define_participants.col_order` |
| 103 | "Name" | `tournaments.define_participants.col_name` |
| 104 | "Ranking" | `tournaments.define_participants.col_ranking` |
| 105 | "Teilnehmer" | `tournaments.define_participants.col_participant` |
| 106 | "Vorgabe (Pkt)" / "Punktziel" | `tournaments.define_participants.col_handicap` / `tournaments.define_participants.col_points_goal` |
| 163, 181 | "Nach oben" / "Bereits oben" (title) | `tournaments.define_participants.move_up` / `tournaments.define_participants.already_top` |
| 174, 181 | "Nach unten" / "Bereits unten" (title) | `tournaments.define_participants.move_down` / `tournaments.define_participants.already_bottom` |
| 191, 230 | "Rang %{rank} in %{discipline} (%{region})" | `tournaments.define_participants.rank_title` (interpolated) |
| 253 | "🔄 Teilnehmerliste sortieren" | `tournaments.define_participants.sort_heading` |
| 258 | "Sortiert nach aktuellem Carambus-Ranking" (title) | `tournaments.define_participants.sort_by_ranking_title` |
| 259 | "📊 Nach Ranking sortieren" | `tournaments.define_participants.sort_by_ranking` |
| 265 | "Sortiert nach Vorgabeziel..." (title) | `tournaments.define_participants.sort_by_handicap_title` |
| 266 | "🎯 Nach Vorgabeziel sortieren" | `tournaments.define_participants.sort_by_handicap` |
| 271 | "💡 Die Sortierung passt die Positionen automatisch an. Änderungen werden sofort gespeichert." | `tournaments.define_participants.sort_info` |
| 279 | "📊 Mögliche Turnierpläne für %{count} Teilnehmer" | `tournaments.define_participants.possible_plans_heading` (interpolated) |
| 287 | "📄 Aus Einladung:" | `tournaments.define_participants.from_invitation_label` |
| 289 | "🤖 Automatisch vorgeschlagen:" | `tournaments.define_participants.auto_suggested_label` |
| 293 | "⚠️ Weicht von NBV ab" | `tournaments.define_participants.differs_from_nbv` |
| 295 | "✓ NBV-konform" | `tournaments.define_participants.nbv_conform` |
| 301, 326, 365 | "Runde(n)" (plural suffix) | `tournaments.define_participants.rounds` (with pluralization via `count`) |
| 313 | "🔄 %{count} Alternative Plan(e) (%{discipline}) anzeigen" | `tournaments.define_participants.show_alternatives_same_discipline` (interpolated) |
| 345 | "⚙️ %{count} Weitere Plan(e) anzeigen" | `tournaments.define_participants.show_other_plans` (interpolated) |
| 347 | "(inkl. \"Jeder gegen Jeden\")" | `tournaments.define_participants.incl_round_robin` |
| 357 | "🎯 Jeder gegen Jeden" | `tournaments.define_participants.round_robin_tag` |
| 381 | "💡 Die Gruppenzuordnungen ändern sich automatisch..." | `tournaments.define_participants.groups_auto_update_info` |
| 384-385 | "ℹ️ Alternative Pläne können ggf. mit reduziertem Ausspielziel arbeiten..." | `tournaments.define_participants.reduced_mode_info_html` |
| 393 | "ℹ️ Für %{count} Teilnehmer ist aktuell kein Turnierplan für %{discipline} hinterlegt." | `tournaments.define_participants.no_plan_for_count` (interpolated) |
| 400 | "➕ Kurzfristiger Nachmelder?" | `tournaments.define_participants.late_registration_heading` |
| 402 | "Spieler mit DBU-Nummer hinzufügen (wird automatisch zur Liste hinzugefügt):" | `tournaments.define_participants.add_player_by_dbu_html` |
| 408 | "DBU-Nummer(n) eingeben..." (placeholder) | `tournaments.define_participants.dbu_nr_placeholder` |
| 413 | "💡 Mit DBU-Nummer: Spieler eindeutig identifiziert (empfohlen)..." | `tournaments.define_participants.dbu_nr_hint` |
| 416 | "Spieler hinzufügen" (submit) | `tournaments.define_participants.add_player_button` |
| 418 | "Wird gesucht..." | `tournaments.define_participants.searching` |
| 423 | "⚠️ Spieler ohne DBU-Nummer? (Klicken für Info)" | `tournaments.define_participants.no_dbu_nr_question` |
| 426 | "Spieler ohne DBU-Nummer können nicht nachgemeldet werden." | `tournaments.define_participants.no_dbu_nr_title` |
| 428 | "Grund: In der ClubCloud können nur Spieler mit DBU-Nummer eingetragen werden." | `tournaments.define_participants.no_dbu_nr_reason_html` |
| 431 | "Lösung:" | `tournaments.define_participants.solution_label` |
| 433 | "Spieler muss DBU-Nummer beantragen" | `tournaments.define_participants.solution_apply_dbu_nr` |
| 434 | "Oder: Turnierleiter trägt Spieler als Gast ein..." | `tournaments.define_participants.solution_add_guest` |
| 446 | "💡 Wichtig" | `tournaments.define_participants.important_label` |
| 448 | "✓ Alle Änderungen (Checkboxen, Vorgaben) werden sofort gespeichert" | `tournaments.define_participants.all_changes_saved_html` |
| 449 | "✓ Sie können jederzeit hierher zurückkehren um weitere Anpassungen vorzunehmen" | `tournaments.define_participants.can_return_anytime` |
| 452 | "⏭️ Wenn Sie fertig sind..." | `tournaments.define_participants.when_done_html` |
| 455 | "← Zurück zum Wizard" | `tournaments.define_participants.back_to_wizard` |

### app/views/tournaments/finalize_modus.html.erb

Note: many strings are already inside `I18n.t(…, default: …)` calls. We extend the existing `tournaments.finalize_modus` subtree.

| Line | Current text | New key |
|------|--------------|---------|
| 35 | "📄 Vorgaben aus Einladung:" | `tournaments.finalize_modus.invitation_specs_heading` |
| 40 | "Diese Informationen wurden automatisch aus der hochgeladenen Einladung extrahiert." | `tournaments.finalize_modus.extracted_info` |
| 66-67 | "✅ Gruppenbildung aus Einladung übernommen..." | `tournaments.finalize_modus.groups_from_invitation_html` |
| 71 | "🔄 Neu berechnen" | `tournaments.finalize_modus.recalculate` |
| 75 | "Extrahierte Gruppenbildung verwerfen und neu berechnen?" | `tournaments.finalize_modus.recalculate_confirm` |
| 76 | "Verwirft Einladungs-Zuordnung und berechnet mit NBV-Algorithmus" | `tournaments.finalize_modus.recalculate_title` |
| 83 | "⚠️ WARNUNG: Abweichung vom NBV-Standard erkannt!" | `tournaments.finalize_modus.warning_nbv_differs` |
| 86-87 | "Die Gruppenbildung in der Einladung unterscheidet sich..." | `tournaments.finalize_modus.warning_nbv_differs_body_html` (interpolated with plan name) |
| 91 | "✅ Einladung verwenden (empfohlen)" | `tournaments.finalize_modus.use_invitation` |
| 95 | "Gruppenbildung aus Einladung verwenden?..." | `tournaments.finalize_modus.use_invitation_confirm` |
| 96 | "Verwendet die offizielle Gruppenbildung aus der Einladung" | `tournaments.finalize_modus.use_invitation_title` |
| 98 | "🔄 Algorithmus verwenden (Risiko)" | `tournaments.finalize_modus.use_algorithm` |
| 102 | "ACHTUNG: Der Algorithmus könnte falsch sein!..." | `tournaments.finalize_modus.use_algorithm_confirm` |
| 103 | "Verwendet berechneten Algorithmus (könnte von NBV-Vorgaben abweichen)" | `tournaments.finalize_modus.use_algorithm_title` |
| 109 | "🔍 Vergleich anzeigen" | `tournaments.finalize_modus.show_comparison` |
| 113 | "📄 Aus Einladung (NBV-Vorgabe):" | `tournaments.finalize_modus.from_invitation_nbv` |
| 117 | "🤖 Berechnet (vermutlich falsch):" | `tournaments.finalize_modus.calculated_likely_wrong` |
| 128-129 | "🤖 Gruppenbildung automatisch berechnet (NBV-konform)..." | `tournaments.finalize_modus.groups_auto_calculated_html` |
| 135 | "✏️ Manuell anpassen" | `tournaments.finalize_modus.manually_adjust` |
| 139 | "\"Auch der Landessportwart irrt manchmal\" 😊" | `tournaments.finalize_modus.landessportwart_quote` |
| 140 | "Sie können die Gruppenzuordnung manuell korrigieren." | `tournaments.finalize_modus.manual_correct_hint` |
| 143 | "Hinweis: Diese Funktion ist in Entwicklung." | `tournaments.finalize_modus.in_development_html` |
| 144 | "Aktuell: Verwenden Sie '🔄 Neu berechnen' oder passen Sie die Setzliste in Schritt 3 an." | `tournaments.finalize_modus.current_workaround` |
| 147 | "Schließen" | `tournaments.finalize_modus.close` |

### app/views/tournaments/parse_invitation.html.erb

| Line | Current text | New key |
|------|--------------|---------|
| 7 | "Setzliste automatisch erkannt" | `tournaments.parse_invitation.heading` |
| 9 | "← Zurück" | `tournaments.parse_invitation.back` |
| 24 | "✅ %{count} Spieler automatisch erkannt!" | `tournaments.parse_invitation.players_detected` (interpolated) |
| 26 | "+ Gruppenbildung extrahiert 🎯" | `tournaments.parse_invitation.groups_extracted` |
| 30 | "Die Setzliste wurde aus der Einladung extrahiert." | `tournaments.parse_invitation.seeding_extracted` |
| 32 | "Bonus: Die Gruppenzuordnung wurde ebenfalls erkannt..." | `tournaments.parse_invitation.bonus_groups_html` |
| 34 | "Bitte prüfen Sie die erkannten Spieler und bestätigen Sie die Übernahme." | `tournaments.parse_invitation.please_review` |
| 42 | "🎯 Extrahierte Gruppenbildung" | `tournaments.parse_invitation.extracted_groups_heading` |
| 47 | "Gruppe %{group_no}" | reuse `tournaments.monitor.group_number` (interpolated) — cross-namespace reuse; we pick a new shared path or inline |
| 55 | "Spieler %{pos}" | `tournaments.parse_invitation.player_fallback` (interpolated) |
| 64 | "💡 Diese Zuordnung wird in Schritt 5 (Turniermodus) verwendet..." | `tournaments.parse_invitation.assignment_used_in_step5` |
| 72 | "Erkannte Spieler (%{rate}% Übereinstimmung)" | `tournaments.parse_invitation.detected_players_heading` (interpolated) |
| 79 | "Position" | `tournaments.parse_invitation.col_position` |
| 80 | "Erkannter Name" | `tournaments.parse_invitation.col_detected_name` |
| 81 | "Zugeordneter Spieler" | `tournaments.parse_invitation.col_matched_player` |
| 82 | "Vorgabe (Pkt)" | `tournaments.parse_invitation.col_handicap` |
| 83 | "Status" | `tournaments.parse_invitation.col_status` |
| 108 | "%{balls_goal} Pkt" | `tournaments.parse_invitation.points_suffix` (interpolated) |
| 115 | "✓ Sicher" | `tournaments.parse_invitation.confidence_high` |
| 117 | "⚠️ Vermutung" | `tournaments.parse_invitation.confidence_low` |
| 128 | "⚠️ Nicht zugeordnet (%{count}):" | `tournaments.parse_invitation.unmatched_heading` (interpolated) |
| 132 | "%{name} (Position %{position})" | `tournaments.parse_invitation.unmatched_item` (interpolated) |
| 136 | "Diese Spieler sind nicht in der Meldeliste. Bitte fügen Sie sie manuell hinzu." | `tournaments.parse_invitation.unmatched_hint` |
| 142 | "Abbrechen" | `tournaments.parse_invitation.cancel` |
| 144 | "Setzliste übernehmen" | `tournaments.parse_invitation.apply_seeding` |
| 146 | "Setzliste mit %{count} Spielern übernehmen?" | `tournaments.parse_invitation.apply_seeding_confirm` (interpolated) |
| 154 | "🔍 Extrahierter Text anzeigen (Debugging)" | `tournaments.parse_invitation.show_extracted_text` |
| 163 | "❌ Automatische Extraktion fehlgeschlagen" | `tournaments.parse_invitation.extraction_failed` |
| 170 | "Alternativen:" | `tournaments.parse_invitation.alternatives_label` |
| 172 | "Andere Datei hochladen" | `tournaments.parse_invitation.upload_other_file` |
| 174 | "Manuell sortieren" | `tournaments.parse_invitation.sort_manually` |
| 181 | "Extrahierter Text anzeigen" | `tournaments.parse_invitation.show_extracted_text_short` |

## Files with Zero User-Visible Hardcoded Strings

- `_balls_goal.html.erb` — only a `number_field_tag` with no literal user-visible text
- `_search.html.erb` — 1-line partial that delegates to `_tournaments_table`
- `_party_record.html.erb` — only dynamic content (league team names, party game names)

## False Positives Skipped

| File:Line | Text | Reason |
|-----------|------|--------|
| `tournament_monitor.html.erb:31, 47-54` | `<!--` and `<%#` comments | ERB/HTML comments, not user-visible |
| `tournament_monitor.html.erb:84, 87` | `"Small Billard" → "kleiner Tisch"`, `"Match Billard" → "großer Tisch"` | Ruby `.gsub` on scraped `table_kind.name`; renaming is semantic data normalization, localizing would require refactoring the gsub logic, out of scope |
| `tournament_monitor.html.erb:136, 139, 142` | `"Kick-Off Left"`, `"Player A"`, `"Player B"` (select_tag options) | English labels in form select options; they correspond to stored values, not user-readable text — would need i18n-aware options_for_select rewrite, out of scope |
| `define_participants.html.erb:47-77` | `<%- # Lade alle Rankings … %>` and similar | ERB Ruby-line comments, not user-visible |
| `_tournament_status.html.erb:50-56, 65-72, 119, 123, 147, 161-202` | `<!--` and `<%` comments + Ruby code | Code/comments, not user-visible |
| `_bracket.html.erb:89-92` | `"TBD"`, `"Freilos / Bye"` etc inside `if(nameTxt === "Freilos / Bye")` | JS client-side comparison against the string value — the string IS user-visible and localized elsewhere, but here it's a comparison operator so we leave it. If we localize the source label at line 164, we must also update line 90 to reference the same localized label — but localizing inside JS would break the comparison. **Pragmatic fix:** keep label at line 164 as DE ("Freilos / Bye") which is what the JS checks; then add the same text as the default value of a new i18n key so DE/EN UI both show the same text. For EN we accept the DE label as fallback. Alternative: introduce a `data-bye-label` attribute. Keep DE-only for this one narrow exception — document in SUMMARY. |
| `_bracket.html.erb:70-104` | Inline `<script>` JS logic | JS logic, not user-visible text (except the `Freilos / Bye` / `Sieger` / `Verlierer` strings handled above) |
| `compare_seedings.html.erb:170-354` | Inline `<script>` `console.warn`, `console.error`, `alert` | `console.*` is developer-facing (browser devtools), out of scope. `alert(...)` is user-facing but localizing JS strings requires a data-attribute indirection that's out of scope for a pure ERB/YAML pass. Flag in SUMMARY as deferred. |
| `_show.html.erb:90-129` | Inline `<script>` JS logic | JS logic, not user-visible |
| `_show.html.erb:164` | `"Kick-Off Player"` | English fallback literal, not German — leave as-is |
| `finalize_modus.html.erb:87` | `plan.name` interpolation inside a sentence | Dynamic data interpolation, the sentence is already parametrized |
| `show.html.erb:155` | `game.data["Ergebnis"]`, `game.data["Punkte"]` | Ruby hash keys from scraped data, not user-visible text |
| `show.html.erb:158` | `%w{Heim Gast}` | Ruby symbols compared against hash keys, not user-visible text |
| `index.html.erb:24` | `t('tournament.index.tournaments')` | Existing (stale) i18n key — different namespace (`tournament.` singular vs `tournaments.` plural), out of scope for I18N-02 |

## Proposed New Key Tree (DE + EN)

### de.yml additions under `tournaments:`

```yaml
    monitor:
      all_rankings_label: "💡 Alle Rankings:"
      back_to_mode_selection: Zurück zur Modus-Auswahl
      bracket_bye: Freilos / Bye
      bracket_final_round: 👑 Finalrunde
      bracket_loser_of: Verlierer %{src}
      bracket_loser_round: 💥 Verliererrunde
      bracket_tree: 🏆 Turnierbaum
      bracket_winner_of: Sieger %{src}
      bracket_winner_round: 🏆 Gewinnerrunde
      club: Club
      current_games: Aktuelle Spiele
      current_phase: Aktuelle Phase
      current_rankings: Aktuelle Platzierungen
      game_running: ▶️ Läuft
      games_count: "%{finished} / %{total} Spiele"
      games_progress: Spiele-Fortschritt
      group_number: Gruppe %{n}
      group_short: "Gr. %{n}"
      groups_heading: Gruppen
      handicap_balls_goal: Vorgabe (Ballziel)
      no_active_games: Keine aktiven Spiele
      no_group_assignment: Keine Gruppenzuordnung
      no_groups: Keine Gruppenbildung verfügbar
      no_players: Keine Spieler
      open_tournament_monitor: 🎮 Tournament Monitor öffnen
      player: Spieler
      position_short: Pos.
      ranking: Ranking
      region_ranking_link: "%{org} Rangliste %{discipline}"
      round_label: Runde %{round}
      seeding_heading: 📋 Setzliste
      show_scoreboards: 📺 Scoreboards anzeigen (read-only)
      status_heading: "📊 Turnier-Status:"
      table_assignment_heading: Zuordnung der Tische
      table_prefix: "Tisch"
      test_update_button: 🔄 Test Update
      tournament_parameters_heading: Turnier Parameter
    show:
      admin_heading: 🔧 Spielleiter-Informationen
      close: Schließen
      edit_button: Bearbeiten
      edit_participants_button: 📝 Teilnehmerliste bearbeiten
      edit_participants_button_admin: ✏️ Teilnehmer bearbeiten
      edit_participants_title: Teilnehmer hinzufügen, bearbeiten oder entfernen
      extracted_mode_label: "Extrahierter Turniermodus:"
      file_label: "Datei:"
      handicap_short: Vorgabe
      last_sync: "Letzter Abgleich:"
      more_players: "... und %{count} weitere Spieler"
      no_invitation_uploaded: ⚠️ Keine Einladung hochgeladen
      parsed_invitation_heading: 📄 Geparste Einladung
      player: Spieler
      position_fallback: Position %{pos}
      position_short: Pos.
      quick_links_heading: 🔗 Schnellzugriff
      readonly_body_html: "Dieses Turnier hat bereits <strong>Ergebnisse aus der ClubCloud</strong> und kann nicht mehr bearbeitet werden. Die ClubCloud ist die führende Datenquelle für abgeschlossene Turniere."
      readonly_heading: Turnier ist schreibgeschützt
      review_invitation_button: 📄 Einladung prüfen
      seeding_heading: 📋 Setzliste
      show_extracted_groups: Extrahierte Gruppenbildung anzeigen
      show_tournament_data: Turnierdaten anzeigen
      tournament_data_modal_title: "📊 Turnier-Daten:"
      tournament_monitor_button: 🎮 Tournament Monitor
      reset_tournament_modal:
        body: "Achtung: Alle lokalen Setzlisten, Spiele und Ergebnisse dieses Turniers gehen verloren."
        confirm: Ja, zurücksetzen
        games_line: "Gespielte Spiele:"
        state_line: "Aktueller Status:"
        title: Turnier-Monitor zurücksetzen
      force_reset_tournament_modal:
        body: "DATENVERLUST: Alle lokalen Setzlisten, laufenden Spiele, Ergebnisse und der Turnierstand gehen unwiderruflich verloren."
        confirm: Ja, zwangsweise zurücksetzen
        title: Turnier-Monitor zwangsweise zurücksetzen
    index:
      api_server_readonly_body_html: "Dies ist der zentrale API Server. Turniermanagement (Erstellen, Bearbeiten, Durchführen) ist nur auf <strong>lokalen Servern</strong> möglich. Hier können Sie nur Turniere ansehen und als Datenquelle für lokale Server verwenden."
      api_server_readonly_heading: API Server - Nur-Lese-Modus
      new_tournament_button: Neues Turnier
    form:
      clubcloud_url: ClubCloud URL
      imported_tournament_note: Importiertes Turnier - Bearbeitung eingeschränkt
      local_config_label: Lokale Konfiguration
      save_tournament: Turnier speichern
    edit:
      cancel: Abbrechen
    new:
      cancel: Abbrechen
    new_team:
      add_team_button: Team zur Setzliste hinzufügen
      heading: Neues TurnierTeam
      player_ba_id_label: "Player%{n} BaID:"
      player_ba_id_placeholder: "player %{n} BA ID"
    wizard_step:
      help_summary: 💡 Was macht dieser Schritt?
      pending_default: Dieser Schritt ist noch offen
      pending_hint: Erst verfügbar nach vorherigem Schritt
    compare_seedings:
      alt_clubcloud_body_html: "Falls keine Einladung vorliegt, können Sie mit der <strong>Meldeliste von ClubCloud</strong> direkt zu Schritt 3 (Teilnehmerliste bearbeiten) weitermachen."
      alt_clubcloud_heading: "📊 Alternative: Mit ClubCloud-Meldeliste weitermachen"
      alt_manual_heading: "✏️ Alternative: Manuell sortieren"
      auto_extract_note: Die Setzliste wird automatisch extrahiert!
      back: ← Zurück
      choose_file: Datei auswählen
      clubcloud_list_heading: "ClubCloud-Meldeliste (%{count} Spieler):"
      confirm_use_clubcloud_as_is: "ClubCloud-Reihenfolge exakt wie sie ist als Setzliste übernehmen und zu Schritt 3 weitergehen?"
      confirm_use_clubcloud_by_ranking: "Meldeliste von ClubCloud als Teilnehmerliste übernehmen und nach Rangliste sortieren?\n\nDie Spieler werden automatisch nach der Carambus-Rangliste sortiert."
      drop_file_here: Datei hier ablegen
      file_types: PDF oder Screenshot (PNG, JPG)
      heading: "Setzliste übernehmen:"
      how_it_works: "💡 So funktioniert's:"
      invitation_present: "✅ Einladung vorhanden:"
      load_clubcloud_hint: Bitte zuerst in Schritt 1 die Meldeliste von ClubCloud laden.
      manual_sort_body: "Oder sortieren Sie die Liste automatisch nach aktueller Rangliste:"
      no_clubcloud_data: "⚠️ Keine ClubCloud-Daten verfügbar."
      open_clubcloud: 🔗 ClubCloud öffnen (zum Vergleich)
      option_as_clubcloud_html: "<strong>Wie in ClubCloud:</strong> Übernimmt die Reihenfolge exakt wie sie in ClubCloud steht"
      option_by_ranking_html: "<strong>Nach Rangliste sortiert:</strong> Carambus sortiert automatisch nach der aktuellen Rangliste (empfohlen für Landesturniere)"
      or_drag_file: 💡 Oder Datei hierher ziehen (z.B. aus E-Mail)
      processing: Wird verarbeitet...
      reparse: Erneut parsen
      sort_by_ranking: Nach Rangliste sortieren
      step_1_html: "Laden Sie die <strong>offizielle Einladung</strong> (PDF oder Screenshot) hoch"
      step_2_html: "Carambus extrahiert automatisch die <strong>Setzliste</strong>"
      step_3: Sie prüfen und bestätigen die erkannten Spieler
      step_4: Die Reihenfolge wird übernommen
      supported_formats: "Unterstützte Formate: PDF, PNG, JPEG"
      two_options_label: "Zwei Möglichkeiten:"
      upload_and_parse: Hochladen & automatisch parsen
      upload_heading: 📧 Offizielle Einladung hochladen
      use_clubcloud_as_is: Diese Reihenfolge übernehmen (wie in ClubCloud)
      use_clubcloud_by_ranking: "→ Mit Meldeliste zu Schritt 3 (nach Rangliste sortiert)"
    define_participants:
      add_player_button: Spieler hinzufügen
      add_player_by_dbu_html: "Spieler mit <strong>DBU-Nummer</strong> hinzufügen (wird automatisch zur Liste hinzugefügt):"
      all_changes_saved_html: "✓ Alle Änderungen (Checkboxen, Vorgaben) werden <strong>sofort gespeichert</strong>"
      already_bottom: Bereits unten
      already_top: Bereits oben
      auto_suggested_label: "🤖 Automatisch vorgeschlagen:"
      back: zurück
      back_to_wizard: ← Zurück zum Wizard
      can_return_anytime: ✓ Sie können jederzeit hierher zurückkehren um weitere Anpassungen vorzunehmen
      col_handicap: Vorgabe (Pkt)
      col_name: Name
      col_new_pos: Neue Pos.
      col_order: Reihenfolge
      col_participant: Teilnehmer
      col_participation: Teilnahme
      col_points_goal: Punktziel
      col_points_or_ranking: Punktziel bzw. Ranking
      col_pos: Pos.
      col_ranking: Ranking
      col_team: Team
      dbu_nr_hint: "💡 Mit DBU-Nummer: Spieler eindeutig identifiziert (empfohlen) | Mehrere durch Komma getrennt möglich"
      dbu_nr_placeholder: "DBU-Nummer(n) eingeben (z.B. 12345 oder 12345, 67890, 11111)"
      differs_from_nbv: ⚠️ Weicht von NBV ab
      edit_heading: 📝 Teilnehmerliste bearbeiten
      from_invitation_label: "📄 Aus Einladung:"
      groups_auto_update_info: 💡 Die Gruppenzuordnungen ändern sich automatisch, wenn Sie die Teilnehmerliste bearbeiten.
      heading: Teilnehmerliste
      important_label: 💡 Wichtig
      incl_round_robin: "(inkl. \"Jeder gegen Jeden\")"
      late_registration_heading: ➕ Kurzfristiger Nachmelder?
      move_down: Nach unten
      move_up: Nach oben
      nbv_conform: ✓ NBV-konform
      new_team: Neues Team
      no_dbu_nr_question: ⚠️ Spieler ohne DBU-Nummer? (Klicken für Info)
      no_dbu_nr_reason_html: "<strong>Grund:</strong> In der ClubCloud können nur Spieler mit DBU-Nummer eingetragen werden."
      no_dbu_nr_title: Spieler ohne DBU-Nummer können nicht nachgemeldet werden.
      no_plan_for_count: "ℹ️ Für %{count} Teilnehmer ist aktuell kein Turnierplan für %{discipline} hinterlegt."
      possible_plans_heading: 📊 Mögliche Turnierpläne für %{count} Teilnehmer
      rank_title: "Rang %{rank} in %{discipline} (%{region})"
      reduced_mode_info_html: "ℹ️ Alternative Pläne können ggf. mit reduziertem Ausspielziel arbeiten (z.B. 25% weniger Aufnahmen/Punkte), um die Gesamtdauer zu verkürzen. Rundenzahl und durchschnittliche Spieldauer beachten."
      round_robin_tag: 🎯 Jeder gegen Jeden
      rounds:
        one: "%{count} Runde"
        other: "%{count} Runden"
      searching: Wird gesucht...
      show_alternatives_same_discipline: "🔄 %{count} Alternative Pläne (%{discipline}) anzeigen"
      show_other_plans: "⚙️ %{count} Weitere Pläne anzeigen"
      solution_add_guest: "Oder: Turnierleiter trägt Spieler als Gast ein (kontaktieren Sie den Landessportwart)"
      solution_apply_dbu_nr: Spieler muss DBU-Nummer beantragen
      solution_label: "Lösung:"
      sort_by_handicap: 🎯 Nach Vorgabeziel sortieren
      sort_by_handicap_title: Sortiert nach Vorgabeziel (höheres Punktziel = stärker)
      sort_by_ranking: 📊 Nach Ranking sortieren
      sort_by_ranking_title: Sortiert nach aktuellem Carambus-Ranking
      sort_heading: 🔄 Teilnehmerliste sortieren
      sort_info: 💡 Die Sortierung passt die Positionen automatisch an. Änderungen werden sofort gespeichert.
      team_list_heading: Teamliste
      tip_auto_save: ✓ Änderungen werden sofort gespeichert
      tip_check_boxes_html: "✓ Haken setzen/entfernen = Spieler als Teilnehmer markieren/streichen"
      tip_handicap_html: "✓ Vorgaben (Punktziel) anpassen falls nötig"
      tip_late_registration: ➕ Kurzfristig nachmelden? Checkbox aktivieren!
      tip_position_html: "🔢 <strong>Setzreihenfolge ändern:</strong> Neue Position direkt eingeben ODER Pfeile ⬆️⬇️ klicken"
      tip_ranking_html: "📊 <strong>Ranking-Spalte:</strong> Zeigt aktuelles Carambus-Ranking für %{discipline} (letzten 2-3 Saisons), klickbar zur Rangliste"
      when_done_html: "⏭️ Wenn Sie fertig sind: Gehen Sie zurück zum Wizard und klicken Sie <strong>Schritt 4: Teilnehmerliste finalisieren</strong>"
    finalize_modus:
      calculated_likely_wrong: "🤖 Berechnet (vermutlich falsch):"
      close: Schließen
      current_workaround: "Aktuell: Verwenden Sie '🔄 Neu berechnen' oder passen Sie die Setzliste in Schritt 3 an."
      extracted_info: Diese Informationen wurden automatisch aus der hochgeladenen Einladung extrahiert.
      from_invitation_nbv: "📄 Aus Einladung (NBV-Vorgabe):"
      groups_auto_calculated_html: "<strong>🤖 Gruppenbildung automatisch berechnet (NBV-konform)</strong><br>Die Zuordnung wurde nach NBV-Standard-Algorithmus berechnet."
      groups_from_invitation_html: "<strong>✅ Gruppenbildung aus Einladung übernommen</strong><br>Die Zuordnung wurde automatisch extrahiert und ist <strong>identisch</strong> mit dem NBV-Standard-Algorithmus."
      in_development_html: "<strong>Hinweis:</strong> Diese Funktion ist in Entwicklung."
      invitation_specs_heading: "📄 Vorgaben aus Einladung:"
      landessportwart_quote: "\"Auch der Landessportwart irrt manchmal\" 😊"
      manual_correct_hint: Sie können die Gruppenzuordnung manuell korrigieren.
      manually_adjust: ✏️ Manuell anpassen
      recalculate: 🔄 Neu berechnen
      recalculate_confirm: Extrahierte Gruppenbildung verwerfen und neu berechnen?
      recalculate_title: Verwirft Einladungs-Zuordnung und berechnet mit NBV-Algorithmus
      show_comparison: 🔍 Vergleich anzeigen
      use_algorithm: 🔄 Algorithmus verwenden (Risiko)
      use_algorithm_confirm: "ACHTUNG: Der Algorithmus könnte falsch sein!\n\nBesser die Einladung verwenden."
      use_algorithm_title: Verwendet berechneten Algorithmus (könnte von NBV-Vorgaben abweichen)
      use_invitation: ✅ Einladung verwenden (empfohlen)
      use_invitation_confirm: "Gruppenbildung aus Einladung verwenden?\n\nDiese ist vom Landessportwart vorgegeben."
      use_invitation_title: Verwendet die offizielle Gruppenbildung aus der Einladung
      warning_nbv_differs: "⚠️  WARNUNG: Abweichung vom NBV-Standard erkannt!"
      warning_nbv_differs_body_html: "Die Gruppenbildung in der Einladung <strong>unterscheidet sich</strong> vom berechneten Algorithmus.<br><strong>Grund:</strong> Der NBV-Algorithmus für %{plan} ist möglicherweise noch nicht korrekt implementiert."
    parse_invitation:
      alternatives_label: "Alternativen:"
      apply_seeding: Setzliste übernehmen
      apply_seeding_confirm: "Setzliste mit %{count} Spielern übernehmen?"
      back: ← Zurück
      bonus_groups_html: "<strong>Bonus:</strong> Die Gruppenzuordnung wurde ebenfalls erkannt und wird automatisch verwendet."
      cancel: Abbrechen
      col_detected_name: Erkannter Name
      col_handicap: Vorgabe (Pkt)
      col_matched_player: Zugeordneter Spieler
      col_position: Position
      col_status: Status
      confidence_high: ✓ Sicher
      confidence_low: ⚠️ Vermutung
      detected_players_heading: "Erkannte Spieler (%{rate}% Übereinstimmung)"
      extracted_groups_heading: 🎯 Extrahierte Gruppenbildung
      extraction_failed: ❌ Automatische Extraktion fehlgeschlagen
      group_number: Gruppe %{group_no}
      groups_extracted: + Gruppenbildung extrahiert 🎯
      heading: Setzliste automatisch erkannt
      player_fallback: Spieler %{pos}
      players_detected: "✅ %{count} Spieler automatisch erkannt!"
      please_review: Bitte prüfen Sie die erkannten Spieler und bestätigen Sie die Übernahme.
      points_suffix: "%{balls_goal} Pkt"
      seeding_extracted: Die Setzliste wurde aus der Einladung extrahiert.
      show_extracted_text: 🔍 Extrahierter Text anzeigen (Debugging)
      show_extracted_text_short: Extrahierter Text anzeigen
      sort_manually: Manuell sortieren
      assignment_used_in_step5: 💡 Diese Zuordnung wird in Schritt 5 (Turniermodus) verwendet und überschreibt den Standard-Algorithmus.
      unmatched_heading: "⚠️ Nicht zugeordnet (%{count}):"
      unmatched_hint: Diese Spieler sind nicht in der Meldeliste. Bitte fügen Sie sie manuell hinzu.
      unmatched_item: "%{name} (Position %{position})"
      upload_other_file: Andere Datei hochladen
```

### en.yml additions under `tournaments:` (parallel structure with EN values)

Same key tree as above; EN translations provided per CONTEXT.md §D-14 "DE is authoritative, EN is a direct Claude-written translation — short UI labels, no AI service."

Representative translations (full tree will mirror the DE structure exactly):

- `monitor.current_phase` → `Current phase`
- `monitor.current_games` → `Current games`
- `monitor.tournament_parameters_heading` → `Tournament parameters`
- `show.readonly_heading` → `Tournament is read-only`
- `show.edit_participants_button` → `📝 Edit participant list`
- `index.api_server_readonly_heading` → `API Server — Read-Only Mode`
- `index.new_tournament_button` → `New Tournament`
- `form.save_tournament` → `Save Tournament`
- `new_team.heading` → `New Tournament Team`
- `compare_seedings.heading` → `Apply seeding list:`
- `define_participants.heading` → `Participants list`
- `finalize_modus.recalculate` → `🔄 Recalculate`
- `parse_invitation.heading` → `Seeding list auto-detected`

Full EN tree lands in `config/locales/en.yml` in Task 2 alongside the DE tree.

## Deferred / Out of Scope

1. **JavaScript inline strings** (`alert`, `console.*`, `preventDefaults` error handlers in `compare_seedings.html.erb`) — localizing these requires refactoring to pass strings via `data-*` attributes from ERB to Stimulus controllers. This is a larger cross-cutting change and does NOT belong to a pure ERB/YAML i18n sweep. Documented here as a follow-up.
2. **`Small Billard` / `Match Billard` gsub** in `tournament_monitor.html.erb:84,87` — semantic data normalization of scraped table kind names. Localization would require refactoring to check discipline/table-kind IDs instead of string substitution.
3. **`_bracket.html.erb:90` JS comparison against "Freilos / Bye"** — the literal is referenced by both the ERB render (line 164) and the JS (line 90). Localizing would break the JS comparison. Keeping both as the DE literal is pragmatic; EN users will also see "Freilos / Bye". Flagged in SUMMARY as a cross-namespace compromise.
4. **Existing stale key `t('tournament.index.tournaments')`** in `index.html.erb:24` — it's a typo-level issue (singular `tournament.` vs plural `tournaments.`) from earlier scaffolding and is a separate bug from I18N-02. Not fixing it in this plan keeps the scope tight.

## Scope Note (CONTEXT.md D-11 Exclusion Confirmed)

`app/views/tournaments/_wizard_steps_v2.html.erb` is **NOT** part of this audit. Phase 36B fully i18n'd it, and Plan 38-01 touched it separately for the G-01 dark-mode fix. Plan 38-02 does not modify it.
