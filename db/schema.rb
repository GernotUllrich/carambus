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

ActiveRecord::Schema.define(version: 2022_04_25_141254) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "account_invitations", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "invited_by_id"
    t.string "token"
    t.string "name"
    t.string "email"
    t.jsonb "roles", default: {}, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["account_id"], name: "index_account_invitations_on_account_id"
    t.index ["invited_by_id"], name: "index_account_invitations_on_invited_by_id"
    t.index ["token"], name: "index_account_invitations_on_token", unique: true
  end

  create_table "account_users", force: :cascade do |t|
    t.bigint "account_id"
    t.bigint "user_id"
    t.jsonb "roles", default: {}, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["account_id"], name: "index_account_users_on_account_id"
    t.index ["user_id"], name: "index_account_users_on_user_id"
  end

  create_table "accounts", force: :cascade do |t|
    t.string "name"
    t.bigint "owner_id"
    t.boolean "personal", default: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "processor"
    t.string "processor_id"
    t.datetime "trial_ends_at"
    t.string "card_type"
    t.string "card_last4"
    t.string "card_exp_month"
    t.string "card_exp_year"
    t.text "extra_billing_info"
    t.string "domain"
    t.string "subdomain"
    t.index ["owner_id"], name: "index_accounts_on_owner_id"
  end

  create_table "action_text_embeds", force: :cascade do |t|
    t.string "url"
    t.jsonb "fields"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.integer "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "announcements", force: :cascade do |t|
    t.string "kind"
    t.string "title"
    t.datetime "published_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "api_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token"
    t.string "name"
    t.jsonb "metadata", default: {}
    t.boolean "transient", default: false
    t.datetime "last_used_at"
    t.datetime "expires_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["token"], name: "index_api_tokens_on_token", unique: true
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
  end

  create_table "branch_ccs", force: :cascade do |t|
    t.integer "cc_id"
    t.string "context"
    t.integer "region_cc_id"
    t.integer "discipline_id"
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["region_cc_id", "cc_id", "context"], name: "index_branch_ccs_on_region_cc_id_and_cc_id_and_context", unique: true
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
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "cc_id"
    t.index ["ba_id"], name: "index_clubs_on_ba_id", unique: true
    t.index ["ba_id"], name: "index_clubs_on_foreign_keys", unique: true
  end

  create_table "competition_ccs", force: :cascade do |t|
    t.integer "cc_id"
    t.string "name"
    t.string "context"
    t.integer "branch_cc_id"
    t.integer "discipline_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["branch_cc_id", "cc_id", "context"], name: "index_competition_ccs_on_branch_cc_id_and_cc_id_and_context", unique: true
  end

  create_table "countries", force: :cascade do |t|
    t.string "name"
    t.string "code"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["code"], name: "index_countries_on_code", unique: true
  end

  create_table "debug_infos", force: :cascade do |t|
    t.string "info"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "discipline_tournament_plans", force: :cascade do |t|
    t.integer "discipline_id"
    t.integer "tournament_plan_id"
    t.integer "points"
    t.integer "innings"
    t.integer "players"
    t.string "player_class"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "disciplines", force: :cascade do |t|
    t.string "name"
    t.integer "super_discipline_id"
    t.integer "table_kind_id"
    t.text "data"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "type"
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
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "sets"
    t.index ["game_id", "player_id", "role"], name: "index_game_participations_on_foreign_keys", unique: true
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
    t.datetime "started_at"
    t.datetime "ended_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "innings", force: :cascade do |t|
    t.integer "game_id"
    t.integer "sequence_number"
    t.string "player_a_count"
    t.string "player_b_count"
    t.string "player_c_count"
    t.string "player_d_count"
    t.text "data"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["game_id", "sequence_number"], name: "index_innings_on_foreign_keys", unique: true
    t.index ["game_id", "sequence_number"], name: "index_innings_on_game_id_and_sequence_number", unique: true
  end

  create_table "kvc_settings", force: :cascade do |t|
    t.string "key"
    t.text "value"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "league_ccs", force: :cascade do |t|
    t.integer "cc_id"
    t.string "name"
    t.integer "season_cc_id"
    t.integer "league_id"
    t.string "context"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "shortname"
    t.string "status"
    t.string "report_form"
    t.string "report_form_data"
  end

  create_table "league_teams", force: :cascade do |t|
    t.string "name"
    t.string "shortname"
    t.integer "league_id"
    t.integer "ba_id"
    t.integer "club_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
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
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "staffel_text"
    t.integer "cc_id"
    t.string "shortname"
    t.index ["ba_id", "ba_id2"], name: "index_leagues_on_ba_id_and_ba_id2", unique: true
  end

  create_table "location_synonyms", force: :cascade do |t|
    t.string "synonym"
    t.integer "location_id"
  end

  create_table "locations", force: :cascade do |t|
    t.integer "club_id"
    t.text "address"
    t.text "data"
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "organizer_type"
    t.integer "organizer_id"
    t.string "md5", null: false
    t.index ["club_id"], name: "index_locations_on_club_id"
    t.index ["club_id"], name: "index_locations_on_foreign_keys"
    t.index ["md5"], name: "index_locations_on_md5", unique: true
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "recipient_type", null: false
    t.bigint "recipient_id", null: false
    t.string "type"
    t.jsonb "params"
    t.datetime "read_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.datetime "interacted_at"
    t.index ["account_id"], name: "index_notifications_on_account_id"
    t.index ["recipient_type", "recipient_id"], name: "index_notifications_on_recipient_type_and_recipient_id"
  end

  create_table "parties", force: :cascade do |t|
    t.datetime "date"
    t.integer "league_id"
    t.text "remarks"
    t.integer "league_team_a_id"
    t.integer "league_team_b_id"
    t.integer "ba_id"
    t.integer "day_seqno"
    t.text "data"
    t.integer "host_league_team_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "no_show_team_id"
    t.string "section"
  end

  create_table "party_games", force: :cascade do |t|
    t.integer "party_id"
    t.integer "seqno"
    t.integer "player_a_id"
    t.integer "player_b_id"
    t.integer "tournament_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.text "data"
    t.string "name"
    t.integer "discipline_id"
  end

  create_table "party_tournaments", force: :cascade do |t|
    t.integer "party_id"
    t.integer "tournament_id"
    t.integer "position"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "pay_charges", force: :cascade do |t|
    t.bigint "owner_id"
    t.string "processor", null: false
    t.string "processor_id", null: false
    t.integer "amount", null: false
    t.integer "amount_refunded"
    t.string "card_type"
    t.string "card_last4"
    t.string "card_exp_month"
    t.string "card_exp_year"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "owner_type"
    t.index ["owner_id"], name: "index_pay_charges_on_owner_id"
  end

  create_table "pay_subscriptions", id: :serial, force: :cascade do |t|
    t.integer "owner_id"
    t.string "name", null: false
    t.string "processor", null: false
    t.string "processor_id", null: false
    t.string "processor_plan", null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "trial_ends_at"
    t.datetime "ends_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "status"
    t.string "owner_type"
  end

  create_table "plans", force: :cascade do |t|
    t.string "name"
    t.integer "amount", default: 0, null: false
    t.string "interval"
    t.jsonb "details", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "trial_period_days", default: 0
  end

  create_table "player_classes", force: :cascade do |t|
    t.integer "discipline_id"
    t.string "shortname"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
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
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "players", force: :cascade do |t|
    t.integer "ba_id"
    t.integer "club_id"
    t.string "lastname"
    t.string "firstname"
    t.string "title"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "guest", default: false, null: false
    t.string "nickname"
    t.string "type"
    t.text "data"
    t.integer "tournament_id"
    t.integer "cc_id"
    t.index ["ba_id"], name: "index_players_on_ba_id", unique: true
    t.index ["club_id"], name: "index_players_on_club_id"
  end

  create_table "region_ccs", force: :cascade do |t|
    t.integer "cc_id"
    t.string "context"
    t.integer "region_id"
    t.string "shortname"
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "base_url"
    t.index ["cc_id", "context"], name: "index_region_ccs_on_cc_id_and_context", unique: true
  end

  create_table "regions", force: :cascade do |t|
    t.string "name"
    t.string "shortname"
    t.string "logo"
    t.string "email"
    t.text "address"
    t.integer "country_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["country_id"], name: "index_regions_on_country_id"
    t.index ["shortname"], name: "index_regions_on_shortname", unique: true
  end

  create_table "season_ccs", force: :cascade do |t|
    t.integer "cc_id"
    t.string "name"
    t.integer "season_id"
    t.integer "competition_cc_id"
    t.string "context"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["competition_cc_id", "cc_id", "context"], name: "index_season_ccs_on_competition_cc_id_and_cc_id_and_context", unique: true
  end

  create_table "season_participations", force: :cascade do |t|
    t.integer "player_id"
    t.integer "season_id"
    t.text "data"
    t.integer "club_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["player_id", "club_id", "season_id"], name: "index_season_participations_on_foreign_keys", unique: true
  end

  create_table "seasons", force: :cascade do |t|
    t.integer "ba_id"
    t.string "name"
    t.text "data"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
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
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "rank"
    t.integer "league_team_id"
  end

  create_table "settings", force: :cascade do |t|
    t.text "data"
    t.string "state"
    t.integer "region_id"
    t.integer "club_id"
    t.integer "tournament_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "table_kinds", force: :cascade do |t|
    t.string "name"
    t.string "short"
    t.text "measures"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "table_monitors", force: :cascade do |t|
    t.integer "tournament_monitor_id"
    t.string "state"
    t.string "name"
    t.integer "game_id"
    t.integer "next_game_id"
    t.text "data"
    t.string "ip_address"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "active_timer"
    t.datetime "timer_start_at"
    t.datetime "timer_finish_at"
    t.datetime "timer_halt_at"
    t.integer "nnn"
    t.string "panel_state", default: "pointer_mode", null: false
    t.string "current_element", default: "pointer_mode", null: false
    t.string "timer_job_id"
    t.string "clock_job_id"
  end

  create_table "tables", force: :cascade do |t|
    t.integer "location_id"
    t.integer "table_kind_id"
    t.string "name"
    t.text "data"
    t.string "ip_address"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "table_monitor_id"
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
    t.boolean "kickoff_switches_with_set", default: true, null: false
    t.string "fixed_display_left"
    t.boolean "color_remains_with_set", default: true, null: false
    t.boolean "allow_follow_up", default: true, null: false
  end

  create_table "tournament_monitors", force: :cascade do |t|
    t.integer "tournament_id"
    t.text "data"
    t.string "state"
    t.integer "innings_goal"
    t.integer "balls_goal"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "timeouts"
    t.integer "timeout", default: 0, null: false
    t.integer "sets_to_win", default: 1, null: false
    t.integer "sets_to_play", default: 1, null: false
    t.boolean "kickoff_switches_with_set", default: true, null: false
    t.string "fixed_display_left"
    t.boolean "color_remains_with_set", default: true, null: false
    t.integer "team_size", default: 1, null: false
    t.boolean "allow_follow_up", default: true, null: false
    t.boolean "allow_overflow"
  end

  create_table "tournament_plan_games", force: :cascade do |t|
    t.string "name"
    t.integer "tournament_plan_id"
    t.text "data"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
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
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "tournament_tables", force: :cascade do |t|
    t.integer "tournament_id"
    t.integer "table_id"
    t.integer "table_no"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["table_no", "tournament_id", "table_id"], name: "index_tournament_tables", unique: true
  end

  create_table "tournaments", force: :cascade do |t|
    t.string "title"
    t.integer "discipline_id"
    t.string "modus"
    t.string "age_restriction"
    t.datetime "date"
    t.datetime "accredation_end"
    t.text "location"
    t.integer "ba_id"
    t.integer "season_id"
    t.integer "region_id"
    t.datetime "end_date"
    t.string "plan_or_show"
    t.string "single_or_league"
    t.string "shortname"
    t.text "data"
    t.string "ba_state"
    t.string "state"
    t.datetime "last_ba_sync_date"
    t.string "player_class"
    t.integer "tournament_plan_id"
    t.integer "innings_goal"
    t.integer "balls_goal"
    t.boolean "handicap_tournier"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "timeout", default: 45
    t.integer "time_out_warm_up_first_min", default: 5
    t.integer "time_out_warm_up_follow_up_min", default: 3
    t.integer "organizer_id"
    t.string "organizer_type"
    t.integer "location_id"
    t.integer "timeouts", default: 0, null: false
    t.boolean "admin_controlled", default: false, null: false
    t.boolean "manual_assignment", default: false
    t.boolean "gd_has_prio", default: false, null: false
    t.integer "league_id"
    t.integer "sets_to_win", default: 1, null: false
    t.integer "sets_to_play", default: 1, null: false
    t.integer "team_size", default: 1, null: false
    t.boolean "kickoff_switches_with_set", default: true, null: false
    t.string "fixed_display_left"
    t.boolean "color_remains_with_set", default: true, null: false
    t.boolean "allow_follow_up", default: true, null: false
    t.index ["ba_id"], name: "index_tournaments_on_ba_id", unique: true
    t.index ["title", "season_id", "region_id"], name: "index_tournaments_on_foreign_keys"
  end

  create_table "user_connected_accounts", force: :cascade do |t|
    t.bigint "user_id"
    t.string "provider"
    t.string "uid"
    t.string "encrypted_access_token"
    t.string "encrypted_access_token_iv"
    t.string "encrypted_access_token_secret"
    t.string "encrypted_access_token_secret_iv"
    t.string "refresh_token"
    t.datetime "expires_at"
    t.text "auth"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["encrypted_access_token_iv"], name: "index_connected_accounts_access_token_iv", unique: true
    t.index ["encrypted_access_token_secret_iv"], name: "index_connected_accounts_access_token_secret_iv", unique: true
    t.index ["user_id"], name: "index_user_connected_accounts_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.string "first_name"
    t.string "last_name"
    t.string "time_zone"
    t.datetime "accepted_terms_at"
    t.datetime "accepted_privacy_at"
    t.datetime "announcements_read_at"
    t.boolean "admin"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "invitation_token"
    t.datetime "invitation_created_at"
    t.datetime "invitation_sent_at"
    t.datetime "invitation_accepted_at"
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
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
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
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "account_invitations", "accounts"
  add_foreign_key "account_invitations", "users", column: "invited_by_id"
  add_foreign_key "account_users", "accounts"
  add_foreign_key "account_users", "users"
  add_foreign_key "accounts", "users", column: "owner_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "api_tokens", "users"
  add_foreign_key "settings", "clubs"
  add_foreign_key "settings", "regions"
  add_foreign_key "settings", "tournaments"
  add_foreign_key "tables", "locations"
  add_foreign_key "tables", "table_kinds"
  add_foreign_key "tournament_monitors", "tournaments"
  add_foreign_key "tournament_plan_games", "tournament_plans"
  add_foreign_key "user_connected_accounts", "users"
  add_foreign_key "users", "players"
end
