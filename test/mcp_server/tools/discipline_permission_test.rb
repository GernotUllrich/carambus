# frozen_string_literal: true

require "test_helper"

# Plan 23-01 T4: Tests für BaseTool.discipline_permission? — transitiver
# Permission-Check via Discipline-Hierarchie.
#
# Eigene Test-Datei (statt base_tool_test.rb), weil dort ein pre-existing
# RSpec-Style-Load-Bug an Zeile 466 das ganze File beim Boot crashen lässt.
class McpServer::Tools::DisciplinePermissionTest < ActiveSupport::TestCase
  setup do
    @root = Discipline.create!(name: "DP4-Karambol")
    @mid = Discipline.create!(name: "DP4-Dreiband", super_discipline: @root)
    @leaf = Discipline.create!(name: "DP4-Dreiband-groß", super_discipline: @mid)
    @unrelated = Discipline.create!(name: "DP4-Pool")
  end

  teardown do
    [@leaf, @mid, @root, @unrelated].compact.each(&:destroy)
  end

  test "user ohne sportwart_disciplines → false (deny)" do
    user = stub_user(disciplines: [])
    refute McpServer::Tools::BaseTool.discipline_permission?(user, @leaf)
  end

  test "user mit Karambol-Permission darf Dreiband-groß (transitive Vererbung)" do
    user = stub_user(disciplines: [@root])
    assert McpServer::Tools::BaseTool.discipline_permission?(user, @leaf),
      "User mit root-Discipline muss auch Sub-Disziplinen erlaubt sein"
  end

  test "user mit Dreiband-Permission darf Dreiband-groß (mittlere Stufe)" do
    user = stub_user(disciplines: [@mid])
    assert McpServer::Tools::BaseTool.discipline_permission?(user, @leaf)
  end

  test "user mit Pool-Permission darf NICHT Dreiband-groß" do
    user = stub_user(disciplines: [@unrelated])
    refute McpServer::Tools::BaseTool.discipline_permission?(user, @leaf),
      "Permission von einer anderen Disziplin-Hierarchie muss blocken"
  end

  test "Permission-Check via Tournament-Objekt (mit .discipline)" do
    tournament_stub = Struct.new(:discipline).new(@leaf)
    user = stub_user(disciplines: [@root])
    assert McpServer::Tools::BaseTool.discipline_permission?(user, tournament_stub)
  end

  test "user=nil → false (defensive)" do
    refute McpServer::Tools::BaseTool.discipline_permission?(nil, @leaf)
  end

  test "discipline=nil → false (defensive)" do
    user = stub_user(disciplines: [@root])
    refute McpServer::Tools::BaseTool.discipline_permission?(user, nil)
  end

  private

  def stub_user(disciplines:)
    Struct.new(:sportwart_disciplines).new(MockRelation.new(disciplines))
  end

  # Mock-Relation, die `.pluck(:id)` versteht (genug für discipline_permission?).
  class MockRelation
    def initialize(records)
      @records = records
    end

    def pluck(field)
      @records.map(&field)
    end
  end
end
