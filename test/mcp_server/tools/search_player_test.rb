# frozen_string_literal: true

require "test_helper"

# Tests für cc_search_player nach Plan 10-06 Task 2 Refactor:
# Von live-only-CC-wrapper → DB-First-Search mit Disambiguation (analog cc_lookup_club).
class McpServer::Tools::SearchPlayerTest < ActiveSupport::TestCase
  setup do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    ENV["CC_FED_ID"] = nil
    ENV["CC_REGION"] = nil
    McpServer::CcSession.reset!
  end

  teardown do
    ENV["CARAMBUS_MCP_MOCK"] = nil
    ENV["CC_FED_ID"] = nil
    ENV["CC_REGION"] = nil
  end

  test "validation: query too short (<2 chars) returns error" do
    response = McpServer::Tools::SearchPlayer.call(query: "M", server_context: {cc_region: "NBV"})
    assert response.error?
    assert_match(/at least 2|too short|min/i, response.content.first[:text])
  end

  test "validation: missing query returns error" do
    response = McpServer::Tools::SearchPlayer.call(server_context: {cc_region: "NBV"})
    assert response.error?
    assert_match(/Missing required parameter/i, response.content.first[:text])
  end

  test "DB-First: nicht-existierende Suche liefert Error mit Workaround-Hinweisen" do
    needle = "ZzzNonexistent#{SecureRandom.hex(8)}"
    response = McpServer::Tools::SearchPlayer.call(query: needle, server_context: {cc_region: "NBV"})
    assert response.error?
    msg = response.content.first[:text]
    assert_match(/Keine Spieler/i, msg)
    assert_match(/Versuche|kürzeren Suchbegriff|region_shortname|force_refresh/i, msg)
  end

  test "DB-First: erfolgreiche Suche liefert candidates-Array" do
    # Pick a Player mit name aus DB; if none, skip.
    sample = Player.where.not(cc_id: nil).where.not(lastname: [nil, ""]).first
    skip "No Player fixtures with cc_id+lastname" unless sample

    ENV["CC_REGION"] = sample.region&.shortname.to_s.upcase if sample.respond_to?(:region)
    needle = sample.lastname.to_s[0, [sample.lastname.length, 5].min]
    skip "Sample lastname too short" if needle.length < 3

    response = McpServer::Tools::SearchPlayer.call(query: needle, server_context: {cc_region: "NBV"})
    refute response.error?, "Expected non-error; got: #{response.content.first[:text]}"
    body = JSON.parse(response.content.first[:text])

    assert_operator body["candidates"].length, :>=, 1
    body["candidates"].each do |c|
      assert(c["lastname"].to_s.downcase.include?(needle.downcase) ||
             c["firstname"].to_s.downcase.include?(needle.downcase) ||
             c["name"].to_s.downcase.include?(needle.downcase),
        "Treffer muss firstname/lastname/name matchen: #{c.inspect}")
    end
  end

  test "Disambiguation: ≥2 Treffer → cc_id:null + warning" do
    # Pick eine Region mit mehreren Players; sehr-kurzer needle der mehrere matched
    region = Region.joins(:players).group("regions.id").having("COUNT(players.id) >= 2").first
    skip "No region with ≥2 players in fixtures" unless region

    ENV["CC_REGION"] = region.shortname.to_s.upcase

    # Wähle kurz/häufig wie "a" oder "e" als needle
    response = McpServer::Tools::SearchPlayer.call(query: "an", server_context: {cc_region: "NBV"})

    if response.error? || JSON.parse(response.content.first[:text])["candidates"].length < 2
      skip "Region #{region.shortname} hat keine ≥2 Players mit 'an' im Namen"
    end

    body = JSON.parse(response.content.first[:text])
    assert_nil body["cc_id"], "Bei ≥2 Treffern muss top-level cc_id NULL sein"
    assert_operator body["candidates"].length, :>=, 2
    assert body["warning"].present?, "Warning erwartet bei ≥2 Treffern"
  end
end
