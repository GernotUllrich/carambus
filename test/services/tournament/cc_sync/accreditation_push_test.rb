# frozen_string_literal: true

require "test_helper"

# Plan 44-01: Unit-Tests für den MCP-freien Akkreditierungs-Push.
# Isoliert: stubbt CcAccountResolver + die Live-State-/Scope-Helfer des assign-Tools,
# injiziert einen Recording-Client über CcSession._client_override. Kein echter HTTP-Call.
class Tournament::CcSync::AccreditationPushTest < ActiveSupport::TestCase
  Assign = McpServer::Tools::AssignPlayerToTeilnehmerliste

  TcDouble = Struct.new(:cc_id, :season)
  TournamentDouble = Struct.new(:tournament_cc, :id)
  PlayerDouble = Struct.new(:cc_id, :id)

  # Minimaler Client, der client.post(...) aufzeichnet und CC-Erfolg liefert.
  class RecordingClient
    attr_reader :posts

    def initialize
      @posts = []
    end

    def post(action, payload, opts)
      @posts << [action, payload, opts]
      [Struct.new(:code, :message, :body).new("200", "OK", "ok"),
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

  # Führt den Push unter kontrolliertem Live-Zustand + Identität aus.
  def run_push(state:, target:, account: nil, tc: TcDouble.new(939, "2025/2026"))
    account ||= own_account
    client = RecordingClient.new
    McpServer::CcSession._client_override = client
    result = nil
    McpServer::CcAccountResolver.stub(:resolve, account) do
      Assign.stub(:resolve_scope_filters, SCOPE) do
        Assign.stub(:accreditation_state, {state: state, teilnehmer: [], gemeldete: [], label: nil, error: nil}) do
          McpServer::CcSession.stub(:cookie_for, "TEST_COOKIE") do
            result = Tournament::CcSync::AccreditationPush.call(
              tournament: TournamentDouble.new(tc, 1),
              player: PlayerDouble.new(10021, 2),
              target: target,
              acting_user: Object.new
            )
          end
        end
      end
    end
    [result, client]
  ensure
    McpServer::CcSession._client_override = nil
  end

  test "deaccredit when currently accredited → genau ein Toggle-POST" do
    result, client = run_push(state: :accredited, target: :deaccredit)
    assert_equal :pushed, result[:status]
    assert_equal 1, client.posts.size
    action, payload, _opts = client.posts.first
    assert_equal "showMeldeliste_teilnahme", action
    assert_equal 10021, payload[:pid]
    refute payload.key?(:firstEntry), "Toggle-Payload darf firstEntry NICHT enthalten"
  end

  test "deaccredit when already reported_only → noop, kein POST" do
    result, client = run_push(state: :reported_only, target: :deaccredit)
    assert_equal :noop, result[:status]
    assert_empty client.posts
  end

  test "accredit when reported_only → genau ein Toggle-POST" do
    result, client = run_push(state: :reported_only, target: :accredit)
    assert_equal :pushed, result[:status]
    assert_equal 1, client.posts.size
  end

  test "accredit when already accredited → noop, kein POST" do
    result, client = run_push(state: :accredited, target: :accredit)
    assert_equal :noop, result[:status]
    assert_empty client.posts
  end

  test "account :none → skipped (no_cc_credentials), kein POST" do
    result, client = run_push(state: :reported_only, target: :accredit, account: none_account)
    assert_equal :skipped, result[:status]
    assert_equal :no_cc_credentials, result[:reason]
    assert_empty client.posts
  end

  test "fast_assigned → skipped (unsupported_state), kein POST" do
    result, client = run_push(state: :fast_assigned, target: :deaccredit)
    assert_equal :skipped, result[:status]
    assert_equal :unsupported_state, result[:reason]
    assert_empty client.posts
  end

  test "kein TournamentCc → skipped (no_tournament_cc)" do
    result, = run_push(state: :reported_only, target: :accredit, tc: nil)
    assert_equal :skipped, result[:status]
    assert_equal :no_tournament_cc, result[:reason]
  end

  # --- 44-02: Membership-Targets (D-44-8) ---

  test "ensure_participant + not_in_tournament → cc_fast_assign (Schnellanmeldung)" do
    result, client = run_push(state: :not_in_tournament, target: :ensure_participant)
    assert_equal :pushed, result[:status]
    assert_equal 1, client.posts.size
    action, payload, _ = client.posts.first
    assert_equal "cc_fast_assign", action
    assert_equal 10021, payload[:foundpid]
    assert_equal "", payload[:akkpid]
  end

  test "ensure_participant + reported_only → Toggle (akkreditieren)" do
    result, client = run_push(state: :reported_only, target: :ensure_participant)
    assert_equal :pushed, result[:status]
    assert_equal ["showMeldeliste_teilnahme"], client.posts.map { |p| p[0] }
  end

  test "ensure_participant + accredited → noop, kein POST" do
    result, client = run_push(state: :accredited, target: :ensure_participant)
    assert_equal :noop, result[:status]
    assert_empty client.posts
  end

  test "ensure_participant + fast_assigned → noop, kein POST" do
    result, client = run_push(state: :fast_assigned, target: :ensure_participant)
    assert_equal :noop, result[:status]
    assert_empty client.posts
  end

  test "remove_participant + accredited → Toggle (deakkreditieren)" do
    result, client = run_push(state: :accredited, target: :remove_participant)
    assert_equal :pushed, result[:status]
    assert_equal ["showMeldeliste_teilnahme"], client.posts.map { |p| p[0] }
  end

  test "remove_participant + fast_assigned → cc_remove_tn" do
    result, client = run_push(state: :fast_assigned, target: :remove_participant)
    assert_equal :pushed, result[:status]
    assert_equal 1, client.posts.size
    action, payload, _ = client.posts.first
    assert_equal "cc_remove_tn", action
    assert_equal 10021, payload[:akkpid]
    assert_equal 1, payload[:dla]
  end

  test "remove_participant + reported_only → skip (registration_only_not_removed), kein POST" do
    result, client = run_push(state: :reported_only, target: :remove_participant)
    assert_equal :skipped, result[:status]
    assert_equal :registration_only_not_removed, result[:reason]
    assert_empty client.posts
  end

  test "remove_participant + not_in_tournament → noop, kein POST" do
    result, client = run_push(state: :not_in_tournament, target: :remove_participant)
    assert_equal :noop, result[:status]
    assert_empty client.posts
  end
end
