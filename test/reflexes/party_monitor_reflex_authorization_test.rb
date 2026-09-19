# frozen_string_literal: true

require "test_helper"

# Plan 20-02: PartyMonitorReflex prueft ein Recht, bevor er eine Begegnung veraendert.
#
# Entstanden als CHARAKTERISIERUNG am unveraenderten Code. Dort prueft keine oeffentliche
# Reflex-Methode ein Recht — ausser reset_party_monitor, die selbst admin? abfragt (am alten
# Stand 33 von 33 Tests rot). Seit dem Gate: PartyPolicy#operate? (Leiter, Sportwart, Admin). Die
# Cable-Verbindung laesst anonyme Clients bewusst zu (connection.rb), die Autorisierung liegt
# also allein beim Reflex.
#
# Muster wie tournament_reflex_test.rb (17-05): Reflex per .allocate, element/current_user/
# method_name/params/flash gestubbt, Aufruf ueber `process` — nur so laufen die before_reflex-
# Callbacks.
#
# Zwei Messarten:
#   - am ZUSTAND fuer die Reflexe, die sich ohne Tische/TableMonitors ausfuehren lassen
#     (Aufstellung, Parameter);
#   - per SPION fuer alle oeffentlichen Methoden: die Methode wird auf dem Reflex-Objekt durch
#     einen Zaehler ersetzt. Wird sie aufgerufen, hat kein Callback den Aufruf verhindert — genau
#     das ist die Aufgabe des Gates. Der Rumpf selbst (Rundenablauf, Spielanlage) braucht dafuer
#     keinen lauffaehigen Tischaufbau.
class PartyMonitorReflexAuthorizationTest < ActiveSupport::TestCase
  include PartyMonitorTestHelper

  # Alle oeffentlichen Reflex-Methoden ausser reset_party_monitor (eigene Pruefung, unveraendert).
  GATED_REFLEXES = %i[assign_player_a assign_player_b remove_player_a remove_player_b assign_player remove_player
    edit_parameter gather_parameters prepare_next_round enter_next_round_seeding finish_round_seeding_mode
    finish_round start_round enter_game_results close_party].freeze

  setup do
    objects = create_party_monitor_with_party(state: "seeding_mode")
    @party_monitor = objects[:party_monitor]
    @party = objects[:party]
    @spieler = players(:jaspers)
    @player_user = users(:one)
  end

  def reflex_for(method_name, user:, params: {})
    pm_id = @party_monitor.id
    reflex = PartyMonitorReflex.allocate
    reflex.define_singleton_method(:element) { OpenStruct.new(dataset: {"id" => pm_id.to_s, "rno" => "1"}) }
    reflex.define_singleton_method(:current_user) { user }
    reflex.define_singleton_method(:method_name) { method_name.to_s }
    reflex.define_singleton_method(:params) { ActionController::Parameters.new(params) }
    flash = {}
    reflex.define_singleton_method(:flash) { flash }
    reflex
  end

  # Ersetzt die Reflex-Methode durch einen Zaehler und ruft sie ueber process auf.
  def spy_call(method_name, user:)
    reflex = reflex_for(method_name, user: user)
    calls = 0
    reflex.define_singleton_method(method_name) { |*| calls += 1 }
    args = %i[assign_player remove_player].include?(method_name) ? ["a"] : []
    reflex.process(method_name, *args)
    [reflex, calls]
  end

  def team_a_seedings
    Seeding.where(tournament: @party, role: "team_a", player_id: @spieler.id)
  end

  # ---------------------------------------------------------------------------
  # Spion: keine Methode wird ohne Recht erreicht
  # ---------------------------------------------------------------------------

  GATED_REFLEXES.each do |name|
    test "#{name}: anonym wird die Methode nicht erreicht" do
      reflex, calls = spy_call(name, user: nil)
      assert_equal 0, calls, "#{name} lief anonym bis in den Rumpf"
      assert reflex.halted?, "#{name}: der Reflex wird abgebrochen"
    end

    test "#{name}: ein Spielerkonto ohne Recht erreicht die Methode nicht" do
      _reflex, calls = spy_call(name, user: @player_user)
      assert_equal 0, calls, "#{name} lief als player bis in den Rumpf"
    end
  end

  GATED_REFLEXES.each do |name|
    test "#{name}: der eingesetzte Begegnungsleiter erreicht die Methode" do
      UserParty.create!(user: users(:two), party: @party)
      reflex, calls = spy_call(name, user: users(:two))
      assert_equal 1, calls
      refute reflex.halted?
    end
  end

  test "ein Admin erreicht die Methode, reset_party_monitor bleibt ungegatet (eigene Pruefung)" do
    _reflex, calls = spy_call(:start_round, user: users(:club_admin))
    assert_equal 1, calls
    _reflex, calls = spy_call(:reset_party_monitor, user: nil)
    assert_equal 1, calls, "reset_party_monitor prueft selbst, der before_reflex laesst ihn durch"
  end

  test "assign_player_a: der Leiter meldet wie bisher" do
    UserParty.create!(user: users(:two), party: @party)
    reflex = reflex_for(:assign_player_a, user: users(:two), params: {"availablePlayerAId" => [@spieler.id.to_s]})
    assert_difference -> { team_a_seedings.count }, 1 do
      reflex.process(:assign_player_a)
    end
  end

  # ---------------------------------------------------------------------------
  # Zustand: Aufstellung und Parameter
  # ---------------------------------------------------------------------------

  test "assign_player_a: anonym wird niemand gemeldet" do
    reflex = reflex_for(:assign_player_a, user: nil, params: {"availablePlayerAId" => [@spieler.id.to_s]})
    assert_no_difference -> { team_a_seedings.count }, "anonym wurde ein Spieler gemeldet" do
      reflex.process(:assign_player_a)
    end
  end

  test "remove_player_a: anonym wird niemand abgemeldet" do
    Seeding.create!(player_id: @spieler.id, tournament: @party, role: "team_a", position: 1)
    reflex = reflex_for(:remove_player_a, user: nil, params: {"assignedPlayerAId" => [@spieler.id.to_s]})
    assert_no_difference -> { team_a_seedings.count }, "anonym wurde ein Spieler abgemeldet" do
      reflex.process(:remove_player_a)
    end
  end

  test "edit_parameter: anonym bleiben die Parameter der Begegnung unveraendert" do
    @party.update_column(:cc_id, 4711)
    @party_monitor.update!(data: {"rows" => [{"type" => "14/1e", "r_no" => 1}]})
    before = @party_monitor.reload.data.deep_dup
    reflex = reflex_for(:edit_parameter, user: nil, params: {"4711-0-1-1-player_a" => "99"})
    reflex.process(:edit_parameter)
    assert_equal before, @party_monitor.reload.data, "anonym wurden die Parameter umgeschrieben"
  end
end

# Plan 20-02, Nebenbefund: TournamentReflex#change_party_seeding / #change_party_game_seeding
# koennen nie schreiben — party_games hat keine Spalte tournament_id, PartyGame keine solche
# Assoziation. Am alten Stand warf ein Aufruf, bevor er etwas aenderte. Betreiber: gaten statt
# entfernen — ohne prepare_tournament? bricht der Reflex jetzt vorher ab.
class TournamentReflexPartySeedingTest < ActiveSupport::TestCase
  test "change_party_seeding und change_party_game_seeding: anonym abgebrochen, ohne zu schreiben" do
    tournament = tournaments(:local)
    party = parties(:party_one)
    party_game = PartyGame.create!(id: 50_020_021, party: party, seqno: 1, name: "tot")
    before = party_game.reload.attributes

    [[:change_party_seeding, "party_#{party.id}"], [:change_party_game_seeding, "party_game_#{party_game.id}"]].each do |name, dom_id|
      reflex = TournamentReflex.allocate
      element = OpenStruct.new(dataset: {"id" => tournament.id.to_s}, attributes: {"id" => dom_id, "checked" => "checked"})
      reflex.define_singleton_method(:element) { element }
      reflex.define_singleton_method(:current_user) { nil }
      reflex.define_singleton_method(:method_name) { name.to_s }
      reflex.process(name)
      assert reflex.halted?, "#{name} wird ohne Recht abgebrochen"
    end
    assert_equal before, party_game.reload.attributes
  end
end
