# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20201011172004) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "clubs", force: :cascade do |t|
    t.integer  "ba_id"
    t.integer  "region_id"
    t.string   "name"
    t.string   "shortname"
    t.text     "address"
    t.string   "homepage"
    t.string   "email"
    t.text     "priceinfo"
    t.string   "logo"
    t.string   "status"
    t.string   "founded"
    t.string   "dbu_entry"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "clubs", ["ba_id"], name: "index_clubs_on_foreign_keys", unique: true, using: :btree

  create_table "countries", force: :cascade do |t|
    t.string   "name"
    t.string   "code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "countries", ["code"], name: "index_countries_on_code", unique: true, using: :btree

  create_table "disciplines", force: :cascade do |t|
    t.string   "name"
    t.datetime "created_at",          null: false
    t.datetime "updated_at",          null: false
    t.integer  "super_discipline_id"
    t.integer  "table_kind_id"
    t.text     "data"
  end

  add_index "disciplines", ["name", "table_kind_id"], name: "index_disciplines_on_foreign_keys", unique: true, using: :btree

  create_table "game_participations", force: :cascade do |t|
    t.integer  "game_id"
    t.integer  "player_id"
    t.string   "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text     "remarks"
    t.integer  "points"
    t.integer  "result"
    t.integer  "innings"
    t.float    "gd"
    t.integer  "hs"
    t.string   "gname"
  end

  add_index "game_participations", ["game_id", "player_id", "role"], name: "index_game_participations_on_foreign_keys", unique: true, using: :btree

  create_table "games", force: :cascade do |t|
    t.integer  "template_game_id"
    t.integer  "tournament_id"
    t.text     "roles"
    t.text     "remarks"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
    t.integer  "seqno"
    t.string   "gname"
  end

  add_index "games", ["template_game_id", "tournament_id"], name: "index_games_on_foreign_keys", unique: true, using: :btree

  create_table "innings", force: :cascade do |t|
    t.integer  "game_id"
    t.integer  "sequence_number"
    t.string   "player_a_count"
    t.string   "player_b_count"
    t.string   "player_c_count"
    t.string   "player_d_count"
    t.text     "remarks"
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
  end

  add_index "innings", ["game_id", "sequence_number"], name: "index_innings_on_foreign_keys", unique: true, using: :btree

  create_table "locations", force: :cascade do |t|
    t.integer  "club_id"
    t.text     "address"
    t.text     "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "locations", ["club_id"], name: "index_locations_on_foreign_keys", using: :btree

  create_table "player_classes", force: :cascade do |t|
    t.integer  "discipline_id"
    t.string   "shortname"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

  create_table "player_count_templates", force: :cascade do |t|
    t.string   "name"
    t.integer  "tournament_template_id"
    t.integer  "players"
    t.integer  "template_id"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "player_count_templates", ["tournament_template_id", "players", "template_id"], name: "index_player_count_templates_on_foreign_keys", unique: true, using: :btree

  create_table "player_rankings", force: :cascade do |t|
    t.integer  "player_id"
    t.integer  "region_id"
    t.integer  "season_id"
    t.string   "org_level"
    t.integer  "discipline_id"
    t.string   "status"
    t.integer  "points"
    t.integer  "innings"
    t.float    "gd"
    t.integer  "hs"
    t.float    "bed"
    t.float    "btg"
    t.integer  "player_class_id"
    t.integer  "p_player_class_id"
    t.integer  "pp_player_class_id"
    t.float    "p_gd"
    t.float    "pp_gd"
    t.integer  "tournament_player_class_id"
    t.integer  "rank"
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
    t.text     "remarks"
    t.integer  "g"
    t.integer  "v"
    t.float    "quote"
    t.integer  "sp_g"
    t.integer  "sp_v"
    t.float    "sp_quote"
    t.integer  "balls"
    t.integer  "sets"
    t.text     "t_ids"
  end

  create_table "player_tournament_participations", force: :cascade do |t|
    t.integer  "player_id"
    t.integer  "tournament_id"
    t.text     "data"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

  create_table "players", force: :cascade do |t|
    t.integer  "ba_id"
    t.integer  "club_id"
    t.string   "lastname"
    t.string   "firstname"
    t.string   "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "players", ["ba_id"], name: "index_players_on_ba_id", unique: true, using: :btree
  add_index "players", ["club_id"], name: "index_players_on_club_id", using: :btree

  create_table "regions", force: :cascade do |t|
    t.string   "name"
    t.string   "shortname"
    t.string   "logo"
    t.string   "email"
    t.text     "address"
    t.integer  "country_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "regions", ["country_id"], name: "index_regions_on_country_id", using: :btree
  add_index "regions", ["shortname"], name: "index_regions_on_shortname", unique: true, using: :btree

  create_table "season_participations", force: :cascade do |t|
    t.integer  "player_id"
    t.integer  "season_id"
    t.text     "remarks"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer  "club_id"
  end

  add_index "season_participations", ["player_id", "club_id", "season_id"], name: "index_season_participations_on_foreign_keys", unique: true, using: :btree

  create_table "seasons", force: :cascade do |t|
    t.integer  "ba_id"
    t.string   "name"
    t.text     "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "seasons", ["ba_id"], name: "index_seasons_on_ba_id", unique: true, using: :btree
  add_index "seasons", ["name"], name: "index_seasons_on_name", unique: true, using: :btree

  create_table "seedings", force: :cascade do |t|
    t.integer  "player_id"
    t.integer  "tournament_id"
    t.string   "status"
    t.integer  "position"
    t.text     "remarks"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

  add_index "seedings", ["player_id", "tournament_id"], name: "index_seedings_on_foreign_keys", unique: true, using: :btree

  create_table "table_kinds", force: :cascade do |t|
    t.string   "name"
    t.string   "short"
    t.text     "measures"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "template_games", force: :cascade do |t|
    t.string   "name"
    t.integer  "template_id"
    t.text     "remarks"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  create_table "templates", force: :cascade do |t|
    t.string   "name"
    t.string   "rulesystem"
    t.integer  "players"
    t.integer  "tables"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tournament_templates", force: :cascade do |t|
    t.string   "name"
    t.integer  "discipline_id"
    t.integer  "points"
    t.integer  "innings"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

  create_table "tournaments", force: :cascade do |t|
    t.string   "title"
    t.integer  "discipline_id",                 null: false
    t.string   "modus"
    t.string   "age_restriction"
    t.datetime "date"
    t.datetime "accredation_end"
    t.text     "location"
    t.integer  "hosting_club_id"
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
    t.integer  "ba_id"
    t.integer  "season_id"
    t.integer  "region_id"
    t.datetime "end_date"
    t.string   "plan_or_show"
    t.string   "single_or_league"
    t.string   "shortname",        default: "", null: false
    t.text     "remarks"
    t.string   "mgmt_status",      default: "", null: false
  end

  add_index "tournaments", ["ba_id"], name: "index_tournaments_on_ba_id", unique: true, using: :btree
  add_index "tournaments", ["title", "season_id", "region_id"], name: "index_tournaments_on_foreign_keys", using: :btree

  create_table "users", force: :cascade do |t|
    t.string   "email"
    t.string   "username"
    t.string   "firstname"
    t.string   "lastname"
    t.integer  "player_id"
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
    t.string   "encrypted_password",     default: "", null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet     "current_sign_in_ip"
    t.inet     "last_sign_in_ip"
    t.string   "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string   "unconfirmed_email"
  end

  add_index "users", ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true, using: :btree
  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree
  add_index "users", ["username"], name: "index_users_on_username", unique: true, using: :btree

end
