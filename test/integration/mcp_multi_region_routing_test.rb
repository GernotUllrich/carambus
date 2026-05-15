# frozen_string_literal: true

require "test_helper"

# v0.3 Plan 13-06 (Plan-13-04.1-Verify): Integration-Test für Multi-Region-Routing.
# Verifiziert dass server_context[:cc_region] vom McpController durch server_context
# bis CcSession.client_for propagiert und die richtige region.region_cc.base_url
# gewählt wird.
class McpMultiRegionRoutingTest < ActionDispatch::IntegrationTest
  setup do
    @prev_mock = ENV["CARAMBUS_MCP_MOCK"]
    @prev_env_region = ENV["CC_REGION"]
    ENV["CARAMBUS_MCP_MOCK"] = nil
    ENV.delete("CC_REGION")
    McpServer::CcSession.reset!
    McpServer::CcSession._client_override = nil
  end

  teardown do
    ENV["CARAMBUS_MCP_MOCK"] = @prev_mock
    ENV["CC_REGION"] = @prev_env_region
    McpServer::CcSession.reset!
  end

  test "region_cc_base_url: BVBW vs NBV server_context liefert verschiedene base_urls (oder nil falls Region nicht in test-DB)" do
    bvbw_url = McpServer::CcSession.region_cc_base_url({})
    nbv_url = McpServer::CcSession.region_cc_base_url({})
    assert(bvbw_url.is_a?(String) || bvbw_url.nil?)
    assert(nbv_url.is_a?(String) || nbv_url.nil?)
    if bvbw_url && nbv_url
      refute_equal bvbw_url, nbv_url, "BVBW + NBV region_cc.base_url müssen unterschiedlich sein"
    end
  end

  test "client_for: server_context cc_region propagiert in region_cc_base_url-Call (via stub-Spy)" do
    captured_context = nil
    McpServer::CcSession.singleton_class.send(:alias_method, :_orig_base_url_p13_06, :region_cc_base_url)
    begin
      McpServer::CcSession.singleton_class.send(:define_method, :region_cc_base_url) do |ctx|
        captured_context = ctx
        "https://test-stub.example.org"
      end
      McpServer::CcSession.client_for({ user_id: 42,})
      assert_equal({ user_id: 42,}, captured_context)
    ensure
      McpServer::CcSession.singleton_class.send(:alias_method, :region_cc_base_url, :_orig_base_url_p13_06)
      McpServer::CcSession.singleton_class.send(:remove_method, :_orig_base_url_p13_06)
    end
  end

  test "User.mcp_cc_region: User.cc_region overrides ENV (Plan-13-02-Helper-Verify)" do
    skip "Pending 14-G.2 (D-14-G6: users.cc_region + mcp_cc_region entfernt; Region via Carambus.config.region_id)"
  end

  test "Plan-14-02.1-fix: effective_cc_region strict — nur server_context, kein ENV-Fallback" do
    skip "Pending 14-G.2 (D-14-G3: effective_cc_region-Chain ändert sich; Quelle = Carambus.config.region_id)"
  end
end
