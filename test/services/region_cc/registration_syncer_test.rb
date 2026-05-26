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
      result = nil
      assert_nothing_raised do
        result = RegionCc::RegistrationSyncer.call(
          region_cc: @region_cc, client: @client,
          operation: :sync_registration_list_ccs_detail,
          season: @season, branch_cc: @branch_cc,
          context: "nbv", update_from_cc: true
        )
      end
      # Beide HTTP-Aufrufe (showMeldelistenList + showMeldeliste) wurden abgesetzt;
      # @client.verify bestätigt, dass genau diese Aufrufe gemacht wurden
      assert_not_nil result
    end

    @client.verify
  end

  # ---------------------------------------------------------------------------
  # Test 1b: Status-Hardcoded-Bug-Fix (Plan 21-06 T1, D-21-05-F → D-21-06-C)
  # Persistiert den geparseden status-Wert (Zeile 98) statt hardcoded "Freigegeben".
  # ---------------------------------------------------------------------------
  test "persists parsed status value instead of hardcoded 'Freigegeben' (D-21-06-C)" do
    list_html = <<~HTML
      <html><body>
        <select name="meldelisteId">
          <option value="99999">Test ML mit Gemeldet-Status</option>
        </select>
      </body></html>
    HTML

    # HTML-Detail mit Status-Zelle, die "Gemeldet" liefert (nicht "Freigegeben").
    # Der Syncer parst tr.css("td")[0].text auf "Status"-Header; tr.css("td")[2].text liefert den Wert.
    detail_html = <<~HTML
      <html><body>
        <table><tr class="tableContent"><td><table>
          <tr><td>Meldeliste</td><td></td><td>Test ML 21-06</td></tr>
          <tr><td>Status</td><td></td><td>Gemeldet</td></tr>
        </table></td></tr></table>
      </body></html>
    HTML

    @client.expect(:post, [OpenStruct.new(message: "OK"), Nokogiri::HTML(list_html)],
      ["showMeldelistenList", Hash, Hash])
    @client.expect(:post, [OpenStruct.new(message: "OK"), Nokogiri::HTML(detail_html)],
      ["showMeldeliste", Hash, Hash])

    captured_args = nil
    registration_list_cc = RegistrationListCc.new
    registration_list_cc.define_singleton_method(:new_record?) { true }
    registration_list_cc.define_singleton_method(:update) { |args|
      captured_args = args
      true
    }
    registration_list_cc.define_singleton_method(:cc_id) { 99_999 }

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

    assert_not_nil captured_args, "update muss mit Args aufgerufen worden sein"
    assert_equal "Gemeldet", captured_args[:status],
      "Bug-Fix (D-21-06-C): parsed status muss persistiert werden, NICHT hardcoded 'Freigegeben'"
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

  # ===========================================================================
  # Plan 14-G.14 Task 4: push_link_to_api Tests
  # ===========================================================================
  class PushLinkToApiTest < ActiveSupport::TestCase
    setup do
      RegionCc::RegistrationSyncer.reset_api_token!

      @api_url = "https://api.example.test"
      @api_origin = Carambus.config.respond_to?(:carambus_api_url) ? Carambus.config.carambus_api_url : nil
      # Carambus.config.carambus_api_url ist OpenStruct — wir stubben via Stub
      Carambus.config.define_singleton_method(:carambus_api_url) { "https://api.example.test" } unless Carambus.config.carambus_api_url

      @tournament_cc = Minitest::Mock.new
      @tournament_cc.expect(:id, 12345)
      def @tournament_cc.tournament
        OpenStruct.new(region: OpenStruct.new(shortname: "NBV"))
      end

      @registration_list_cc = OpenStruct.new(
        cc_id: 999_001, name: "Test Meldeliste",
        branch_cc_id: 8, season: OpenStruct.new(name: "2025/2026"),
        discipline_id: 58, category_cc_id: nil
      )
    end

    teardown do
      RegionCc::RegistrationSyncer.reset_api_token!
    end

    test "push_link_to_api with no carambus_api_url configured does nothing" do
      Carambus.config.stub(:carambus_api_url, nil) do
        assert_nothing_raised do
          RegionCc::RegistrationSyncer.push_link_to_api(@tournament_cc, @registration_list_cc)
        end
      end
    end

    test "push_link_to_api with no credentials configured logs warn and skips" do
      Rails.application.credentials.stub(:api_syncer_email, nil) do
        Rails.application.credentials.stub(:api_syncer_password, nil) do
          assert_nothing_raised do
            RegionCc::RegistrationSyncer.push_link_to_api(@tournament_cc, @registration_list_cc)
          end
        end
      end
    end

    test "push_link_to_api with 200 response triggers apply_response_unprotected" do
      stub_request(:post, "https://api.example.test/login")
        .to_return(status: 200, headers: {"Authorization" => "Bearer test-jwt"})

      stub_request(:patch, "https://api.example.test/api/tournament_ccs/12345/registration_list_link")
        .with(headers: {"Authorization" => "Bearer test-jwt"})
        .to_return(
          status: 200,
          body: {tournament_cc: {id: 12345, registration_list_cc_id: 9999}, registration_list_cc: {id: 9999, cc_id: 999_001, name: "X"}}.to_json,
          headers: {"Content-Type" => "application/json"}
        )

      Rails.application.credentials.stub(:api_syncer_email, "syncer@test.de") do
        Rails.application.credentials.stub(:api_syncer_password, "secret") do
          RegionCc::RegistrationSyncer.stub(:apply_response_unprotected, ->(_json) { :applied }) do
            assert_nothing_raised do
              RegionCc::RegistrationSyncer.push_link_to_api(@tournament_cc, @registration_list_cc)
            end
          end
        end
      end
    end

    test "push_link_to_api with 401 retries once with fresh token" do
      RegionCc::RegistrationSyncer.reset_api_token!

      login_count = 0
      stub_request(:post, "https://api.example.test/login")
        .to_return do
          login_count += 1
          {status: 200, headers: {"Authorization" => "Bearer fresh-jwt-#{login_count}"}}
        end

      patch_count = 0
      stub_request(:patch, "https://api.example.test/api/tournament_ccs/12345/registration_list_link")
        .to_return do
          patch_count += 1
          if patch_count == 1
            {status: 401, body: {error: "Unauthorized"}.to_json}
          else
            {status: 200, body: {tournament_cc: {}, registration_list_cc: {}}.to_json}
          end
        end

      Rails.application.credentials.stub(:api_syncer_email, "syncer@test.de") do
        Rails.application.credentials.stub(:api_syncer_password, "secret") do
          RegionCc::RegistrationSyncer.stub(:apply_response_unprotected, ->(_json) { :applied }) do
            RegionCc::RegistrationSyncer.push_link_to_api(@tournament_cc, @registration_list_cc)
          end
        end
      end

      assert_equal 2, patch_count, "PATCH muss 2× gerufen werden (initial + retry nach 401)"
      assert_equal 2, login_count, "POST /login muss 2× gerufen werden (initial + after reset_api_token!)"
    end

    test "push_link_to_api on network exception logs and does not crash" do
      stub_request(:post, "https://api.example.test/login")
        .to_return(status: 200, headers: {"Authorization" => "Bearer test-jwt"})
      stub_request(:patch, "https://api.example.test/api/tournament_ccs/12345/registration_list_link")
        .to_raise(Errno::ECONNREFUSED)

      Rails.application.credentials.stub(:api_syncer_email, "syncer@test.de") do
        Rails.application.credentials.stub(:api_syncer_password, "secret") do
          assert_nothing_raised do
            RegionCc::RegistrationSyncer.push_link_to_api(@tournament_cc, @registration_list_cc)
          end
        end
      end
    end
  end
end
