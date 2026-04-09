# frozen_string_literal: true

require "test_helper"

# Unit tests fuer RegionCc::RegistrationSyncer.
# Alle HTTP-Aufrufe werden via Minitest::Mock abgefangen.
# Kein VCR — reine Unit-Tests mit injizierten Client-Doubles.
class RegionCc::RegistrationSyncerTest < ActiveSupport::TestCase
  setup do
    @region_cc = RegionCc.new(cc_id: 20, shortname: "NBV")
    @client = Minitest::Mock.new
    @season = Season.new(id: 5, name: "2023/2024")
    @branch_cc = BranchCc.new(cc_id: 10, id: 1)
  end

  # ---------------------------------------------------------------------------
  # Test 1: sync_registration_list_ccs_detail erstellt RegistrationListCc-Records
  # ---------------------------------------------------------------------------
  test "sync_registration_list_ccs_detail creates RegistrationListCc from HTML response" do
    list_html = <<~HTML
      <html><body>
        <select name="meldelisteId">
          <option value="66">5. Petit Prix Einband</option>
        </select>
      </body></html>
    HTML

    detail_html = <<~HTML
      <html><body>
        <table><tr class="tableContent"><td><table><tr>
          <td>Meldeliste</td><td></td><td>Test Meldeliste</td>
        </tr></table></td></tr></table>
      </body></html>
    HTML

    @client.expect(:post, [OpenStruct.new(message: "OK"), Nokogiri::HTML(list_html)],
                   ["showMeldelistenList", Hash, Hash])
    @client.expect(:post, [OpenStruct.new(message: "OK"), Nokogiri::HTML(detail_html)],
                   ["showMeldeliste", Hash, Hash])

    registration_list_cc = RegistrationListCc.new
    registration_list_cc.define_singleton_method(:new_record?) { true }
    registration_list_cc.define_singleton_method(:update) { |_args| true }
    registration_list_cc.define_singleton_method(:cc_id) { 66 }

    RegistrationListCc.stub(:find_or_initialize_by, registration_list_cc) do
      assert_nothing_raised do
        RegionCc::RegistrationSyncer.call(
          region_cc: @region_cc, client: @client,
          operation: :sync_registration_list_ccs_detail,
          season: @season, branch_cc: @branch_cc,
          context: "nbv", update_from_cc: true
        )
      end
    end

    @client.verify
  end

  # ---------------------------------------------------------------------------
  # Test 2: Unbekannte Operation wirft ArgumentError
  # ---------------------------------------------------------------------------
  test "raises ArgumentError for unknown operation" do
    assert_raises(ArgumentError) do
      RegionCc::RegistrationSyncer.call(
        region_cc: @region_cc, client: @client,
        operation: :unknown_operation
      )
    end
  end
end
