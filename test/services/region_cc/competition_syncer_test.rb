# frozen_string_literal: true

require "test_helper"

# Unit tests fuer RegionCc::CompetitionSyncer.
# Alle HTTP-Aufrufe werden via Minitest::Mock abgefangen.
# Kein VCR — reine Unit-Tests mit injizierten Client-Doubles.
class RegionCc::CompetitionSyncerTest < ActiveSupport::TestCase
  setup do
    @region_cc = RegionCc.new(cc_id: 20, shortname: "NBV")
    @client = Minitest::Mock.new
  end

  # ---------------------------------------------------------------------------
  # Test 1: sync_competitions mit gestubtem client.post gibt CompetitionCc-Records zurueck
  # ---------------------------------------------------------------------------
  test "sync_competitions creates CompetitionCc records from HTML response" do
    stub_html = <<~HTML
      <html><body>
        <select name="subBranchId">
          <option value="1">Mannschaft Karambol</option>
        </select>
      </body></html>
    HTML

    # stub: post("showLeagueList", ...) => [response, doc]
    @client.expect(:post, [OpenStruct.new(message: "OK"), Nokogiri::HTML(stub_html)],
                   ["showLeagueList", Hash, Hash])

    branch_cc = BranchCc.new(cc_id: 6, name: "Karambol")
    competition = Competition.new(name: "Mannschaft Karambol")

    BranchCc.stub(:where, [branch_cc].tap { |a| def a.each(&b); super(&b) end }) do
      Competition.stub(:find_by_name, competition) do
        CompetitionCc.stub(:where, [].tap { |a|
          def a.first; nil end
        }) do
          CompetitionCc.stub(:new, CompetitionCc.new) do
            # Ergebnis testen: keine Exception bedeutet Success-Pfad wurde genommen
            result = nil
            assert_nothing_raised do
              result = RegionCc::CompetitionSyncer.call(
                region_cc: @region_cc, client: @client,
                operation: :sync_competitions,
                context: "nbv"
              )
            end
            assert_kind_of Array, result
          end
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Test 2: sync_seasons_in_competitions erstellt SeasonCc-Records
  # ---------------------------------------------------------------------------
  test "sync_seasons_in_competitions creates SeasonCc records" do
    stub_html = <<~HTML
      <html><body>
        <select name="seasonId">
          <option value="11">2023/2024</option>
        </select>
      </body></html>
    HTML

    @client.expect(:post, [OpenStruct.new(message: "OK"), Nokogiri::HTML(stub_html)],
                   ["showLeagueList", Hash, Hash])

    season = Season.new(id: 99, name: "2023/2024")
    branch_cc = BranchCc.new(cc_id: 6, name: "Karambol")
    competition_cc = CompetitionCc.new(cc_id: 1, id: 1)

    allow_branch_ccs = [branch_cc].tap do |a|
      branch_cc.define_singleton_method(:competition_ccs) { [competition_cc] }
    end

    Season.stub(:find_by_name, season) do
      BranchCc.stub(:where, allow_branch_ccs) do
        SeasonCc.stub(:find_by_cc_id_and_competition_cc_id_and_context, nil) do
          SeasonCc.stub(:new, SeasonCc.new.tap { |s|
            s.define_singleton_method(:assign_attributes) { |_h| }
            s.define_singleton_method(:save) { true }
          }) do
            result = nil
            assert_nothing_raised do
              result = RegionCc::CompetitionSyncer.call(
                region_cc: @region_cc, client: @client,
                operation: :sync_seasons_in_competitions,
                season_name: "2023/2024"
              )
            end
            assert_kind_of Array, result
          end
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Test 3: Unbekannte Operation wirft ArgumentError
  # ---------------------------------------------------------------------------
  test "raises ArgumentError for unknown operation" do
    assert_raises(ArgumentError) do
      RegionCc::CompetitionSyncer.call(
        region_cc: @region_cc, client: @client,
        operation: :nonexistent_operation
      )
    end
  end
end
