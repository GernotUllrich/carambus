# frozen_string_literal: true

require "test_helper"
require "json"
require "open3"

# End-to-end Stdio-Integrationstest (D-16). Spawnt den echten bin/mcp-server als Subprocess
# und tauscht JSON-RPC-Nachrichten über STDIN/STDOUT aus.
# Langsam (~5s Rails-Boot pro Run); ist der Phase-40-Abschluss-Integrationstest.

module McpServer
  module Integration
  end
end

class McpServer::Integration::StdioE2ETest < ActiveSupport::TestCase
  BOOT_TIMEOUT_SECONDS = 30

  setup do
    @env = ENV.to_h.merge(
      "CARAMBUS_MCP_MOCK" => "1",
      "CC_USERNAME" => "test",
      "CC_PASSWORD" => "test",
      "CC_FED_ID" => "20",
      "RAILS_ENV" => "test"
    )
    @mcp_server_path = Rails.root.join("bin/mcp-server").to_s
  end

  def with_server
    Open3.popen2e(@env, @mcp_server_path) do |stdin, stdout_err, wait_thr|
      yield(stdin, stdout_err)
    ensure
      begin
        stdin.close
      rescue
        nil
      end
      begin
        Process.kill("TERM", wait_thr.pid)
      rescue
        nil
      end
      wait_thr.join(5)
    end
  end

  def send_jsonrpc(stdin, id:, method:, params: {})
    stdin.puts({jsonrpc: "2.0", id: id, method: method, params: params}.to_json)
    stdin.flush
  end

  def read_jsonrpc(stdout_err)
    # Nicht-JSON-Zeilen überspringen (z.B. Rails-Boot-Warnungen im STDERR-gemischten Stream).
    BOOT_TIMEOUT_SECONDS.times do
      line = stdout_err.gets
      next if line.nil? || line.strip.empty?
      begin
        return JSON.parse(line)
      rescue JSON::ParserError
        next
      end
    end
    flunk "Keine gültige JSON-RPC-Antwort innerhalb des Timeouts erhalten"
  end

  test "executable bit guard (RESEARCH Open Question §5 RESOLVED)" do
    # Lokaler + Capistrano-Deploy-Guard — bin/mcp-server MUSS 0755 haben.
    # Plan 06 Task 4 fügt den Capistrano-Hook hinzu; dieser Test erkennt lokalen Checkout-Drift.
    path = Rails.root.join("bin/mcp-server")
    assert File.exist?(path), "bin/mcp-server fehlt"
    assert File.executable?(path), "bin/mcp-server ist nicht ausführbar (mode ist #{File.stat(path).mode.to_s(8)})"
  end

  test "initialize handshake — server identifies as carambus_clubcloud" do
    skip "E2E-Test benötigt Rails-Boot; auf CI wegen Performance übersprungen" if ENV["CI"]
    with_server do |stdin, stdout|
      send_jsonrpc(stdin, id: 1, method: "initialize", params: {
        protocolVersion: "2024-11-05",
        capabilities: {},
        clientInfo: {name: "test-client", version: "1.0"}
      })
      response = read_jsonrpc(stdout)
      assert_equal "carambus_clubcloud", response.dig("result", "serverInfo", "name"),
        "Server-Name stimmt nicht: #{response.inspect}"
    end
  end

  test "tools/list — all 11 expected tools registered" do
    skip "E2E-Test benötigt Rails-Boot; auf CI wegen Performance übersprungen" if ENV["CI"]
    with_server do |stdin, stdout|
      send_jsonrpc(stdin, id: 1, method: "initialize", params: {
        protocolVersion: "2024-11-05", capabilities: {}, clientInfo: {name: "test", version: "1.0"}
      })
      read_jsonrpc(stdout)  # init-Response konsumieren

      send_jsonrpc(stdin, id: 2, method: "tools/list")
      response = read_jsonrpc(stdout)
      tool_names = response.dig("result", "tools").map { |t| t["name"] }
      %w[cc_lookup_region cc_lookup_teilnehmerliste cc_search_player cc_finalize_teilnehmerliste].each do |name|
        assert_includes tool_names, name, "tools/list fehlt #{name}"
      end
      assert_operator tool_names.size, :>=, 11
    end
  end

  test "resources/list — workflow + api resources present" do
    skip "E2E-Test benötigt Rails-Boot; auf CI wegen Performance übersprungen" if ENV["CI"]
    with_server do |stdin, stdout|
      send_jsonrpc(stdin, id: 1, method: "initialize", params: {
        protocolVersion: "2024-11-05", capabilities: {}, clientInfo: {name: "test", version: "1.0"}
      })
      read_jsonrpc(stdout)

      send_jsonrpc(stdin, id: 2, method: "resources/list")
      response = read_jsonrpc(stdout)
      uris = response.dig("result", "resources").map { |r| r["uri"] }
      assert_includes uris, "cc://workflow/scenarios/teilnehmerliste-finalisieren"
      assert_includes uris, "cc://workflow/roles"
      assert(uris.any? { |u| u.start_with?("cc://api/") }, "Keine cc://api/ Resources gefunden")
      assert_operator uris.size, :>=, 20  # 5 workflow + 15 api = mindestens 20
    end
  end

  test "tools/call — cc_finalize_teilnehmerliste dry-run (D-19)" do
    skip "E2E-Test benötigt Rails-Boot; auf CI wegen Performance übersprungen" if ENV["CI"]
    with_server do |stdin, stdout|
      send_jsonrpc(stdin, id: 1, method: "initialize", params: {
        protocolVersion: "2024-11-05", capabilities: {}, clientInfo: {name: "test", version: "1.0"}
      })
      read_jsonrpc(stdout)

      send_jsonrpc(stdin, id: 2, method: "tools/call", params: {
        name: "cc_finalize_teilnehmerliste",
        arguments: {fed_id: 20, branch_id: 10, season: "2025/2026", meldeliste_id: 42}
      })
      response = read_jsonrpc(stdout)
      # Dry-run: kein Fehler, Content enthält "Would finalize"
      refute response.dig("result", "isError"), "Tool hat unerwartet einen Fehler geworfen: #{response.inspect}"
      combined_text = response.dig("result", "content").map { |c| c["text"] }.join(" ")
      assert_match(/Would finalize Meldeliste 42/, combined_text)
    end
  end

  test "invalid JSON probe returns -32700 Parse error (RESEARCH Open Question §1 RESOLVED)" do
    skip "E2E-Test benötigt Rails-Boot; auf CI wegen Performance übersprungen" if ENV["CI"]
    # Einen fehlerhaften JSON-Frame pipen, SDK muss JSON-RPC Parse-Error-Envelope zurückgeben
    # ohne den Server-Loop zum Absturz zu bringen.
    with_server do |stdin, stdout|
      stdin.puts "{garbage not json"
      stdin.flush
      response = read_jsonrpc(stdout)
      # Per JSON-RPC 2.0 Spec § Error Codes:
      # -32700 Parse error  | Ungültiges JSON vom Client empfangen
      assert_equal(-32700, response.dig("error", "code"),
        "SDK muss -32700 Parse error Envelope für ungültiges JSON zurückgeben; erhalten: #{response.inspect}")
    end
  end
end
