# frozen_string_literal: true

require "test_helper"

# Tests für cc_lookup_club (Plan 10-05 Task 3 / Befund #9 D-10-03-4):
# DB-First-Search mit cc_id ODER name ODER shortname; Disambiguation-Output;
# Synonym-Match-Hervorhebung; Region-Filter via region_shortname.
#
# Mock-Mode-only: kein CC-Call nötig (Tool ist jetzt DB-first).
class McpServer::Tools::LookupClubTest < ActiveSupport::TestCase
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

  test "validation: kein input-param liefert error" do
    response = McpServer::Tools::LookupClub.call(server_context: nil)
    assert response.error?
    assert_match(/Missing required parameter/i, response.content.first[:text])
  end

  test "cc_id direkt-Lookup: bekannter Club aus DB" do
    sample = Club.where.not(cc_id: nil).first
    skip "No Club fixtures with cc_id" unless sample

    ENV["CC_REGION"] = sample.region&.shortname.to_s.upcase
    response = McpServer::Tools::LookupClub.call(cc_id: sample.cc_id, server_context: nil)
    refute response.error?, "Expected non-error; got: #{response.content.first[:text]}"
    body = JSON.parse(response.content.first[:text])
    assert_equal sample.cc_id, body["cc_id"]
    assert_equal 1, body["meta"]["count"]
    assert_equal 1, body["candidates"].length
    assert_equal sample.name, body["candidates"].first["name"]
  end

  test "name-Search: exact Name-Match liefert candidates-Array" do
    sample = Club.where.not(cc_id: nil).where.not(name: [nil, ""]).first
    skip "No Club fixtures with name" unless sample

    ENV["CC_REGION"] = sample.region&.shortname.to_s.upcase
    # Suche mit Teilstring des echten Namens (case-insensitive)
    needle = sample.name.to_s[0, [sample.name.length, 5].min]
    skip "Sample name too short" if needle.length < 3

    response = McpServer::Tools::LookupClub.call(name: needle, server_context: nil)
    refute response.error?, "Expected non-error; got: #{response.content.first[:text]}"
    body = JSON.parse(response.content.first[:text])

    assert_operator body["candidates"].length, :>=, 1
    body["candidates"].each do |c|
      # Name ODER synonyms ODER shortname matched
      match_in_name = c["name"].to_s.downcase.include?(needle.downcase)
      match_in_shortname = c["shortname"].to_s.downcase.include?(needle.downcase)
      assert(match_in_name || match_in_shortname || c["synonyms_matched"],
        "Treffer muss name, shortname, oder synonyms matchen: #{c.inspect}")
    end
  end

  test "shortname-Search: exact Shortname-Match" do
    sample = Club.where.not(cc_id: nil).where.not(shortname: [nil, ""]).first
    skip "No Club fixtures with shortname" unless sample

    ENV["CC_REGION"] = sample.region&.shortname.to_s.upcase
    needle = sample.shortname.to_s

    response = McpServer::Tools::LookupClub.call(shortname: needle, server_context: nil)
    refute response.error?, "Expected non-error; got: #{response.content.first[:text]}"
    body = JSON.parse(response.content.first[:text])

    assert_operator body["candidates"].length, :>=, 1
    body["candidates"].each do |c|
      assert_match(/#{Regexp.escape(needle)}/i, c["shortname"].to_s)
    end
  end

  test "synonym-Match: Hervorhebung der getroffenen Alt-Schreibweise" do
    # Pick a Club mit synonyms-content; if none in fixtures, skip.
    sample = Club.where.not(cc_id: nil).where("synonyms IS NOT NULL AND synonyms != ''").first
    skip "No Club fixtures with synonyms" unless sample

    ENV["CC_REGION"] = sample.region&.shortname.to_s.upcase
    # Erste Synonym-Zeile (Alt-Schreibweise) als Such-Needle
    first_synonym = sample.synonyms.to_s.split("\n").map(&:strip).reject(&:empty?).first
    skip "Sample has no usable synonyms" if first_synonym.nil? || first_synonym.length < 3

    needle = first_synonym[0, [first_synonym.length, 5].min]

    response = McpServer::Tools::LookupClub.call(name: needle, server_context: nil)
    refute response.error?, "Expected non-error; got: #{response.content.first[:text]}"
    body = JSON.parse(response.content.first[:text])

    # Mindestens einer der Treffer muss synonyms_matched enthalten
    has_synonym_match = body["candidates"].any? { |c| c["synonyms_matched"].present? }
    assert has_synonym_match, "Expected at least one candidate with synonyms_matched; got: #{body["candidates"].inspect}"
  end

  test "0-Treffer: Tool-Error mit attempted-Details + Workaround-Hinweise" do
    needle = "ZzzNonexistent#{SecureRandom.hex(8)}"
    response = McpServer::Tools::LookupClub.call(name: needle, server_context: nil)
    assert response.error?
    msg = response.content.first[:text]
    assert_match(/Kein Verein/i, msg)
    assert_match(/#{Regexp.escape(needle)}/, msg, "attempted-Param muss erscheinen")
    assert_match(/Versuche|shortname-Variante|Teilstring/i, msg, "Diagnose-Workaround-Hinweise erwartet")
  end

  test "Disambiguation: ≥2 Treffer → cc_id:null + candidates + warning" do
    # Pick a region wo wahrscheinlich mehrere Clubs existieren
    region = Region.joins(:clubs).group("regions.id").having("COUNT(clubs.id) >= 2").first
    skip "No region with ≥2 clubs in fixtures" unless region

    ENV["CC_REGION"] = region.shortname.to_s.upcase
    # Sehr kurzer needle der mehrere Clubs treffen sollte
    response = McpServer::Tools::LookupClub.call(name: "B", server_context: nil)
    body = JSON.parse(response.content.first[:text]) unless response.error?

    if response.error? || body["candidates"].length < 2
      skip "Region #{region.shortname} hat keine ≥2 Clubs mit 'B' im Namen"
    end

    assert_nil body["cc_id"], "Bei ≥2 Treffern muss top-level cc_id NULL sein"
    assert_operator body["candidates"].length, :>=, 2
    assert body["warning"].present?, "Warning erwartet bei ≥2 Treffern"
    assert_match(/Sportwart-R/i, body["warning"], "Warning sollte Sportwart-Rückfrage erwähnen")
  end

  test "region_shortname-Override: explizit gesetzte Region wird genutzt" do
    # 2 Regionen mit Clubs benötigt; sonst skip
    regions_with_clubs = Region.joins(:clubs).distinct.limit(2).to_a
    skip "Need ≥2 regions with clubs" unless regions_with_clubs.length >= 2

    region_a, region_b = regions_with_clubs

    # Default ENV → region_a; Override → region_b
    ENV["CC_REGION"] = region_a.shortname.to_s.upcase

    # Test mit Override: liefert Club aus region_b
    sample_b = Club.where(region_id: region_b.id).where.not(cc_id: nil).first
    skip "No fixtures in region_b" unless sample_b

    response = McpServer::Tools::LookupClub.call(
      cc_id: sample_b.cc_id,
      region_shortname: region_b.shortname.to_s.upcase,
      server_context: nil
    )
    refute response.error?, "Override muss greifen; got: #{response.content.first[:text]}"
    body = JSON.parse(response.content.first[:text])
    assert_equal region_b.shortname, body["meta"]["region"]
    assert_equal sample_b.cc_id, body["cc_id"]
  end
end
