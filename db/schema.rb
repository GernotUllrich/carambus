# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2025_07_03_154911) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", precision: nil, null: false
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "branch_ccs", force: :cascade do |t|
    t.integer "cc_id"
    t.string "context"
    t.integer "region_cc_id"
    t.integer "discipline_id"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["region_cc_id", "cc_id", "context"], name: "index_branch_ccs_on_region_cc_id_and_cc_id_and_context", unique: true
  end

  create_table "calendar_events", force: :cascade do |t|
    t.string "summary"
    t.boolean "recurring"
    t.integer "location_id"
    t.datetime "event_start"
    t.datetime "event_end"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "category_ccs", force: :cascade do |t|
    t.string "context"
    t.integer "max_age"
    t.integer "min_age"
    t.string "name"
    t.string "sex"
    t.string "status"
    t.integer "cc_id"
    t.integer "branch_cc_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "championship_type_ccs", force: :cascade do |t|
    t.integer "cc_id"
    t.string "name"
    t.string "shortname"
    t.string "context"
    t.integer "branch_cc_id"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "club_locations", force: :cascade do |t|
    t.integer "club_id"
    t.integer "location_id"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "region_id"
    t.boolean "global_context", default: false
    t.index ["global_context"], name: "index_club_locations_on_global_context"
    t.index ["region_id"], name: "index_club_locations_on_region_id"
  end

  create_table "clubs", force: :cascade do |t|
    t.integer "ba_id"
    t.integer "region_id"
    t.string "name"
    t.string "shortname"
    t.text "address"
    t.string "homepage"
    t.string "email"
    t.text "priceinfo"
    t.string "logo"
    t.string "status"
    t.string "founded"
    t.string "dbu_entry"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "cc_id"
    t.integer "dbu_nr"
    t.text "synonyms"
    t.string "source_url"
    t.datetime "sync_date"
    t.boolean "global_context", default: false
    t.index ["ba_id"], name: "index_clubs_on_ba_id", unique: true
    t.index ["ba_id"], name: "index_clubs_on_foreign_keys", unique: true
    t.index ["global_context"], name: "index_clubs_on_global_context"
  end

  create_table "competition_ccs", force: :cascade do |t|
    t.integer "cc_id"
    t.string "name"
    t.string "context"
    t.integer "branch_cc_id"
    t.integer "discipline_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_cc_id", "cc_id", "context"], name: "index_competition_ccs_on_branch_cc_id_and_cc_id_and_context", unique: true
  end

  create_table "countries", force: :cascade do |t|
    t.string "name"
    t.string "code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_countries_on_code", unique: true
  end

  create_table "debug_infos", force: :cascade do |t|
    t.string "info"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "discipline_ccs", force: :cascade do |t|
    t.integer "cc_id"
    t.string "name"
    t.integer "discipline_id"
    t.integer "branch_cc_id"
    t.string "context"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "discipline_phases", force: :cascade do |t|
    t.string "name"
    t.integer "discipline_id"
    t.integer "parent_discipline_id"
    t.integer "position"
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "discipline_tournament_plans", force: :cascade do |t|
    t.integer "discipline_id"
    t.integer "tournament_plan_id"
    t.integer "points"
    t.integer "innings"
    t.integer "players"
    t.string "player_class"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "disciplines", force: :cascade do |t|
    t.string "name"
    t.integer "super_discipline_id"
    t.integer "table_kind_id"
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type"
    t.text "synonyms"
    t.integer "team_size"
    t.index ["name", "table_kind_id"], name: "index_disciplines_on_foreign_keys", unique: true
    t.index ["name", "table_kind_id"], name: "index_disciplines_on_name_and_table_kind_id", unique: true
  end

  create_table "game_participations", force: :cascade do |t|
    t.integer "game_id"
    t.integer "player_id"
    t.string "role"
    t.text "data"
    t.integer "points"
    t.integer "result"
    t.integer "innings"
    t.float "gd"
    t.integer "hs"
    t.string "gname"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "sets"
    t.integer "region_id"
    t.boolean "global_context", default: false
    t.index ["game_id", "player_id", "role"], name: "index_game_participations_on_foreign_keys", unique: true
    t.index ["global_context"], name: "index_game_participations_on_global_context"
    t.index ["region_id"], name: "index_game_participations_on_region_id"
  end

  create_table "game_plan_ccs", force: :cascade do |t|
    t.integer "cc_id"
    t.string "name"
    t.text "data"
    t.integer "branch_cc_id"
    t.integer "discipline_id"
    t.integer "mp_won"
    t.integer "mb_draw"
    t.integer "mp_lost"
    t.integer "znp"
    t.integer "vorgabe"
    t.boolean "plausi"
    t.string "pez_partie"
    t.string "bez_brett"
    t.integer "rang_partie"
    t.integer "rang_mgd"
    t.integer "rang_kegel"
    t.integer "ersatzspieler_regel"
    t.integer "row_type_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "game_plan_row_ccs", force: :cascade do |t|
    t.integer "cc_id"
    t.integer "game_plan_id"
    t.integer "discipline_id"
    t.integer "home_brett"
    t.integer "visitor_brett"
    t.integer "sets"
    t.integer "score"
    t.integer "ppg"
    t.integer "ppu"
    t.integer "ppv"
    t.integer "mpg"
    t.integer "pmv"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "game_plans", force: :cascade do |t|
    t.string "footprint"
    t.text "data"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "region_id"
    t.boolean "global_context", default: false
    t.index ["global_context"], name: "index_game_plans_on_global_context"
    t.index ["region_id"], name: "index_game_plans_on_region_id"
  end

  create_table "games", force: :cascade do |t|
    t.integer "tournament_id"
    t.text "roles"
    t.text "data"
    t.integer "seqno"
    t.string "gname"
    t.integer "group_no"
    t.integer "table_no"
    t.integer "round_no"
    t.datetime "started_at", precision: nil
    t.datetime "ended_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "tournament_type"
    t.integer "region_id"
    t.boolean "global_context", default: false
    t.index ["global_context"], name: "index_games_on_global_context"
    t.index ["region_id"], name: "index_games_on_region_id"
    t.index ["tournament_id", "gname", "seqno"], name: "index_games_on_tournament_id_and_gname_and_seqno", unique: true
  end

  create_table "group_ccs", force: :cascade do |t|
    t.integer "cc_id"
    t.string "name"
    t.string "context"
    t.string "display"
    t.string "status"
    t.integer "branch_cc_id"
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "innings", force: :cascade do |t|
    t.integer "game_id"
    t.integer "sequence_number"
    t.string "player_a_count"
    t.string "player_b_count"
    t.string "player_c_count"
    t.string "player_d_count"
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_id", "sequence_number"], name: "index_innings_on_foreign_keys", unique: true
    t.index ["game_id", "sequence_number"], name: "index_innings_on_game_id_and_sequence_number", unique: true
  end

  create_table "ion_contents", force: :cascade do |t|
    t.integer "page_id"
    t.string "title"
    t.text "html"
    t.string "level"
    t.datetime "scraped_at", precision: nil
    t.datetime "deep_scraped_at", precision: nil
    t.integer "ion_content_id"
    t.text "data"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "hidden", default: false, null: false
  end

  create_table "ion_modules", force: :cascade do |t|
    t.string "module_id"
    t.integer "ion_content_id"
    t.string "module_type"
    t.integer "position"
    t.text "html"
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "kvc_settings", force: :cascade do |t|
    t.string "key"
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "league_ccs", force: :cascade do |t|
    t.integer "cc_id"
    t.string "name"
    t.integer "season_cc_id"
    t.integer "league_id"
    t.string "context"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "shortname"
    t.string "status"
    t.string "report_form"
    t.string "report_form_data"
    t.integer "cc_id2"
    t.integer "game_plan_cc_id"
  end

  create_table "league_team_ccs", force: :cascade do |t|
    t.integer "cc_id"
    t.string "name"
    t.string "shortname"
    t.integer "league_cc_id"
    t.integer "league_team_id"
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "league_teams", force: :cascade do |t|
    t.string "name"
    t.string "shortname"
    t.integer "league_id"
    t.integer "ba_id"
    t.integer "club_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "source_url"
    t.datetime "sync_date"
    t.integer "cc_id"
    t.text "data"
    t.integer "region_id"
    t.boolean "global_context", default: false
    t.index ["global_context"], name: "index_league_teams_on_global_context"
    t.index ["region_id"], name: "index_league_teams_on_region_id"
  end

  create_table "leagues", force: :cascade do |t|
    t.string "name"
    t.date "registration_until"
    t.string "organizer_type"
    t.integer "organizer_id"
    t.integer "season_id"
    t.integer "ba_id"
    t.integer "ba_id2"
    t.integer "discipline_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "staffel_text"
    t.integer "cc_id"
    t.string "shortname"
    t.string "type"
    t.string "source_url"
    t.datetime "sync_date"
    t.integer "cc_id2"
    t.integer "game_plan_id"
    t.text "game_parameters"
    t.boolean "game_plan_locked", default: false, null: false
    t.integer "region_id"
    t.boolean "global_context", default: false
    t.index ["ba_id", "ba_id2"], name: "index_leagues_on_ba_id_and_ba_id2", unique: true
    t.index ["cc_id", "cc_id2", "organizer_id", "organizer_type"], name: "index_leagues_on_cc_ids_organizer_unique", unique: true, where: "((cc_id IS NOT NULL) AND ((organizer_type)::text = 'Region'::text))"
    t.index ["global_context"], name: "index_leagues_on_global_context"
    t.index ["region_id"], name: "index_leagues_on_region_id"
  end

  create_table "location_synonyms", force: :cascade do |t|
    t.string "synonym"
    t.integer "location_id"
  end

  create_table "locations", force: :cascade do |t|
    t.text "address"
    t.text "data"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "organizer_type"
    t.integer "organizer_id"
    t.string "md5", null: false
    t.text "synonyms"
    t.string "source_url"
    t.datetime "sync_date"
    t.integer "cc_id"
    t.integer "dbu_nr"
    t.integer "club_id"
    t.integer "region_id"
    t.boolean "global_context", default: false
    t.index ["global_context"], name: "index_locations_on_global_context"
    t.index ["md5"], name: "index_locations_on_md5", unique: true
    t.index ["region_id"], name: "index_locations_on_region_id"
  end

  create_table "meta_maps", force: :cascade do |t|
    t.string "class_ba"
    t.string "class_cc"
    t.string "ba_base_url"
    t.string "cc_base_url"
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "pages", force: :cascade do |t|
    t.string "title", null: false
    t.text "content"
    t.text "summary"
    t.integer "super_page_id"
    t.integer "position"
    t.string "author_type"
    t.integer "author_id"
    t.string "content_type", default: "markdown"
    t.string "status", default: "draft"
    t.datetime "published_at"
    t.jsonb "tags", default: []
    t.jsonb "metadata", default: {}
    t.jsonb "crud_minimum_roles", default: {"read"=>"player", "create"=>"system_admin", "delete"=>"system_admin", "update"=>"system_admin"}
    t.string "version", default: "0.1"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_translated_at"
    t.string "slug", default: "", null: false
    t.index ["author_type", "author_id"], name: "index_pages_on_author_type_and_author_id"
    t.index ["status"], name: "index_pages_on_status"
    t.index ["super_page_id"], name: "index_pages_on_super_page_id"
    t.index ["tags"], name: "index_pages_on_tags", using: :gin
  end

  create_table "parties", force: :cascade do |t|
    t.datetime "date", precision: nil
    t.integer "league_id"
    t.text "remarks"
    t.integer "league_team_a_id"
    t.integer "league_team_b_id"
    t.integer "ba_id"
    t.integer "day_seqno"
    t.text "data"
    t.integer "host_league_team_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "no_show_team_id"
    t.string "section"
    t.integer "cc_id"
    t.date "register_at"
    t.string "group"
    t.string "round"
    t.integer "status"
    t.datetime "time", precision: nil
    t.string "source_url"
    t.datetime "sync_date"
    t.integer "location_id"
    t.datetime "reported_at"
    t.integer "reported_by_player_id"
    t.string "reported_by"
    t.integer "party_no"
    t.boolean "manual_assignment"
    t.boolean "continuous_placements", default: false, null: false
    t.integer "timeout", default: 0, null: false
    t.integer "timeouts"
    t.integer "time_out_stoke_preparation_sec", default: 45
    t.integer "time_out_warm_up_first_min", default: 5
    t.integer "time_out_warm_up_follow_up_min", default: 3
    t.integer "sets_to_play", default: 1, null: false
    t.integer "sets_to_win", default: 1, null: false
    t.integer "team_size", default: 1, null: false
    t.string "fixed_display_left"
    t.boolean "allow_follow_up", default: true, null: false
    t.boolean "color_remains_with_set", default: true, null: false
    t.string "kickoff_switches_with"
    t.integer "region_id"
    t.boolean "global_context", default: false
    t.string "round_name"
    t.index ["global_context"], name: "index_parties_on_global_context"
    t.index ["league_id", "day_seqno", "round_name", "league_team_a_id", "league_team_b_id"], name: "index_parties_on_league_and_teams", unique: true
    t.index ["region_id"], name: "index_parties_on_region_id"
  end

  create_table "party_ccs", force: :cascade do |t|
    t.integer "cc_id"
    t.integer "league_cc_id"
    t.integer "party_id"
    t.integer "league_team_a_cc_id"
    t.integer "league_team_b_cc_id"
    t.integer "league_team_host_cc_id"
    t.integer "day_seqno"
    t.text "remarks"
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "register_at"
    t.string "group"
    t.string "round"
    t.integer "status"
    t.datetime "time", precision: nil
    t.integer "match_id"
  end

  create_table "party_game_ccs", force: :cascade do |t|
    t.integer "cc_id"
    t.integer "seqno"
    t.integer "player_a_id"
    t.integer "player_b_id"
    t.text "data"
    t.string "name"
    t.integer "discipline_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "party_cc_id"
  end

  create_table "party_games", force: :cascade do |t|
    t.integer "party_id"
    t.integer "seqno"
    t.integer "player_a_id"
    t.integer "player_b_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "data"
    t.string "name"
    t.integer "discipline_id"
    t.integer "region_id"
    t.boolean "global_context", default: false
    t.index ["global_context"], name: "index_party_games_on_global_context"
    t.index ["region_id"], name: "index_party_games_on_region_id"
  end

  create_table "party_monitors", force: :cascade do |t|
    t.integer "party_id"
    t.string "state"
    t.text "data"
    t.datetime "started_at"
    t.datetime "ended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "timeout", default: 0, null: false
    t.integer "timeouts"
    t.integer "time_out_stoke_preparation_sec", default: 45
    t.integer "time_out_warm_up_first_min", default: 5
    t.integer "time_out_warm_up_follow_up_min", default: 3
    t.integer "sets_to_play", default: 1, null: false
    t.integer "sets_to_win", default: 1, null: false
    t.integer "team_size", default: 1, null: false
    t.string "fixed_display_left"
    t.boolean "allow_follow_up", default: true, null: false
    t.boolean "color_remains_with_set", default: true, null: false
    t.string "kickoff_switches_with"
  end

  create_table "player_classes", force: :cascade do |t|
    t.integer "discipline_id"
    t.string "shortname"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "player_rankings", force: :cascade do |t|
    t.integer "player_id"
    t.integer "region_id"
    t.integer "season_id"
    t.string "org_level"
    t.integer "discipline_id"
    t.integer "innings"
    t.string "status"
    t.integer "points"
    t.float "gd"
    t.integer "hs"
    t.float "bed"
    t.float "btg"
    t.integer "player_class_id"
    t.integer "p_player_class_id"
    t.integer "pp_player_class_id"
    t.float "p_gd"
    t.float "pp_gd"
    t.integer "tournament_player_class_id"
    t.integer "rank"
    t.text "remarks"
    t.integer "g"
    t.integer "v"
    t.float "quote"
    t.integer "sp_g"
    t.integer "sp_v"
    t.float "sp_quote"
    t.integer "balls"
    t.integer "sets"
    t.text "t_ids"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "global_context", default: false
    t.index ["global_context"], name: "index_player_rankings_on_global_context"
  end

  create_table "players", force: :cascade do |t|
    t.integer "ba_id"
    t.integer "club_id"
    t.string "lastname"
    t.string "firstname"
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "guest", default: false, null: false
    t.string "nickname"
    t.string "type"
    t.text "data"
    t.integer "tournament_id"
    t.integer "cc_id"
    t.integer "dbu_nr"
    t.integer "dbu_pass_nr"
    t.string "fl_name"
    t.string "source_url"
    t.datetime "sync_date"
    t.integer "nrw_nr"
    t.string "pin4"
    t.string "logo"
    t.integer "region_id"
    t.boolean "global_context", default: false
    t.index ["ba_id"], name: "index_players_on_ba_id", unique: true
    t.index ["club_id"], name: "index_players_on_club_id"
    t.index ["global_context"], name: "index_players_on_global_context"
    t.index ["region_id"], name: "index_players_on_region_id"
  end

  create_table "region_ccs", force: :cascade do |t|
    t.integer "cc_id"
    t.string "context"
    t.integer "region_id"
    t.string "shortname"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "base_url"
    t.string "public_url"
    t.string "username"
    t.string "userpw"
    t.index ["cc_id", "context"], name: "index_region_ccs_on_cc_id_and_context", unique: true
    t.index ["context"], name: "index_region_ccs_on_context", unique: true
  end

  create_table "regions", force: :cascade do |t|
    t.string "name"
    t.string "shortname"
    t.string "logo"
    t.string "email"
    t.text "address"
    t.integer "country_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "public_cc_url_base"
    t.string "dbu_name"
    t.string "telefon"
    t.string "fax"
    t.string "website"
    t.string "opening"
    t.string "source_url"
    t.datetime "sync_date"
    t.integer "cc_id"
    t.text "scrape_data"
    t.integer "region_id"
    t.boolean "global_context", default: false
    t.index ["country_id"], name: "index_regions_on_country_id"
    t.index ["global_context"], name: "index_regions_on_global_context"
    t.index ["region_id"], name: "index_regions_on_region_id"
    t.index ["shortname"], name: "index_regions_on_shortname", unique: true
  end

  create_table "registration_ccs", force: :cascade do |t|
    t.integer "registration_list_cc_id"
    t.integer "player_id"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id", "registration_list_cc_id"], name: "index_registration_ccs_on_player_id_and_registration_list_cc_id", unique: true
  end

  create_table "registration_list_ccs", force: :cascade do |t|
    t.integer "cc_id"
    t.string "context"
    t.string "name"
    t.integer "branch_cc_id"
    t.integer "season_id"
    t.integer "discipline_id"
    t.integer "category_cc_id"
    t.datetime "deadline", precision: nil
    t.datetime "qualifying_date", precision: nil
    t.text "data"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "season_ccs", force: :cascade do |t|
    t.integer "cc_id"
    t.string "name"
    t.integer "season_id"
    t.integer "competition_cc_id"
    t.string "context"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["competition_cc_id", "cc_id", "context"], name: "index_season_ccs_on_competition_cc_id_and_cc_id_and_context", unique: true
  end

  create_table "season_participations", force: :cascade do |t|
    t.integer "player_id"
    t.integer "season_id"
    t.text "data"
    t.integer "club_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status"
    t.integer "ba_id"
    t.string "source_url"
    t.datetime "sync_date"
    t.integer "region_id"
    t.boolean "global_context", default: false
    t.index ["global_context"], name: "index_season_participations_on_global_context"
    t.index ["player_id", "club_id", "season_id"], name: "index_season_participations_on_foreign_keys", unique: true
    t.index ["region_id"], name: "index_season_participations_on_region_id"
  end

  create_table "seasons", force: :cascade do |t|
    t.integer "ba_id"
    t.string "name"
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ba_id"], name: "index_seasons_on_ba_id", unique: true
    t.index ["name"], name: "index_seasons_on_name", unique: true
  end

  create_table "seedings", force: :cascade do |t|
    t.integer "player_id"
    t.integer "tournament_id"
    t.string "ba_state"
    t.integer "position"
    t.text "data"
    t.string "state"
    t.integer "balls_goal"
    t.integer "playing_discipline_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "rank"
    t.integer "league_team_id"
    t.string "role"
    t.string "tournament_type"
    t.integer "region_id"
    t.boolean "global_context", default: false
    t.index ["global_context"], name: "index_seedings_on_global_context"
    t.index ["region_id"], name: "index_seedings_on_region_id"
  end

  create_table "settings", force: :cascade do |t|
    t.text "data"
    t.string "state"
    t.integer "region_id"
    t.integer "club_id"
    t.integer "tournament_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "slots", force: :cascade do |t|
    t.integer "dayofweek"
    t.integer "hourofday_start"
    t.integer "minuteofhour_start"
    t.integer "hourofday_end"
    t.integer "minuteofhour_end"
    t.datetime "next_start"
    t.datetime "next_end"
    t.integer "table_id"
    t.boolean "recurring"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sync_hashes", force: :cascade do |t|
    t.string "url"
    t.string "md5"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "doc"
  end

  create_table "table_kinds", force: :cascade do |t|
    t.string "name"
    t.string "short"
    t.text "measures"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "table_locals", force: :cascade do |t|
    t.string "tpl_ip_address"
    t.string "ip_address"
    t.integer "table_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "event_id"
    t.string "event_summary"
    t.string "event_creator"
    t.datetime "event_start"
    t.datetime "event_end"
    t.string "heater_on_reason"
    t.string "heater_off_reason"
    t.datetime "heater_switched_on_at"
    t.datetime "heater_switched_off_at"
    t.boolean "heater"
    t.datetime "manual_heater_on_at"
    t.datetime "manual_heater_off_at"
    t.boolean "scoreboard"
    t.datetime "scoreboard_on_at"
    t.datetime "scoreboard_off_at"
  end

  create_table "table_monitors", force: :cascade do |t|
    t.integer "tournament_monitor_id"
    t.string "state"
    t.string "name"
    t.integer "game_id"
    t.integer "next_game_id"
    t.text "data"
    t.string "ip_address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "active_timer"
    t.datetime "timer_start_at", precision: nil
    t.datetime "timer_finish_at", precision: nil
    t.datetime "timer_halt_at", precision: nil
    t.integer "nnn"
    t.string "panel_state", default: "pointer_mode", null: false
    t.string "current_element", default: "pointer_mode", null: false
    t.string "timer_job_id"
    t.string "clock_job_id"
    t.integer "copy_from"
    t.string "tournament_monitor_type"
    t.integer "prev_game_id"
    t.text "prev_data"
    t.integer "prev_tournament_monitor_id"
    t.string "prev_tournament_monitor_type"
  end

  create_table "tables", force: :cascade do |t|
    t.integer "location_id"
    t.integer "table_kind_id"
    t.string "name"
    t.text "data"
    t.string "ip_address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "table_monitor_id"
    t.integer "tpl_ip_address"
    t.string "event_id"
    t.string "event_summary"
    t.string "event_creator"
    t.datetime "event_start"
    t.datetime "event_end"
    t.string "heater_on_reason"
    t.string "heater_off_reason"
    t.datetime "heater_switched_on_at"
    t.datetime "heater_switched_off_at"
    t.boolean "heater"
    t.datetime "manual_heater_on_at"
    t.datetime "manual_heater_off_at"
    t.boolean "scoreboard"
    t.datetime "scoreboard_on_at"
    t.datetime "scoreboard_off_at"
    t.boolean "heater_auto"
    t.integer "region_id"
    t.boolean "global_context", default: false
    t.index ["global_context"], name: "index_tables_on_global_context"
    t.index ["region_id"], name: "index_tables_on_region_id"
  end

  create_table "tournament_ccs", force: :cascade do |t|
    t.integer "cc_id"
    t.string "context"
    t.string "name"
    t.string "shortname"
    t.string "status"
    t.integer "branch_cc_id"
    t.string "season"
    t.integer "registration_list_cc_id"
    t.integer "registration_rule"
    t.integer "discipline_id"
    t.integer "championship_type_cc_id"
    t.integer "category_cc_id"
    t.integer "group_cc_id"
    t.datetime "tournament_start", precision: nil
    t.integer "tournament_series_cc_id"
    t.datetime "tournament_end", precision: nil
    t.time "starting_at"
    t.integer "league_climber_quote"
    t.decimal "entry_fee", precision: 6, scale: 2
    t.integer "max_players"
    t.integer "location_id"
    t.string "location_text"
    t.text "description"
    t.string "poster"
    t.string "tender"
    t.string "flowchart"
    t.string "ranking_list"
    t.string "successor_list"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "tournament_id"
    t.string "branch_cc_name"
    t.string "category_cc_name"
    t.string "championship_type_cc_name"
    t.index ["cc_id", "context"], name: "index_tournament_ccs_on_cc_id_and_context", unique: true
    t.index ["tournament_id"], name: "index_tournament_ccs_on_tournament_id", unique: true
  end

  create_table "tournament_locals", force: :cascade do |t|
    t.integer "tournament_id"
    t.integer "timeout"
    t.integer "timeouts"
    t.boolean "admin_controlled"
    t.boolean "gd_has_prio"
    t.integer "sets_to_win", default: 1, null: false
    t.integer "sets_to_play", default: 1, null: false
    t.integer "team_size", default: 1, null: false
    t.string "fixed_display_left"
    t.boolean "color_remains_with_set", default: true, null: false
    t.boolean "allow_follow_up", default: true, null: false
    t.string "kickoff_switches_with"
    t.integer "innings_goal"
    t.integer "balls_goal"
  end

  create_table "tournament_monitors", force: :cascade do |t|
    t.integer "tournament_id"
    t.text "data"
    t.string "state"
    t.integer "innings_goal"
    t.integer "balls_goal"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "timeouts"
    t.integer "timeout", default: 0, null: false
    t.integer "sets_to_win", default: 1, null: false
    t.integer "sets_to_play", default: 1, null: false
    t.string "fixed_display_left"
    t.boolean "color_remains_with_set", default: true, null: false
    t.integer "team_size", default: 1, null: false
    t.boolean "allow_follow_up", default: true, null: false
    t.boolean "allow_overflow"
    t.string "kickoff_switches_with"
  end

  create_table "tournament_plan_games", force: :cascade do |t|
    t.string "name"
    t.integer "tournament_plan_id"
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tournament_plans", force: :cascade do |t|
    t.string "name"
    t.text "rulesystem"
    t.integer "players"
    t.integer "tables"
    t.text "more_description"
    t.text "even_more_description"
    t.string "executor_class"
    t.text "executor_params"
    t.integer "ngroups"
    t.integer "nrepeats"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tournament_series_ccs", force: :cascade do |t|
    t.integer "cc_id"
    t.string "name"
    t.integer "branch_cc_id"
    t.string "season"
    t.integer "valuation"
    t.integer "series_valuation"
    t.integer "no_tournaments"
    t.string "point_formula"
    t.integer "min_points"
    t.integer "point_fraction"
    t.decimal "price_money", precision: 9, scale: 2
    t.string "currency"
    t.string "club_id"
    t.integer "show_jackpot"
    t.decimal "jackpot", precision: 9, scale: 2
    t.string "status"
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tournament_tables", force: :cascade do |t|
    t.integer "tournament_id"
    t.integer "table_id"
    t.integer "table_no"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["table_no", "tournament_id", "table_id"], name: "index_tournament_tables", unique: true
  end

  create_table "tournaments", force: :cascade do |t|
    t.string "title"
    t.integer "discipline_id"
    t.string "modus"
    t.string "age_restriction"
    t.datetime "date", precision: nil
    t.datetime "accredation_end", precision: nil
    t.text "location_text"
    t.integer "ba_id"
    t.integer "season_id"
    t.integer "region_id"
    t.datetime "end_date", precision: nil
    t.string "plan_or_show"
    t.string "single_or_league"
    t.string "shortname"
    t.text "data"
    t.string "ba_state"
    t.string "state"
    t.datetime "sync_date", precision: nil
    t.string "player_class"
    t.integer "tournament_plan_id"
    t.integer "innings_goal"
    t.integer "balls_goal"
    t.boolean "handicap_tournier"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "timeout", default: 45
    t.integer "time_out_warm_up_first_min", default: 5
    t.integer "time_out_warm_up_follow_up_min", default: 3
    t.integer "organizer_id"
    t.string "organizer_type"
    t.integer "location_id"
    t.integer "timeouts", default: 0, null: false
    t.boolean "admin_controlled", default: false, null: false
    t.boolean "gd_has_prio", default: false, null: false
    t.integer "league_id"
    t.integer "sets_to_win", default: 1, null: false
    t.integer "sets_to_play", default: 1, null: false
    t.integer "team_size", default: 1, null: false
    t.string "fixed_display_left"
    t.boolean "color_remains_with_set", default: true, null: false
    t.boolean "allow_follow_up", default: true, null: false
    t.boolean "continuous_placements", default: false, null: false
    t.boolean "manual_assignment", default: false
    t.string "kickoff_switches_with"
    t.string "source_url"
    t.boolean "global_context", default: false
    t.index ["ba_id"], name: "index_tournaments_on_ba_id", unique: true
    t.index ["global_context"], name: "index_tournaments_on_global_context"
  end

  create_table "uploads", force: :cascade do |t|
    t.string "filename"
    t.integer "user_id"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.string "confirmation_token"
    t.datetime "confirmed_at", precision: nil
    t.datetime "confirmation_sent_at", precision: nil
    t.string "unconfirmed_email"
    t.string "first_name"
    t.string "last_name"
    t.string "time_zone"
    t.datetime "accepted_terms_at", precision: nil
    t.datetime "accepted_privacy_at", precision: nil
    t.datetime "announcements_read_at", precision: nil
    t.boolean "admin"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "invitation_token"
    t.datetime "invitation_created_at", precision: nil
    t.datetime "invitation_sent_at", precision: nil
    t.datetime "invitation_accepted_at", precision: nil
    t.integer "invitation_limit"
    t.string "invited_by_type"
    t.bigint "invited_by_id"
    t.integer "invitations_count", default: 0
    t.string "preferred_language"
    t.string "username"
    t.string "firstname"
    t.string "lastname"
    t.integer "player_id"
    t.integer "sign_in_count"
    t.datetime "current_sign_in_at", precision: nil
    t.datetime "last_sign_in_at", precision: nil
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
    t.boolean "otp_required_for_login"
    t.string "otp_secret"
    t.integer "last_otp_timestep"
    t.text "otp_backup_codes"
    t.string "code"
    t.jsonb "preferences"
    t.virtual "name", type: :string, as: "(((first_name)::text || ' '::text) || (COALESCE(last_name, ''::character varying))::text)", stored: true
    t.integer "role", default: 0
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true
    t.index ["invitations_count"], name: "index_users_on_invitations_count"
    t.index ["invited_by_id"], name: "index_users_on_invited_by_id"
    t.index ["invited_by_type", "invited_by_id"], name: "index_users_on_invited_by_type_and_invited_by_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.string "item_type"
    t.bigint "item_id"
    t.string "event"
    t.string "whodunnit"
    t.text "object"
    t.text "object_changes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "region_id"
    t.boolean "global_context", default: false
    t.index ["global_context"], name: "index_versions_on_global_context"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
    t.index ["region_id"], name: "index_versions_on_region_id"
  end

  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "club_locations", "regions", validate: false
  add_foreign_key "clubs", "regions", validate: false
  add_foreign_key "game_participations", "regions", validate: false
  add_foreign_key "game_plans", "regions", validate: false
  add_foreign_key "games", "regions", validate: false
  add_foreign_key "league_teams", "regions", validate: false
  add_foreign_key "leagues", "regions", validate: false
  add_foreign_key "locations", "regions", validate: false
  add_foreign_key "parties", "regions", validate: false
  add_foreign_key "party_games", "regions", validate: false
  add_foreign_key "player_rankings", "regions", validate: false
  add_foreign_key "players", "regions", validate: false
  add_foreign_key "regions", "regions", validate: false
  add_foreign_key "season_participations", "regions", validate: false
  add_foreign_key "seedings", "regions", validate: false
  add_foreign_key "settings", "clubs"
  add_foreign_key "settings", "regions"
  add_foreign_key "settings", "tournaments"
  add_foreign_key "tables", "locations"
  add_foreign_key "tables", "regions", validate: false
  add_foreign_key "tables", "table_kinds"
  add_foreign_key "tournament_monitors", "tournaments"
  add_foreign_key "tournament_plan_games", "tournament_plans"
  add_foreign_key "tournaments", "regions", validate: false
  add_foreign_key "users", "players"
  add_foreign_key "versions", "regions", validate: false
end
