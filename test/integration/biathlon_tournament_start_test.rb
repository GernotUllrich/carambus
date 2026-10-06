# frozen_string_literal: true

require "test_helper"

# Biathlon im Turnier (2026-10-06): die Variante (Dreiband-Distanz, Aufnahmen Dreiband) wird
# auf der Startseite eingestellt und beim Start am lokalen TournamentMonitor abgelegt — nicht in
# tournament.data, das bei globalen Turnieren ein Sync ueberschreiben kann. Ablauf wie in
# app_tournament_web_path_test.rb.
class BiathlonTournamentStartTest < ActionDispatch::IntegrationTest
  setup do
    @original_api_url = Carambus.config.carambus_api_url
    Carambus.config.carambus_api_url = "http://local.test" # lokaler Server
    @nbv = regions(:nbv)
    @plan = tournament_plans(:t04_5)
    @table = tables(:one)
    @biathlon = Discipline.find_by(name: "Biathlon") || Discipline.create!(name: "Biathlon")
    @players = (1..5).map do |i|
      Player.create!(id: 50_017_140 + i, firstname: "Bia#{i}", lastname: "Start", ba_id: 1_714_000 + i)
    end
  end

  teardown do
    Carambus.config.carambus_api_url = @original_api_url
  end

  def create_biathlon_tournament
    sign_in users(:club_admin)
    post tournaments_url, params: {tournament: {
      title: "Biathlon Grand Prix Test", shortname: "BIATEST", date: 1.week.from_now, end_date: 3.weeks.from_now,
      season_id: seasons(:current).id, organizer_id: @nbv.id, organizer_type: "Region",
      discipline_id: @biathlon.id, location_id: @table.location_id, balls_goal: 120, innings_goal: 0
    }}
    tournament = Tournament.order(:id).last
    @players.each_with_index { |p, i| tournament.seedings.create!(player: p, position: i + 1) }
    post finish_seeding_tournament_url(tournament)
    get finalize_modus_tournament_url(tournament)
    post select_modus_tournament_url(tournament), params: {tournament_plan_id: @plan.id}
    tournament.reload
  end

  def start(tournament, extra = {})
    post start_tournament_url(tournament),
      params: {balls_goal: 120, innings_goal: 0, table_id: [@table.id], parameter_verification_confirmed: "1"}.merge(extra)
    tournament.reload
  end

  test "Startseite zeigt die Biathlon-Felder" do
    tournament = create_biathlon_tournament
    get tournament_monitor_tournament_url(tournament)

    assert_select "input[name='biathlon[balls_goal_3b]'][value='15']"
    assert_select "input[name='biathlon[innings_goal_3b]'][value='30']"
  end

  test "Start legt die Variante am TournamentMonitor ab und schreibt sie auf die Tische" do
    tournament = create_biathlon_tournament
    start(tournament, biathlon: {balls_goal_3b: 10, innings_goal_3b: 20})

    expected = {"balls_goal_3b" => 10, "innings_goal_3b" => 20, "factor" => 6}
    assert_equal expected, tournament.tournament_monitor.data["biathlon"]
    monitors = tournament.tournament_monitor.table_monitors.to_a
    assert monitors.any?, "Testvoraussetzung: mindestens ein Tisch im Turnier"
    monitors.each { |tm| assert_equal expected, tm.data["biathlon"] }
  end

  test "Gegenprobe: ein Dreiband-Turnier bekommt keine Biathlon-Variante" do
    tournament = create_biathlon_tournament
    tournament.update_columns(discipline_id: disciplines(:carom_3band).id)
    start(tournament, biathlon: {balls_goal_3b: 10, innings_goal_3b: 20})

    assert_nil tournament.tournament_monitor.data["biathlon"]
  end
end
