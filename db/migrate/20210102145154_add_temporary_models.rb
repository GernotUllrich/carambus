class AddTemporaryModels < ActiveRecord::Migration[6.0]
  def change
    create_table "t_seedings", force: :cascade do |t|
      t.integer "player_id"
      t.integer "t_tournament_id"
      t.string "ba_state"
      t.integer "position"
      t.text "data"
      t.string "state"
      t.integer "balls_goal"
      t.integer "playing_discipline_id"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.integer "rank"
      t.index ["player_id", "t_tournament_id"], name: "index_t_seedings_on_foreign_keys", unique: true
    end
    create_table "t_games", force: :cascade do |t|
      t.integer "t_tournament_id"
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
      t.index ["t_tournament_id"], name: "index_t_games_on_foreign_keys", unique: true
    end

    create_table "t_game_participations", force: :cascade do |t|
      t.integer "t_game_id"
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
      t.index ["t_game_id", "player_id", "role"], name: "index_t_game_participations_on_foreign_keys", unique: true
    end

    create_table "t_tournaments", force: :cascade do |t|
      t.string "title"
      t.bigint "tournament_id"
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
      t.integer "time_out_stoke_preparation_sec", default: 45
      t.integer "time_out_warm_up_first_min", default: 5
      t.integer "time_out_warm_up_follow_up_min", default: 3
      t.integer "organizer_id"
      t.string "organizer_type"
      t.integer "location_id"
      t.index ["ba_id"], name: "index_t_tournaments_on_ba_id", unique: true
      t.index ["title", "season_id", "region_id"], name: "index_t_tournaments_on_foreign_keys"
    end
    create_table "t_locations", force: :cascade do |t|
      t.integer "club_id"
      t.text "address"
      t.text "data"
      t.string "name"
      t.datetime "created_at", precision: 6, null: false
      t.datetime "updated_at", precision: 6, null: false
      t.string "organizer_type"
      t.integer "organizer_id"
      t.index ["club_id"], name: "index _t_locations_on_club_id"
      t.index ["club_id"], name: "index_t_locations_on_foreign_keys"
    end
  end

end
