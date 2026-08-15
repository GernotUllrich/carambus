# frozen_string_literal: true

require "test_helper"

# Charakterisierungs-Tests fuer die name-basierte Recency-Logik.
# Hintergrund: id/ba_id sind durch das Scrapen internationaler Turniere verrutscht;
# NUR der Name "yyyy/yyyy+1" ist verlaesslich. Platzhalter/Fremd-Saisons ("Unknown Season")
# haben ungueltige Namen / ba_id = nil und duerfen NIE als "aktuellste/vorige" Saison gelten.
class SeasonTest < ActiveSupport::TestCase
  # Fixtures: current=2025/2026 (id 50_000_001), previous=2024/2025, season_2024=2023/2024
  setup do
    @current = seasons(:current)      # "2025/2026"
    @previous = seasons(:previous)    # "2024/2025"
    @s2024 = seasons(:season_2024)    # "2023/2024"
  end

  test "with_valid_name schliesst Platzhalter-/Fremd-Saisons aus" do
    junk = Season.create!(name: "Unknown Season", ba_id: nil)
    future_stub = Season.create!(name: "2030/2031 (leer)", ba_id: nil)

    names = Season.with_valid_name.pluck(:name)
    assert_includes names, @current.name
    refute_includes names, junk.name
    refute_includes names, future_stub.name
  end

  test "recent_valid liefert die neuesten n gueltigen Saisons chronologisch aufsteigend" do
    Season.create!(name: "Unknown Season", ba_id: nil) # darf nicht auftauchen

    result = Season.recent_valid(2, up_to: @current)
    assert_equal [@previous.name, @current.name], result.map(&:name)
    # aeltere-zuerst: die juengste (= up_to) steht am Ende
    assert_equal @current.name, result.last.name
  end

  test "recent_valid begrenzt ueber up_to (schliesst neuere Saisons aus)" do
    result = Season.recent_valid(3, up_to: @previous)
    # nur Saisons <= 2024/2025
    assert_equal [@s2024.name, @previous.name], result.map(&:name)
    refute_includes result.map(&:name), @current.name
  end

  test "previous leitet die Vorsaison ueber den Namen ab (nicht ueber ba_id)" do
    # ba_id bewusst irrefuehrend gesetzt, um zu beweisen dass NICHT ba_id genutzt wird
    @current.update_column(:ba_id, 999)
    assert_equal @previous.name, @current.previous&.name
  end

  test "next_season leitet die Folgesaison ueber den Namen ab" do
    @previous.update_column(:ba_id, 111)
    assert_equal @current.name, @previous.next_season&.name
  end

  test "previous ist nil, wenn keine Vorsaison existiert und ba_id fehlt" do
    orphan = Season.create!(name: "Unknown Season", ba_id: nil)
    assert_nil orphan.previous
  end
end
