# frozen_string_literal: true

require "test_helper"

# Plan 17-05: TournamentReflex prueft dasselbe Recht wie der Controller.
#   Teilnehmerlisten-Reflexe -> TournamentPolicy#manage_teilnehmerliste?
#   Start-Formular-Setter    -> TournamentPolicy#prepare_tournament?
#
# Muster wie game_protocol_reflex_test.rb: Reflex per .allocate (ohne WebSocket-Stack),
# element/current_user/method_name gestubbt. Aufgerufen wird ueber `process` — nur so laufen die
# before_reflex-Callbacks, ein direkter Methodenaufruf ginge an ihnen vorbei.
class TournamentReflexTest < ActiveSupport::TestCase
  PARTICIPANT_LIST_REFLEXES = %w[change_seeding change_no_show change_position move_up move_down
    change_point_goal sort_by_ranking sort_by_handicap].freeze

  setup do
    @tournament = tournaments(:local)
    @player = Player.create!(id: 50_017_051, firstname: "Rita", lastname: "Reflex", ba_id: 17_051)
    @seeding = Seeding.create!(id: 50_017_052, tournament: @tournament, player: @player, position: 1, balls_goal: 30)
  end

  def reflex_for(method_name, user:, element:)
    reflex = TournamentReflex.allocate
    reflex.define_singleton_method(:element) { element }
    reflex.define_singleton_method(:current_user) { user }
    reflex.define_singleton_method(:method_name) { method_name.to_s }
    reflex.define_singleton_method(:morph) { |*| nil }
    reflex
  end

  def point_goal_element(value)
    OpenStruct.new(dataset: {"id" => @tournament.id.to_s},
      attributes: {"id" => "seeding-#{@player.id}", "value" => value.to_s})
  end

  def balls_goal_element(value)
    OpenStruct.new(dataset: {"id" => @tournament.id.to_s}, value: value.to_s)
  end

  test "17-05 AC-5: nicht angemeldet aendert change_point_goal die Vorgabe nicht" do
    reflex = reflex_for(:change_point_goal, user: nil, element: point_goal_element(99))
    reflex.process(:change_point_goal)
    assert_equal 30, @seeding.reload.balls_goal
    assert reflex.halted?, "der Reflex wird abgebrochen"
  end

  test "17-05 AC-5: ein player ohne Bezug aendert die Vorgabe nicht" do
    reflex = reflex_for(:change_point_goal, user: users(:one), element: point_goal_element(99))
    reflex.process(:change_point_goal)
    assert_equal 30, @seeding.reload.balls_goal
  end

  test "17-05 AC-5: die Turnierleitung aendert die Vorgabe wie bisher" do
    @tournament.update_column(:turnier_leiter_user_id, users(:one).id)
    reflex = reflex_for(:change_point_goal, user: users(:one), element: point_goal_element(99))
    reflex.process(:change_point_goal)
    assert_equal 99, @seeding.reload.balls_goal
    refute reflex.halted?
  end

  test "17-05 AC-5: nicht angemeldet werden alle Teilnehmerlisten-Reflexe abgebrochen" do
    not_halted = PARTICIPANT_LIST_REFLEXES.reject do |name|
      reflex = reflex_for(name, user: nil, element: OpenStruct.new(dataset: {}, attributes: {}))
      begin
        reflex.process(name)
      rescue
        nil # am alten Code lief der Rumpf mit dem leeren Element los
      end
      reflex.halted?
    end
    assert_empty not_halted, "ohne Recht nicht abgebrochen: #{not_halted.join(", ")}"
  end

  test "17-05 AC-5: nicht angemeldet setzt der Start-Parameter-Setter nichts" do
    before = @tournament.balls_goal
    reflex = reflex_for(:balls_goal, user: nil, element: balls_goal_element(77))
    reflex.process(:balls_goal)
    assert_equal before, @tournament.reload.balls_goal
    assert reflex.halted?
  end

  test "17-05 AC-5: nicht angemeldet werden alle Start-Parameter-Setter abgebrochen" do
    not_halted = TournamentReflex::ATTRIBUTE_METHODS.keys.map(&:to_s).reject do |name|
      reflex = reflex_for(name, user: nil, element: balls_goal_element(1))
      begin
        reflex.process(name)
      rescue
        nil
      end
      reflex.halted?
    end
    assert_empty not_halted, "ohne Recht nicht abgebrochen: #{not_halted.join(", ")}"
  end

  test "17-05 AC-5: ein club_admin setzt den Start-Parameter wie bisher" do
    reflex = reflex_for(:balls_goal, user: users(:club_admin), element: balls_goal_element(77))
    reflex.process(:balls_goal)
    assert_equal 77, @tournament.reload.balls_goal
    refute reflex.halted?
  end
end
