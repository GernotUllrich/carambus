# frozen_string_literal: true

require "test_helper"

# Plan 17-04 (Spec-Fix Checkpoint, AC-7): Laufen zwei Turniere gleichzeitig am selben Spielort,
# teilen sie sich die Tische. Das Startformular des Turnier-Monitors bietet alle passenden Tische
# des Spielorts an (tournaments/tournament_monitor.html.erb), und initialize_table_monitors bindet
# jeden gewählten Tisch an das neue Turnier — ohne zu prüfen, ob er an einem anderen laufenden
# Turnier hängt. reset_table_monitor verweigert zwar das Zurücksetzen eines „managed“ Tisches,
# die Umbindung danach geschieht trotzdem.
#
# IST-Zustand (gemessen 2026-09-13): der Tisch gehört danach Turnier B, das Spiel von Turnier A
# liegt weiter darauf. Die Turnier-App verweigert denselben Fall (TableLocker → „Table already in use“).
# Deshalb nennt die Doku gleichzeitige Turniere an einem Spielort als Grund für die App.
class TournamentMonitor::ConcurrentTournamentsTest < ActiveSupport::TestCase
  setup do
    @original_api_url = Carambus.config.carambus_api_url
    Carambus.config.carambus_api_url = "http://local.test"
    @table = tables(:one)
    @table_monitor = @table.table_monitor
  end

  teardown do
    Carambus.config.carambus_api_url = @original_api_url
  end

  def tournament(title, data = {})
    t = tournaments(:local).dup
    t.assign_attributes(title: title, tournament_plan: tournament_plans(:t04_5), location_id: @table.location_id,
      manual_assignment: false, data: data)
    t.save!
    t
  end

  test "17-04: der Start eines zweiten Turniers übernimmt einen Tisch, auf dem das Spiel des ersten liegt" do
    a = tournament("Turnier A")
    monitor_a = TournamentMonitor.create!(tournament: a)
    monitor_a.update_columns(state: "playing_groups")
    game_a = a.games.create!(id: 61_704_101, gname: "group1:1-2", data: {})
    @table_monitor.update_columns(tournament_monitor_id: monitor_a.id, tournament_monitor_type: "TournamentMonitor",
      game_id: game_a.id)

    b = tournament("Turnier B", {"table_ids" => [@table.id]})
    monitor_b = TournamentMonitor.create!(tournament: b)
    TournamentMonitor::TablePopulator.new(monitor_b).initialize_table_monitors

    @table_monitor.reload
    assert_equal monitor_b.id, @table_monitor.tournament_monitor_id,
      "IST: kein Schutz — der Tisch des laufenden Turniers A wird an Turnier B gebunden"
    assert_equal game_a.id, @table_monitor.game_id, "IST: das Spiel von Turnier A liegt weiter auf dem Tisch"
  end
end
