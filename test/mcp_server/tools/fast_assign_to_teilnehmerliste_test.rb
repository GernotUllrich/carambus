# frozen_string_literal: true

require "test_helper"

# Plan 32-01 (2026-06-10): Tests fuer cc_fast_assign_to_teilnehmerliste.
# Neues Write-Tool fuer Schnellanmeldung via cc_fast_assign.php.
# Kein Pre-Read / Edit-Buffer — atomarer Single-POST mit foundpid.

class McpServer::Tools::FastAssignToTeilnehmerlisteTest < ActiveSupport::TestCase
  setup do
    McpServer::CcSession.reset!
    McpServer::CcSession.session_id = "TEST_SESSION_ID"
    McpServer::CcSession.session_started_at = Time.now
  end

  teardown do
    McpServer::CcSession._client_override = nil
    McpServer::CcSession.reset!
  end

  # Mock-Client: POST cc_fast_assign → armed_response_code; GET showTeilnehmerliste → leeres HTML
  def build_mock(armed_response_code: "200")
    ok = Struct.new(:code, :message, :body)
    empty_html = "<html><body></body></html>"
    mock = McpServer::Tools::MockClient.new
    mock.define_singleton_method(:post) do |action, params, opts|
      @calls << [:post, action, params, opts]
      [ok.new(armed_response_code, "OK", empty_html), Nokogiri::HTML(empty_html)]
    end
    mock.define_singleton_method(:get) do |action, params, opts|
      @calls << [:get, action, params, opts]
      [ok.new("200", "OK", empty_html), Nokogiri::HTML(empty_html)]
    end
    McpServer::CcSession._client_override = mock
    mock
  end

  # AC-1: Dry-Run gibt vollstaendigen Echo ohne CC-POST
  test "AC-1: Dry-Run (armed:false) gibt Echo-Output ohne POST zu cc_fast_assign" do
    mock = build_mock
    response = McpServer::Tools::FastAssignToTeilnehmerliste.call(
      tournament_cc_id: 859, player_cc_id: 10165,
      fed_cc_id: 20, branch_cc_id: 7, armed: false
    )
    refute response.error?, "expected non-error; got: #{response.content.first[:text]}"
    text = response.content.first[:text]
    assert_match(/DRY-RUN/, text)
    assert_match(/tournament_cc_id.*859/, text)
    assert_match(/player_cc_id.*10165/, text)
    assert_match(/foundpid/, text)
    assert_match(/akkpid.*""/, text)
    # Kein POST zu cc_fast_assign
    post_calls = mock.calls.select { |c| c[0] == :post && c[1] == "cc_fast_assign" }
    assert_empty post_calls, "Dry-Run darf keinen POST zu cc_fast_assign machen; got: #{post_calls.inspect}"
  end

  # AC-2: Armed=true sendet POST mit korrekten Params
  test "AC-2: armed:true sendet POST zu cc_fast_assign mit foundpid/fedId/branchId" do
    mock = build_mock(armed_response_code: "200")
    response = McpServer::Tools::FastAssignToTeilnehmerliste.call(
      tournament_cc_id: 859, player_cc_id: 10165,
      fed_cc_id: 20, branch_cc_id: 7, armed: true
    )
    refute response.error?, "expected non-error; got: #{response.content.first[:text]}"
    fast_assign_calls = mock.calls.select { |c| c[0] == :post && c[1] == "cc_fast_assign" }
    assert_equal 1, fast_assign_calls.size, "Genau 1 POST zu cc_fast_assign erwartet"
    _verb, _action, params, _opts = fast_assign_calls.first
    assert_equal 859, params[:meisterschaftsId]
    assert_equal 10165, params[:foundpid]
    assert_equal "", params[:akkpid]
    assert_equal 20, params[:fedId]
    assert_equal 7, params[:branchId]
  end

  # AC-3: Swap-Modus via replace_player_cc_id
  test "AC-3: replace_player_cc_id setzt akkpid fuer Swap-Modus" do
    build_mock
    response = McpServer::Tools::FastAssignToTeilnehmerliste.call(
      tournament_cc_id: 859, player_cc_id: 10165,
      replace_player_cc_id: 10761,
      fed_cc_id: 20, branch_cc_id: 7, armed: false
    )
    refute response.error?
    text = response.content.first[:text]
    assert_match(/Swap/, text)
    assert_match(/10761/, text)
    assert_match(/akkpid.*"10761"/, text)
  end

  # AC-4: Fehlende Scope-Params -> klare Fehlermeldung
  test "AC-4: fehlende fed_cc_id und branch_cc_id geben Scope-Fehler" do
    build_mock
    # Kein fed_cc_id, kein branch_cc_id, kein DB-Mock -> Scope unvollstaendig
    response = McpServer::Tools::FastAssignToTeilnehmerliste.call(
      tournament_cc_id: 999_999_999, player_cc_id: 10165
    )
    assert response.error?
    text = response.content.first[:text]
    assert_match(/fed_cc_id|branchId|Scope/, text)
  end

  # CC-Fehler bei armed:true
  test "HTTP-Fehler (500) bei armed:true liefert error-Response" do
    build_mock(armed_response_code: "500")
    response = McpServer::Tools::FastAssignToTeilnehmerliste.call(
      tournament_cc_id: 859, player_cc_id: 10165,
      fed_cc_id: 20, branch_cc_id: 7, armed: true
    )
    assert response.error?, "HTTP-500 muss error-Response liefern"
    assert_match(/500|rejected/, response.content.first[:text])
  end
end
