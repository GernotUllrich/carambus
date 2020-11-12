# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2020_11_10_200523) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "clubs", id: :serial, force: :cascade do |t|
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
    t.index ["ba_id"], name: "index_clubs_on_foreign_keys", unique: true
  end

  create_table "countries", id: :serial, force: :cascade do |t|
    t.string "name"
    t.string "code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_countries_on_code", unique: true
  end

  create_table "discipline_tournament_plans", id: :serial, force: :cascade do |t|
    t.integer "discipline_id"
    t.integer "tournament_plan_id"
    t.integer "points"
    t.integer "innings"
    t.integer "players"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "player_class"
  end

  create_table "disciplines", id: :serial, force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "super_discipline_id"
    t.integer "table_kind_id"
    t.text "data"
    t.index ["name", "table_kind_id"], name: "index_disciplines_on_foreign_keys", unique: true
  end

  create_table "game_participations", id: :serial, force: :cascade do |t|
    t.integer "game_id"
    t.integer "player_id"
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "data"
    t.integer "points"
    t.integer "result"
    t.integer "innings"
    t.float "gd"
    t.integer "hs"
    t.string "gname"
    t.index ["game_id", "player_id", "role"], name: "index_game_participations_on_foreign_keys", unique: true
  end

  create_table "games", id: :serial, force: :cascade do |t|
    t.integer "template_game_id"
    t.integer "tournament_id"
    t.text "roles"
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "seqno"
    t.string "gname"
    t.integer "group_no"
    t.integer "table_no"
    t.integer "round_no"
    t.datetime "started_at"
    t.datetime "ended_at"
    t.index ["template_game_id", "tournament_id"], name: "index_games_on_foreign_keys", unique: true
  end

  create_table "innings", id: :serial, force: :cascade do |t|
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
  end

  create_table "kvc_settings", force: :cascade do |t|
    t.string "key"
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "locations", id: :serial, force: :cascade do |t|
    t.integer "club_id"
    t.text "address"
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.index ["club_id"], name: "index_locations_on_foreign_keys"
  end

  create_table "player_classes", id: :serial, force: :cascade do |t|
    t.integer "discipline_id"
    t.string "shortname"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "player_rankings", id: :serial, force: :cascade do |t|
    t.integer "player_id"
    t.integer "region_id"
    t.integer "season_id"
    t.string "org_level"
    t.integer "discipline_id"
    t.string "status"
    t.integer "points"
    t.integer "innings"
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
  end

  create_table "player_tournament_participations", id: :serial, force: :cascade do |t|
    t.integer "player_id"
    t.integer "tournament_id"
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "players", id: :serial, force: :cascade do |t|
    t.integer "ba_id"
    t.integer "club_id"
    t.string "lastname"
    t.string "firstname"
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ba_id"], name: "index_players_on_ba_id", unique: true
    t.index ["club_id"], name: "index_players_on_club_id"
  end

  create_table "regions", id: :serial, force: :cascade do |t|
    t.string "name"
    t.string "shortname"
    t.string "logo"
    t.string "email"
    t.text "address"
    t.integer "country_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["country_id"], name: "index_regions_on_country_id"
    t.index ["shortname"], name: "index_regions_on_shortname", unique: true
  end

  create_table "season_participations", id: :serial, force: :cascade do |t|
    t.integer "player_id"
    t.integer "season_id"
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "club_id"
    t.index ["player_id", "club_id", "season_id"], name: "index_season_participations_on_foreign_keys", unique: true
  end

  create_table "seasons", id: :serial, force: :cascade do |t|
    t.integer "ba_id"
    t.string "name"
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ba_id"], name: "index_seasons_on_ba_id", unique: true
    t.index ["name"], name: "index_seasons_on_name", unique: true
  end

  create_table "seedings", id: :serial, force: :cascade do |t|
    t.integer "player_id"
    t.integer "tournament_id"
    t.string "ba_state"
    t.integer "position"
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "state", default: "registered", null: false
    t.integer "balls_goal"
    t.integer "playing_discipline_id"
    t.index ["player_id", "tournament_id"], name: "index_seedings_on_foreign_keys", unique: true
  end

  create_table "settings", force: :cascade do |t|
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "state", default: "startup", null: false
    t.integer "region_id"
    t.integer "club_id"
    t.integer "tournament_id"
  end

  create_table "table_kinds", id: :serial, force: :cascade do |t|
    t.string "name"
    t.string "short"
    t.text "measures"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "table_monitors", id: :serial, force: :cascade do |t|
    t.integer "tournament_monitor_id"
    t.string "state"
    t.string "name"
    t.integer "game_id"
    t.integer "next_game_id"
    t.text "data"
    t.integer "ipaddress"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tables", force: :cascade do |t|
    t.integer "location_id"
    t.integer "table_kind_id"
    t.string "name"
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "ip_address"
  end

  create_table "tournament_monitors", id: :serial, force: :cascade do |t|
    t.integer "tournament_id"
    t.text "data"
    t.string "state"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "innings_goal"
    t.integer "balls_goal"
  end

  create_table "tournament_plan_games", id: :serial, force: :cascade do |t|
    t.string "name"
    t.integer "tournament_plan_id"
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tournament_plans", id: :serial, force: :cascade do |t|
    t.string "name"
    t.text "rulesystem"
    t.integer "players"
    t.integer "tables"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "more_description"
    t.text "even_more_description"
    t.string "executor_class"
    t.text "executor_params"
    t.integer "ngroups", default: 2, null: false
    t.integer "nrepeats", default: 1, null: false
  end

  create_table "tournament_tables", force: :cascade do |t|
    t.integer "tournament_id"
    t.integer "table_id"
    t.integer "table_no"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["table_no", "tournament_id", "table_id"], name: "index_tournament_tables", unique: true
  end

  create_table "tournaments", id: :serial, force: :cascade do |t|
    t.string "title"
    t.integer "discipline_id", null: false
    t.string "modus"
    t.string "age_restriction"
    t.datetime "date"
    t.datetime "accredation_end"
    t.text "location"
    t.integer "hosting_club_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "ba_id"
    t.integer "season_id"
    t.integer "region_id"
    t.datetime "end_date"
    t.string "plan_or_show"
    t.string "single_or_league"
    t.string "shortname", default: "", null: false
    t.text "data"
    t.string "ba_state", default: "", null: false
    t.string "state", default: "new_tournament", null: false
    t.datetime "last_ba_sync_date"
    t.string "player_class"
    t.integer "tournament_plan_id"
    t.integer "innings_goal"
    t.integer "balls_goal"
    t.boolean "handicap_tournier"
    t.index ["ba_id"], name: "index_tournaments_on_ba_id", unique: true
    t.index ["title", "season_id", "region_id"], name: "index_tournaments_on_foreign_keys"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "email"
    t.string "username"
    t.string "firstname"
    t.string "lastname"
    t.integer "player_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "versions", id: :serial, force: :cascade do |t|
    t.string "item_type", null: false
    t.bigint "item_id", null: false
    t.string "event", null: false
    t.string "whodunnit"
    t.text "object"
    t.datetime "created_at"
    t.text "object_changes"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

end
