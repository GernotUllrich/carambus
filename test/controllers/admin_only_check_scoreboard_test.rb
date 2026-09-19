# frozen_string_literal: true

require "test_helper"

# Plan 20-04: die Ausnahme `guest_player_creation?` in `admin_only_check`.
#
# Diese Datei ist zuerst als CHARAKTERISIERUNG entstanden: sie lief am unveraenderten Code und
# belegte, dass das Scoreboard-Konto mit `club_id` + `season_id` in den Params das Admin-Gate von
# 20 Controllern passierte. Als Scoreboard-Konto wird jeder anonyme Besucher ueber
# `/locations/:id` automatisch angemeldet (`LocationsController#set_location`, Befund 20-01).
#
# Die Ausnahme ist fuer genau ein Formular da: „Gastspieler anlegen" im Scoreboard-Modal
# (`locations/_new_player_modal.html.erb` → POST /players mit from=new_guest). Nur das bleibt offen.
#
# `User.scoreboard` liefert in der Testumgebung nil; die Ausnahme prueft aber nur die E-Mail
# (`Current.user.email`), deshalb genuegt ein Konto mit dieser Adresse.
class AdminOnlyCheckScoreboardTest < ActionDispatch::IntegrationTest
  GATED = %w[club country discipline discipline_tournament_plan game_participation game league_team league
    party party_game player_class player_ranking player region season_participation season seeding
    table_kind table tournament_plan].freeze

  setup do
    @scoreboard = User.create!(email: "scoreboard@carambus.de", password: "Scoreboard!2026x",
      role: :player, confirmed_at: Time.current)
    @club_admin = users(:club_admin)
    @club = clubs(:bcw)
    @season = seasons(:current)
    @ctx = {club_id: @club.id, season_id: @season.id}
  end

  def admin_only_denied?
    response.redirect? && flash[:alert].to_s.start_with?("Admin Only")
  end

  # ---------------------------------------------------------------------------
  # Gate je Controller: GET new mit club_id + season_id
  # ---------------------------------------------------------------------------

  GATED.each do |res|
    test "#{res}: das Scoreboard-Konto mit club_id+season_id kommt nicht an new vorbei" do
      sign_in @scoreboard
      begin
        get send(:"new_#{res}_path", **@ctx)
      rescue
        flunk "new_#{res}: Rumpf erreicht (Ausnahme im Rumpf) — Gate passiert"
      end
      assert admin_only_denied?, "new_#{res}: nicht abgewiesen (Status #{response.status})"
    end
  end

  # ---------------------------------------------------------------------------
  # Zustand: drei Schreibaktionen
  # ---------------------------------------------------------------------------

  test "players#create ohne from=new_guest legt als Scoreboard-Konto keinen Spieler an" do
    sign_in @scoreboard
    assert_no_difference "Player.count" do
      post players_path, params: @ctx.merge(player: {firstname: "Ein", lastname: "Geschmuggelt"})
    end
    assert admin_only_denied?
  end

  test "table_kinds#update als Scoreboard-Konto ändert nichts" do
    kind = table_kinds(:one)
    sign_in @scoreboard
    patch table_kind_path(kind, **@ctx), params: {table_kind: {name: "Geändert"}}
    assert_equal "Karambol", kind.reload.name
    assert admin_only_denied?
  end

  test "player_rankings#destroy als Scoreboard-Konto löscht nichts" do
    ranking = player_rankings(:ullrich_dreiband)
    sign_in @scoreboard
    assert_no_difference "PlayerRanking.count" do
      delete player_ranking_path(ranking, **@ctx)
    end
    assert admin_only_denied?
  end

  # ---------------------------------------------------------------------------
  # Die eine erlaubte Stelle: Gastspieler-Anlage im Scoreboard-Modal
  # ---------------------------------------------------------------------------

  def guest_params(**overrides)
    {club_id: @club.id, season_id: @season.id, from: "new_guest",
     player: {firstname: "Gast", lastname: "Spieler"}}.merge(overrides)
  end

  test "Gastspieler-Anlage: das Scoreboard-Konto legt Spieler und Saison-Teilnahme an" do
    sign_in @scoreboard
    assert_difference ["Player.count", "SeasonParticipation.count"], 1 do
      post players_path, params: guest_params
    end
    assert_not admin_only_denied?
  end

  test "Gastspieler-Anlage ohne club_id oder season_id wird abgewiesen" do
    sign_in @scoreboard
    [guest_params.except(:club_id), guest_params.except(:season_id)].each do |params|
      assert_no_difference("Player.count") { post players_path, params: params }
      assert admin_only_denied?
    end
  end

  test "ein anderes Spielerkonto bekommt die Ausnahme nicht" do
    sign_in users(:player)
    assert_no_difference("Player.count") { post players_path, params: guest_params }
    assert admin_only_denied?
  end

  # ---------------------------------------------------------------------------
  # Admins unveraendert
  # ---------------------------------------------------------------------------

  test "ein club_admin ändert wie bisher" do
    kind = table_kinds(:one)
    sign_in @club_admin
    patch table_kind_path(kind), params: {table_kind: {name: "Vom Admin"}}
    assert_equal "Vom Admin", kind.reload.name
  end
end
