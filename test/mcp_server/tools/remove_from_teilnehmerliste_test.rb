# frozen_string_literal: true

require "test_helper"

# Tests für cc_remove_from_teilnehmerliste (Plan 33-01 Toggle-Umbau).
# Mock-only Scope. Neue Architektur: Live-State aus showTeilnehmerliste Tab-3
# (akkreditierte) + meisterschaft-showMeldeliste Tab-2 (gemeldete); zwei atomare
# Entfernungs-Pfade je nach Zustand:
#   :accredited    → showMeldeliste_teilnahme (Toggle, zurück in Meldeliste)
#   :fast_assigned → cc_remove_tn (Schnellanmeldung, verschwindet ganz)
#   :reported_only / :not_in_tournament → Ablehnung
class McpServer::Tools::RemoveFromTeilnehmerlisteTest < ActiveSupport::TestCase
  # Stateful MockClient für die neue Live-State-Architektur.
  # teilnehmer / gemeldete: Arrays von [cc_id, "Nachname", "Vorname"].
  # gemeldete enthält ALLE Gemeldeten (auch akkreditierte) — wie CC Tab-2 (live verifiziert 2026-06-11).
  # ascii8bit: simuliert den Net::HTTP-Rohbody (Encoding-Regression).
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
      case action
      when "showMeldeliste_teilnahme"
        pid = params[:pid].to_i
        if t.any? { |id, _, _| id == pid }
          t.reject! { |id, _, _| id == pid }
        else
          row = g.find { |id, _, _| id == pid }
          t << row if row
        end
        [Struct.new(:code, :message, :body).new("200", "OK", "ok"), Nokogiri::HTML("<html><body>ok</body></html>")]
      when "cc_remove_tn"
        pid = params[:akkpid].to_i
        t.reject! { |id, _, _| id == pid }
        [Struct.new(:code, :message, :body).new("200", "OK", "ok"), Nokogiri::HTML("<html><body>ok</body></html>")]
      else
        [Struct.new(:code, :message, :body).new("200", "OK", "ok"), Nokogiri::HTML("<html><body>MOCK POST #{action}</body></html>")]
      end
    end
    mock
  end

  # Standard-Setup: Kämmer + Schröder akkreditiert (in Teilnehmerliste + Meldeliste),
  # Meyer nur gemeldet, Ullrich per Schnellanmeldung (Teilnehmer ohne Meldeliste-Eintrag).
  TEILNEHMER = [[10686, "Kämmer", "Lothar"], [10024, "Schröder", "Hans-Jörg"], [10031, "Ullrich", "Gernot"]].freeze
  GEMELDETE = [[10686, "Kämmer", "Lothar"], [10024, "Schröder", "Hans-Jörg"], [10021, "Meyer", "Manfred"]].freeze

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

  def call_remove(player_cc_id:, armed: false, read_back: true)
    McpServer::Tools::RemoveFromTeilnehmerliste.call(
      tournament_cc_id: 939, player_cc_id: player_cc_id,
      fed_cc_id: 20, branch_cc_id: 10, season: "2025/2026",
      armed: armed, read_back: read_back, server_context: nil
    )
  end

  # --- Dry-Run + Pfad-Wahl ---

  test "armed:false akkreditierter Spieler → Dry-Run Toggle-Pfad, kein Write" do
    response = call_remove(player_cc_id: 10024) # Schröder = :accredited
    refute response.error?, "Expected success, got: #{response.content.first[:text]}"
    text = response.content.first[:text]
    assert_match(/\[DRY-RUN\] Would remove player_cc_id=10024/, text)
    assert_match(/Live-Zustand: accredited/, text)
    assert_match(/Toggle showMeldeliste_teilnahme/, text)
    write_calls = @mock.calls.select { |verb, action, _, _| verb == :post }
    assert write_calls.empty?, "Dry-Run darf KEINEN POST auslösen — got #{write_calls.inspect}"
  end

  test "armed:true akkreditierter Spieler → Toggle showMeldeliste_teilnahme + Read-Back, KEIN removePlayer/Save" do
    response = call_remove(player_cc_id: 10024, armed: true)
    refute response.error?, "Expected success, got: #{response.content.first[:text]}"
    text = response.content.first[:text]
    assert_match(/Removed player_cc_id=10024/, text)
    assert_match(/read_back_match: true/, text)
    posts = @mock.calls.select { |verb, _, _, _| verb == :post }.map { |_, a, _, _| a }
    assert_equal ["showMeldeliste_teilnahme"], posts, "akkreditiert → genau 1 Toggle-POST — got #{posts.inspect}"
    refute posts.include?("removePlayer"), "removePlayer-Pfad darf NICHT mehr genutzt werden"
    refute posts.include?("editTeilnehmerlisteSave"), "Edit-Buffer-Save darf NICHT mehr genutzt werden"
  end

  test "Toggle-Payload enthält pid + Base-Felder ohne firstEntry/save" do
    call_remove(player_cc_id: 10024, armed: true)
    toggle = @mock.calls.find { |verb, action, _, _| verb == :post && action == "showMeldeliste_teilnahme" }
    refute_nil toggle, "showMeldeliste_teilnahme muss aufgerufen worden sein"
    _, _, params, _ = toggle
    assert_equal 10024, params[:pid]
    assert_equal 939, params[:meisterschaftsId]
    refute params.key?(:firstEntry), "firstEntry darf nicht im Toggle-Payload sein"
    refute params.key?(:save), "save darf nicht im Toggle-Payload sein"
  end

  test "armed:true Schnellanmeldungs-Spieler → cc_remove_tn (akkpid), NICHT Toggle" do
    response = call_remove(player_cc_id: 10031, armed: true) # Ullrich = :fast_assigned
    refute response.error?, "Expected success, got: #{response.content.first[:text]}"
    text = response.content.first[:text]
    assert_match(/Removed player_cc_id=10031/, text)
    posts = @mock.calls.select { |verb, _, _, _| verb == :post }.map { |_, a, _, _| a }
    assert_equal ["cc_remove_tn"], posts, "Schnellanmeldung → genau 1 cc_remove_tn-POST — got #{posts.inspect}"
    rm = @mock.calls.find { |verb, action, _, _| verb == :post && action == "cc_remove_tn" }
    _, _, params, _ = rm
    assert_equal 10031, params[:akkpid], "cc_remove_tn identifiziert den Spieler via akkpid"
  end

  # --- Pre-Validation (Ablehnungen) ---

  test "nur gemeldeter (nicht akkreditierter) Spieler → Ablehnung, kein Write" do
    response = call_remove(player_cc_id: 10021, armed: true) # Meyer = :reported_only
    assert response.error?
    assert_match(/nur gemeldet.*nicht akkreditiert|nicht akkreditiert/, response.content.first[:text])
    assert @mock.calls.select { |verb, _, _, _| verb == :post }.empty?, "Ablehnung darf keinen Write auslösen"
  end

  test "Spieler weder gemeldet noch Teilnehmer → Ablehnung" do
    response = call_remove(player_cc_id: 99999, armed: true)
    assert response.error?
    assert_match(/weder gemeldet noch Teilnehmer/, response.content.first[:text])
  end

  # --- Encoding-Regression (Live-Bug 2026-06-11) ---

  test "Umlaut-Name aus ASCII-8BIT-Body crasht NICHT (Encoding-Regression Kämmer)" do
    McpServer::CcSession._client_override =
      build_state_mock(teilnehmer: TEILNEHMER.map(&:dup), gemeldete: GEMELDETE.map(&:dup), ascii8bit: true)
    response = call_remove(player_cc_id: 10686) # Kämmer (ä), Dry-Run
    refute response.error?, "Umlaut-Name darf nicht zu Encoding::CompatibilityError führen: #{response.content.first[:text]}"
    assert_match(/Kämmer/, response.content.first[:text])
  end

  # --- Schema + Registration ---

  test "Validation: fehlendes player_cc_id → Missing-required-error" do
    response = McpServer::Tools::RemoveFromTeilnehmerliste.call(tournament_cc_id: 939, server_context: nil)
    assert response.error?
    assert_match(/Missing required parameter/i, response.content.first[:text])
    assert_match(/player_cc_id/, response.content.first[:text])
  end

  test "Tool ist als cc_remove_from_teilnehmerliste registriert" do
    tools = McpServer::Server.collect_tools.map { |t| t.respond_to?(:tool_name) ? t.tool_name : nil }.compact
    assert_includes tools, "cc_remove_from_teilnehmerliste"
  end
end
