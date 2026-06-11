# frozen_string_literal: true

require "test_helper"

# Tests für cc_assign_player_to_teilnehmerliste (Plan 33-01 Toggle-Umbau).
# Mock-only Scope. Neue Architektur: Live-State aus showTeilnehmerliste Tab-3
# (akkreditierte) + meisterschaft-showMeldeliste Tab-2 (gemeldete). cc_assign akkreditiert
# NUR Spieler im Zustand :reported_only (gemeldet, noch nicht Teilnehmer) via atomarem
# showMeldeliste_teilnahme-Toggle (1 POST pro Spieler).
class McpServer::Tools::AssignPlayerToTeilnehmerlisteTest < ActiveSupport::TestCase
  # Stateful MockClient für die neue Live-State-Architektur.
  # teilnehmer / gemeldete: Arrays von [cc_id, "Nachname", "Vorname"].
  def build_state_mock(teilnehmer:, gemeldete:, ascii8bit: false)
    t = teilnehmer.dup
    g = gemeldete.dup
    enc = ascii8bit
    mock = McpServer::Tools::MockClient.new
    mock.define_singleton_method(:get) do |action, params, opts|
      @calls << [:get, action, params, opts]
      body = case action
      when "showTeilnehmerliste"
        rows = t.map { |cc_id, nach, vor| %(<a href="showTeilnehmer.php?p=x-#{cc_id}&" title="#{nach}, #{vor} (#{cc_id})" class="cc_bluelink">#{nach}</a>) }.join("\n")
        "<html><body>#{rows}</body></html>"
      when "meisterschaft-showMeldeliste"
        rows = g.map { |cc_id, nach, vor| "<tr><td class='bb1'><b>#{nach}</b></td><td class='bb1'><b>#{vor}</b></td><td class='bb1' align='center'>#{cc_id}</td></tr>" }.join("\n")
        "<html><body><table>#{rows}</table></body></html>"
      else
        "<html><body>MOCK GET #{action}</body></html>"
      end
      body = body.dup.force_encoding("ASCII-8BIT") if enc
      [Struct.new(:code, :message, :body).new("200", "OK", body), Nokogiri::HTML(body)]
    end
    mock.define_singleton_method(:post) do |action, params, opts|
      @calls << [:post, action, params, opts]
      if action == "showMeldeliste_teilnahme"
        pid = params[:pid].to_i
        if t.any? { |id, _, _| id == pid }
          t.reject! { |id, _, _| id == pid }
        else
          row = g.find { |id, _, _| id == pid }
          t << row if row
        end
      end
      [Struct.new(:code, :message, :body).new("200", "OK", "ok"), Nokogiri::HTML("<html><body>ok</body></html>")]
    end
    mock
  end

  # Standard-Setup: Kämmer (10686) akkreditiert; Meyer (10021) + Müller (10022) nur gemeldet.
  TEILNEHMER = [[10686, "Kämmer", "Lothar"]].freeze
  GEMELDETE = [[10686, "Kämmer", "Lothar"], [10021, "Meyer", "Manfred"], [10022, "Müller", "Jörg"]].freeze

  setup do
    McpServer::CcSession.reset!
    McpServer::CcSession.session_id = "TEST_SESSION_ID"
    McpServer::CcSession.session_started_at = Time.now
    @mock = build_state_mock(teilnehmer: TEILNEHMER.map(&:dup), gemeldete: GEMELDETE.map(&:dup))
    McpServer::CcSession._client_override = @mock
  end

  teardown do
    McpServer::CcSession._client_override = nil
    McpServer::CcSession.reset!
  end

  def call_assign(player_cc_ids:, armed: false, read_back: true)
    McpServer::Tools::AssignPlayerToTeilnehmerliste.call(
      tournament_cc_id: 939, player_cc_ids: player_cc_ids,
      fed_cc_id: 20, branch_cc_id: 10, season: "2025/2026",
      armed: armed, read_back: read_back, server_context: nil
    )
  end

  # --- Dry-Run + Toggle ---

  test "armed:false nur-gemeldeter Spieler → Dry-Run, kein Write" do
    response = call_assign(player_cc_ids: [10021]) # Meyer = :reported_only
    refute response.error?, "Expected success, got: #{response.content.first[:text]}"
    text = response.content.first[:text]
    assert_match(/\[DRY-RUN\] Would assign 1 player/, text)
    assert_match(/10021.*Meyer/, text)
    assert_match(/teilnehmerliste_count_before: 1/, text)
    assert_match(/Workflow: showMeldeliste_teilnahme.*Toggle/, text)
    assert @mock.calls.select { |verb, _, _, _| verb == :post }.empty?, "Dry-Run darf keinen POST auslösen"
  end

  test "armed:true akkreditiert via Toggle + Read-Back, KEIN assignPlayer/Save" do
    response = call_assign(player_cc_ids: [10021], armed: true)
    refute response.error?, "Expected success, got: #{response.content.first[:text]}"
    text = response.content.first[:text]
    assert_match(/Assigned 1 player/, text)
    assert_match(/read_back_match: true/, text)
    posts = @mock.calls.select { |verb, _, _, _| verb == :post }.map { |_, a, _, _| a }
    assert_equal ["showMeldeliste_teilnahme"], posts, "genau 1 Toggle-POST — got #{posts.inspect}"
    refute posts.include?("assignPlayer"), "assignPlayer/meldungId[] darf nicht mehr genutzt werden"
    refute posts.include?("editTeilnehmerlisteSave"), "Edit-Buffer-Save darf nicht mehr genutzt werden"
  end

  test "Multi-Add: zwei nur-gemeldete Spieler → ein Toggle pro Spieler" do
    response = call_assign(player_cc_ids: [10021, 10022], armed: true)
    refute response.error?, "Expected success, got: #{response.content.first[:text]}"
    assert_match(/Assigned 2 player/, response.content.first[:text])
    toggles = @mock.calls.select { |verb, action, _, _| verb == :post && action == "showMeldeliste_teilnahme" }
    assert_equal 2, toggles.size, "1 Toggle pro Spieler — got #{toggles.size}"
    assert_equal [10021, 10022], toggles.map { |_, _, p, _| p[:pid] }
  end

  test "Toggle-Payload enthält pid + Base-Felder ohne firstEntry/save" do
    call_assign(player_cc_ids: [10021], armed: true)
    toggle = @mock.calls.find { |verb, action, _, _| verb == :post && action == "showMeldeliste_teilnahme" }
    refute_nil toggle, "showMeldeliste_teilnahme muss aufgerufen worden sein"
    _, _, params, _ = toggle
    required = %i[fedId branchId disciplinId catId season meisterTypeId meisterschaftsId sortedBy pid]
    assert_empty(required - params.keys, "fehlende Felder; got #{params.keys.sort.inspect}")
    assert_equal 10021, params[:pid]
    refute params.key?(:firstEntry)
    refute params.key?(:save)
  end

  # --- Pre-Validation (Matrix-Ablehnungen) ---

  test "bereits akkreditierter Spieler → Ablehnung (kein Re-Toggle)" do
    response = call_assign(player_cc_ids: [10686], armed: true) # Kämmer = :accredited
    assert response.error?
    assert_match(/bereits akkreditiert/, response.content.first[:text])
    assert @mock.calls.select { |verb, _, _, _| verb == :post }.empty?, "Ablehnung darf keinen Toggle auslösen"
  end

  test "Spieler nicht in Meldeliste → Ablehnung mit Hinweis auf cc_register / cc_fast_assign" do
    response = call_assign(player_cc_ids: [99999], armed: true) # :not_in_tournament
    assert response.error?
    text = response.content.first[:text]
    assert_match(/nicht in der Meldeliste/, text)
    assert_match(/cc_register_for_tournament/, text)
    assert_match(/cc_fast_assign_to_teilnehmerliste/, text)
  end

  # --- Encoding-Regression (Live-Bug 2026-06-11) ---

  test "Umlaut-Name aus ASCII-8BIT-Body crasht NICHT (Encoding-Regression Müller)" do
    McpServer::CcSession._client_override =
      build_state_mock(teilnehmer: TEILNEHMER.map(&:dup), gemeldete: GEMELDETE.map(&:dup), ascii8bit: true)
    response = call_assign(player_cc_ids: [10022]) # Müller (ü), Dry-Run
    refute response.error?, "Umlaut-Name darf nicht zu Encoding::CompatibilityError führen: #{response.content.first[:text]}"
    assert_match(/Müller/, response.content.first[:text])
  end

  # --- Schema + Registration ---

  test "Validation: fehlendes tournament_cc_id → Missing-required-error" do
    response = McpServer::Tools::AssignPlayerToTeilnehmerliste.call(player_cc_ids: [10021], server_context: nil)
    assert response.error?
    assert_match(/Missing required parameter/i, response.content.first[:text])
    assert_match(/tournament_cc_id/, response.content.first[:text])
  end

  test "Validation: leeres player_cc_ids Array → Invalid-input-error" do
    response = McpServer::Tools::AssignPlayerToTeilnehmerliste.call(tournament_cc_id: 939, player_cc_ids: [], server_context: nil)
    assert response.error?
    assert_match(/Invalid player_cc_ids/i, response.content.first[:text])
  end

  test "Tool ist als cc_assign_player_to_teilnehmerliste registriert" do
    tools = McpServer::Server.collect_tools.map { |t| t.respond_to?(:tool_name) ? t.tool_name : nil }.compact
    assert_includes tools, "cc_assign_player_to_teilnehmerliste"
  end
end
