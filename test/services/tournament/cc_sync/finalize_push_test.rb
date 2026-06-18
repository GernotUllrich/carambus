# frozen_string_literal: true

require "test_helper"

# Plan 44-03: Unit-Tests für den MCP-freien Finalize-Push (releaseMeldeliste).
# Stub-Idiom wie accreditation_push_test: CcAccountResolver + resolve_scope_filters stubben,
# Recording-Client über CcSession._client_override. Kein echter HTTP-Call.
class Tournament::CcSync::FinalizePushTest < ActiveSupport::TestCase
  Assign = McpServer::Tools::AssignPlayerToTeilnehmerliste

  TcDouble = Struct.new(:cc_id, :season, :meldeliste_cc_id)
  TournamentDouble = Struct.new(:tournament_cc, :id)

  class RecordingClient
    attr_reader :posts

    def initialize(code: "200")
      @posts = []
      @code = code
    end

    def post(action, payload, opts)
      @posts << [action, payload, opts]
      [Struct.new(:code, :message, :body).new(@code, "OK", "ok"),
        Nokogiri::HTML("<html><body>ok</body></html>")]
    end
  end

  def own_account
    McpServer::CcAccountResolver::CcAccount.new(
      login_username: "tl_login", password: "secret", source: :own, acting_user_id: 42
    )
  end

  def none_account
    McpServer::CcAccountResolver::CcAccount.new(source: :none, acting_user_id: 42)
  end

  SCOPE = {fedId: 20, branchId: 10, season: "2025/2026", disciplinId: "*", catId: "*"}.freeze

  def run_finalize(account: nil, tc: TcDouble.new(939, "2025/2026", 1347), client: nil)
    account ||= own_account
    client ||= RecordingClient.new
    McpServer::CcSession._client_override = client
    result = nil
    McpServer::CcAccountResolver.stub(:resolve, account) do
      Assign.stub(:resolve_scope_filters, SCOPE) do
        McpServer::CcSession.stub(:cookie_for, "TEST_COOKIE") do
          result = Tournament::CcSync::FinalizePush.call(
            tournament: TournamentDouble.new(tc, 1), acting_user: Object.new
          )
        end
      end
    end
    [result, client]
  ensure
    McpServer::CcSession._client_override = nil
  end

  test "happy path → genau ein releaseMeldeliste-POST, status :finalized" do
    result, client = run_finalize
    assert_equal :finalized, result[:status]
    assert_equal 1, client.posts.size
    action, payload, _ = client.posts.first
    assert_equal "releaseMeldeliste", action
    assert_equal 1347, payload[:meldelisteId]
    assert_equal "", payload[:release]
  end

  test "account :none → skipped (no_cc_credentials), kein POST" do
    result, client = run_finalize(account: none_account)
    assert_equal :skipped, result[:status]
    assert_equal :no_cc_credentials, result[:reason]
    assert_empty client.posts
  end

  test "fehlende meldeliste_cc_id → skipped (no_meldeliste), kein POST" do
    result, client = run_finalize(tc: TcDouble.new(939, "2025/2026", nil))
    assert_equal :skipped, result[:status]
    assert_equal :no_meldeliste, result[:reason]
    assert_empty client.posts
  end

  test "kein TournamentCc → skipped (no_tournament_cc)" do
    result, = run_finalize(tc: nil)
    assert_equal :skipped, result[:status]
    assert_equal :no_tournament_cc, result[:reason]
  end

  test "CC-Fehler (HTTP 500) → status :error, kein Crash" do
    result, client = run_finalize(client: RecordingClient.new(code: "500"))
    assert_equal :error, result[:status]
    assert_equal "http_500", result[:reason]
    assert_equal 1, client.posts.size
  end
end
