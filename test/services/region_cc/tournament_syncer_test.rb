# frozen_string_literal: true

require "test_helper"

# Unit tests fuer RegionCc::TournamentSyncer.
# Alle HTTP-Aufrufe werden via Minitest::Mock abgefangen.
# Kein VCR — reine Unit-Tests mit injizierten Client-Doubles.
class RegionCc::TournamentSyncerTest < ActiveSupport::TestCase
  setup do
    @region_cc = RegionCc.new(cc_id: 20, shortname: "NBV")
    @client = Minitest::Mock.new
  end

  # ---------------------------------------------------------------------------
  # Test 1: sync_tournament_ccs liest showMeisterschaftenList und gibt TournamentCc-Records zurueck
  # ---------------------------------------------------------------------------
  test "sync_tournament_ccs calls post with showMeisterschaftenList action" do
    # Minimales HTML: keine Turniere, kein errMsg => leere Ergebnisliste
    stub_html = <<~HTML
      <html><body>
        <input name="errMsg" value="">
      </body></html>
    HTML

    branch_cc = BranchCc.new(cc_id: 6, name: "Karambol")
    region_cc_stub = RegionCc.new(cc_id: 20)
    region_stub = Region.new
    region_stub.define_singleton_method(:cc_id) { 20 }
    region_stub.define_singleton_method(:region_cc) { region_cc_stub }
    season = Season.new(id: 5, name: "2023/2024")
    region_cc_stub.define_singleton_method(:branch_ccs) { [branch_cc] }

    @client.expect(:post, [OpenStruct.new(message: "OK"), Nokogiri::HTML(stub_html)],
                   ["showMeisterschaftenList", Hash, Hash])

    Region.stub(:find_by_shortname, region_stub) do
      Season.stub(:find_by_name, season) do
        result = nil
        assert_nothing_raised do
          result = RegionCc::TournamentSyncer.call(
            region_cc: @region_cc, client: @client,
            operation: :sync_tournament_ccs,
            context: "nbv", season_name: "2023/2024"
          )
        end
        # Dispatcher hat den richtigen Zweig durchlaufen
        assert_kind_of Array, result
      end
    end

    @client.verify
  end

  # ---------------------------------------------------------------------------
  # Test 2: sync_tournament_series_ccs liest showSerienList
  # ---------------------------------------------------------------------------
  test "sync_tournament_series_ccs calls post with showSerienList action" do
    stub_html = <<~HTML
      <html><body>
        <select name="serienId">
        </select>
      </body></html>
    HTML

    branch_cc = BranchCc.new(cc_id: 10, name: "Karambol")
    region_cc_stub = RegionCc.new(cc_id: 20)
    region_stub = Region.new
    region_stub.define_singleton_method(:region_cc) { region_cc_stub }
    region_cc_stub.define_singleton_method(:branch_ccs) { [branch_cc] }
    season = Season.new(id: 5, name: "2023/2024")

    @client.expect(:post, [OpenStruct.new(message: "OK"), Nokogiri::HTML(stub_html)],
                   ["showSerienList", Hash, Hash])

    Region.stub(:find_by_shortname, region_stub) do
      Season.stub(:find_by_name, season) do
        result = nil
        assert_nothing_raised do
          result = RegionCc::TournamentSyncer.call(
            region_cc: @region_cc, client: @client,
            operation: :sync_tournament_series_ccs,
            context: "nbv", season_name: "2023/2024"
          )
        end
        # Dispatcher hat den richtigen Zweig durchlaufen
        assert_kind_of Array, result
      end
    end

    @client.verify
  end

  # ---------------------------------------------------------------------------
  # Test 3: fix_tournament_structure behandelt fehlendes Tournament ohne Exception
  # ---------------------------------------------------------------------------
  test "fix_tournament_structure handles missing TournamentCc gracefully" do
    season = Season.new(id: 5, name: "2023/2024")
    region = Region.new
    region.define_singleton_method(:id) { 1 }
    region.define_singleton_method(:shortname) { "NBV" }
    @region_cc.define_singleton_method(:region) { region }

    # Kein TournamentCc => error geloggt, kein Crash
    tournament = Tournament.new
    tournament.define_singleton_method(:id) { 42 }
    tournament.define_singleton_method(:title) { "Test Turnier" }
    discipline = Discipline.new
    root_discipline = Discipline.new
    root_discipline.define_singleton_method(:name) { "Karambol" }
    root_discipline.define_singleton_method(:branch_cc) { BranchCc.new(cc_id: 6) }
    discipline.define_singleton_method(:root) { root_discipline }
    tournament.define_singleton_method(:discipline) { discipline }

    tournament_scope = [tournament]
    def tournament_scope.where(*args); self end
    def tournament_scope.not(*args); self end
    def tournament_scope.to_a; self end

    Season.stub(:find_by_name, season) do
      Tournament.stub(:where, tournament_scope) do
        TournamentCc.stub(:find_by, nil) do
          # fehlendes TournamentCc wird geloggt (Rails.logger.error), kein Exception
          result = nil
          assert_nothing_raised do
            result = RegionCc::TournamentSyncer.call(
              region_cc: @region_cc, client: @client,
              operation: :fix_tournament_structure,
              season_name: "2023/2024"
            )
          end
          # Kein TournamentCc gefunden: Fehler geloggt, Schleife ueber tournaments durchlaufen
          assert_kind_of Array, result
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Test 4: Unbekannte Operation wirft ArgumentError
  # ---------------------------------------------------------------------------
  test "raises ArgumentError for unknown operation" do
    assert_raises(ArgumentError) do
      RegionCc::TournamentSyncer.call(
        region_cc: @region_cc, client: @client,
        operation: :invalid_operation
      )
    end
  end
end
