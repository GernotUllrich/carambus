# frozen_string_literal: true
require "test_helper"

# Tests für cc_finalize_teilnehmerliste (D-19 proof write tool).
# SDK-API Kontrakt (Plan 01 Task 3 verifiziert): response.error? (Predicate!), NICHT response.error.
class McpServer::Tools::FinalizeTeilnehmerlisteTest < ActiveSupport::TestCase
  setup do
    # Keine echte CC-Verbindung: _client_override + vorab gesetzte Session umgehen den Real-Login-Pfad.
    # mock_mode? bleibt aus (ENV["CARAMBUS_MCP_MOCK"] != "1"), damit _client_override auch zurückgegeben wird.
    McpServer::CcSession.reset!
    McpServer::CcSession.session_id = "TEST_SESSION_ID"
    McpServer::CcSession.session_started_at = Time.now
    @mock = McpServer::Tools::MockClient.new
    McpServer::CcSession._client_override = @mock
  end

  teardown do
    McpServer::CcSession._client_override = nil
    McpServer::CcSession.reset!
  end

  test "dry-run (armed: false default) returns 'would finalize' text ohne CC-Mutation" do
    response = McpServer::Tools::FinalizeTeilnehmerliste.call(
      fed_id: 20, branch_id: 10, season: "2025/2026", meldeliste_id: 42,
      server_context: nil
    )
    refute response.error?
    assert_match(/Would finalize Meldeliste 42/, response.content.first[:text])
    # MockClient wurde aufgerufen, opts[:armed] war blank (d.h. dry-run-Konvention honoriert)
    assert @mock.calls.any? { |verb, action, _params, opts| verb == :post && action == "releaseMeldeliste" && opts[:armed].blank? }
  end

  test "armed: true mit mock-success gibt 'Finalized' text zurück" do
    response = McpServer::Tools::FinalizeTeilnehmerliste.call(
      fed_id: 20, branch_id: 10, season: "2025/2026", meldeliste_id: 42, armed: true,
      server_context: nil
    )
    refute response.error?
    assert_match(/Finalized Meldeliste 42/, response.content.first[:text])
  end

  test "Validierung: fehlende meldeliste_id gibt error mit Parameternamen zurück" do
    response = McpServer::Tools::FinalizeTeilnehmerliste.call(
      fed_id: 20, branch_id: 10, season: "2025/2026",
      server_context: nil
    )
    assert response.error?
    assert_match(/Missing required parameter/i, response.content.first[:text])
    assert_match(/meldeliste_id/, response.content.first[:text])
  end

  test "D-11 Role-Error-Parsing: error-div in CC-Response wird als MCP-Error zurückgegeben" do
    error_doc = Nokogiri::HTML('<html><body><div class="error">Permission denied: requires Club-Sportwart</div></body></html>')
    @mock.define_singleton_method(:post) do |action, params, opts|
      [Struct.new(:code, :message, :body).new("200", "OK", ""), error_doc]
    end

    response = McpServer::Tools::FinalizeTeilnehmerliste.call(
      fed_id: 20, branch_id: 10, season: "2025/2026", meldeliste_id: 42, armed: true,
      server_context: nil
    )
    assert response.error?
    assert_match(/CC rejected.*Permission denied/, response.content.first[:text])
  end

  test "D-11 Login-Redirect löst Reauth + Retry aus" do
    login_doc   = Nokogiri::HTML('<html><body><form action="/login.php"><input/></form></body></html>')
    success_doc = Nokogiri::HTML("<html><body><table>OK</table></body></html>")
    ok_response = Struct.new(:code, :message, :body).new("200", "OK", "")
    call_count = 0
    @mock.define_singleton_method(:post) do |action, params, opts|
      call_count += 1
      if call_count == 1
        [ok_response, login_doc]
      else
        [ok_response, success_doc]
      end
    end

    # Stub reauth_if_needed! damit kein echter CC-Login ausgelöst wird (test env hat keine CC-Credentials).
    # Simuliert transparentes Reauth: gibt true zurück wenn Login-Redirect erkannt, setzt Session-ID neu.
    original_reauth = McpServer::CcSession.method(:reauth_if_needed!)
    McpServer::CcSession.define_singleton_method(:reauth_if_needed!) do |doc|
      if doc.respond_to?(:css) && doc.css("form[action*='login']").any?
        self.session_id = "REAUTHED_SESSION_ID"
        self.session_started_at = Time.now
        true
      else
        false
      end
    end

    begin
      response = McpServer::Tools::FinalizeTeilnehmerliste.call(
        fed_id: 20, branch_id: 10, season: "2025/2026", meldeliste_id: 42, armed: true,
        server_context: nil
      )
      refute response.error?
      assert_match(/Finalized Meldeliste 42/, response.content.first[:text])
      assert_equal 2, call_count, "Erwarte genau einen Reauth-Retry"
    ensure
      McpServer::CcSession.define_singleton_method(:reauth_if_needed!, original_reauth)
    end
  end

  test "Defensiv: StandardError in client.post gibt error envelope ohne stacktrace zurück" do
    @mock.define_singleton_method(:post) do |*_|
      raise RuntimeError, "simulated network failure"
    end

    response = McpServer::Tools::FinalizeTeilnehmerliste.call(
      fed_id: 20, branch_id: 10, season: "2025/2026", meldeliste_id: 42, armed: true,
      server_context: nil
    )
    assert response.error?
    assert_match(/Tool exception: RuntimeError/, response.content.first[:text])
    refute_match(/backtrace|line \d+/i, response.content.first[:text])
  end
end
