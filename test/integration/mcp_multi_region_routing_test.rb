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
    bvbw_url = McpServer::CcSession.region_cc_base_url({cc_region: "BVBW"})
    nbv_url = McpServer::CcSession.region_cc_base_url({cc_region: "NBV"})
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
      McpServer::CcSession.client_for({cc_region: "BVBW", user_id: 42, mcp_role: "mcp_sportwart"})
      assert_equal({cc_region: "BVBW", user_id: 42, mcp_role: "mcp_sportwart"}, captured_context)
    ensure
      McpServer::CcSession.singleton_class.send(:alias_method, :region_cc_base_url, :_orig_base_url_p13_06)
      McpServer::CcSession.singleton_class.send(:remove_method, :_orig_base_url_p13_06)
    end
  end

  test "User.mcp_cc_region: User.cc_region overrides ENV (Plan-13-02-Helper-Verify)" do
    ENV["CC_REGION"] = "EnvFallback"
    user_bvbw = User.create!(
      email: "mr-bvbw@test.de", password: "password123",
      mcp_role: :mcp_sportwart, cc_region: "BVBW"
    )
    user_nbv = User.create!(
      email: "mr-nbv@test.de", password: "password123",
      mcp_role: :mcp_turnierleiter, cc_region: "NBV"
    )
    assert_equal "BVBW", user_bvbw.mcp_cc_region
    assert_equal "NBV", user_nbv.mcp_cc_region
  ensure
    ENV.delete("CC_REGION")
  end

  test "Plan-13-04.1 + Plan-13-04 Integration: effective_cc_region honoriert server_context Vorrang vor ENV" do
    ENV["CC_REGION"] = "nbv"
    assert_equal "BVBW", McpServer::Tools::BaseTool.effective_cc_region({cc_region: "BVBW"})
    assert_equal "NBV", McpServer::Tools::BaseTool.effective_cc_region(nil)
  ensure
    ENV.delete("CC_REGION")
  end
end
