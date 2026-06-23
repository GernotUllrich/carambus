# frozen_string_literal: true

require "test_helper"

# Plan 45-01: cc_lookup_league-Fix.
# AC-1: force_refresh wirft KEINEN NameError mehr (live_lookup nimmt server_context).
# AC-3: DB-Pfad liefert keine BELIEBIGE Liga mehr (vorher LeagueCc...first) — bei
#       Mehrdeutigkeit Hinweis auf cc_list_leagues, bei genau 1 Treffer die Liga.
class McpServer::Tools::LookupLeagueTest < ActiveSupport::TestCase
  setup do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    ENV["CC_FED_ID"] = nil
    ENV["CC_REGION"] = nil
    McpServer::CcSession.reset!

    @nbv = regions(:nbv)
    @season = seasons(:current)
    @pool = Branch.create!(name: "P45L-Pool")
    @nineball = Discipline.create!(name: "P45L-9Ball", super_discipline: @pool)
  end

  teardown do
    ENV["CARAMBUS_MCP_MOCK"] = nil
    [@league_b, @league_a, @nineball, @pool].compact.each { |r| r.destroy if r&.persisted? }
  end

  def make_league!(name:, cc_id:)
    League.create!(name: name, shortname: name.gsub(/\s/, "")[0, 12], organizer: @nbv,
      season: @season, discipline: @pool, cc_id: cc_id)
  end

  # AC-1: Regression — der frühere NameError (live_lookup nutzte server_context, nahm es
  # aber nicht als Param) darf nicht mehr auftreten.
  test "AC-1: force_refresh wirft keinen NameError (server_context durchgereicht)" do
    skip "NBV fixtures missing" unless @nbv
    assert_nothing_raised do
      response = McpServer::Tools::LookupLeague.call(
        fed_id: 20, branch_id: 10, season: "2025/2026",
        force_refresh: true, server_context: {cc_region: "NBV"}
      )
      assert_not_nil response
    end
  end

  # AC-3: Mehrere Treffer → KEINE willkürliche Auswahl, sondern Hinweis auf cc_list_leagues.
  test "AC-3: mehrere passende Ligen → Disambiguierungs-Hinweis statt beliebiger Liga" do
    skip "NBV fixtures missing" unless @nbv
    @league_a = make_league!(name: "P45L Pool Liga A", cc_id: 945_101)
    @league_b = make_league!(name: "P45L Pool Liga B", cc_id: 945_102)

    response = McpServer::Tools::LookupLeague.call(
      discipline: "P45L-Pool", server_context: {cc_region: "NBV"}
    )
    refute response.error?, "Disambiguierung ist kein Fehler"
    txt = response.content.first[:text]
    assert_match(/Mehrere Ligen/i, txt)
    assert_match(/cc_list_leagues/, txt)
    # darf NICHT eine einzelne Liga als JSON zurückgeben
    refute_match(/"league_id":\s*#{@league_a.id}\s*,\s*"cc_id"/, txt)
  end

  # AC-3: genau 1 Treffer → die Liga (JSON mit league_id), kein .first-Zufall.
  test "AC-3: genau eine passende Liga → diese Liga als JSON" do
    skip "NBV fixtures missing" unless @nbv
    @league_a = make_league!(name: "P45L Pool Solo Liga", cc_id: 945_103)

    response = McpServer::Tools::LookupLeague.call(
      discipline: "P45L-Pool", server_context: {cc_region: "NBV"}
    )
    refute response.error?
    body = JSON.parse(response.content.first[:text])
    assert_equal @league_a.id, body["league_id"]
    assert_equal 945_103, body["cc_id"]
    assert_equal "P45L Pool Solo Liga", body["name"]
  end

  # Backward-Compat: league_id-Pfad bleibt funktional (unbekannte ID → sauberer Error, kein Crash).
  test "Backward-Compat: unbekannte league_id → sauberer Error (kein Crash)" do
    skip "NBV fixtures missing" unless @nbv
    assert_nothing_raised do
      response = McpServer::Tools::LookupLeague.call(
        league_id: 999_999_999, server_context: {cc_region: "NBV"}
      )
      assert response.error?
      assert_match(/not found/i, response.content.first[:text])
    end
  end

  # Guard: ohne identifizierende Angaben → Hinweis (kein Crash, keine Liste).
  test "ohne Parameter → Hinweis auf benötigte Angaben" do
    response = McpServer::Tools::LookupLeague.call(server_context: {cc_region: "NBV"})
    assert response.error?
    assert_match(/league_id|discipline|cc_list_leagues/i, response.content.first[:text])
  end
end
