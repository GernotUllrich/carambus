# frozen_string_literal: true

require "test_helper"

# Plan 48-05: PartyPreparation::AppLinkBuilder — vorverbindender Deeplink auf das
# carambus_app-"spieltag"-Schema (gespiegelt von TournamentPreparation::AppLinkBuilder).
class PartyPreparation::AppLinkBuilderTest < ActiveSupport::TestCase
  def setup
    @league = League.create!(
      name: "AppLink Test League #{SecureRandom.hex(4)}",
      shortname: "ALT-#{SecureRandom.hex(2)}",
      organizer: regions(:nbv), season: seasons(:current), discipline: disciplines(:one)
    )
    @party = Party.create!(league: @league, cc_id: 9999, date: Time.zone.local(2026, 9, 13))
  end

  test "baut Deeplink mit cb_region/cb_party_id/cb_party_cc_id, Same-Origin-Default (kein cb_base_url)" do
    res = PartyPreparation::AppLinkBuilder.call(party: @party)

    assert res[:ok]
    link = res[:app_link]
    assert link.start_with?("/app/?"), "Same-Origin-Default /app/: #{link}"
    assert_includes link, "cb_region=NBV"
    assert_includes link, "cb_party_id=#{@party.id}"
    assert_includes link, "cb_party_cc_id=9999"
    refute_includes link, "cb_base_url", "kein cb_base_url im Same-Origin-Fall"
  end

  test "Region über league.organizer (Region)" do
    res = PartyPreparation::AppLinkBuilder.call(party: @party, server_context: {cc_region: "BVBW"})
    # organizer (nbv) schlägt den server_context-Fallback
    assert_includes res[:app_link], "cb_region=NBV"
  end

  test "nil-Party → ok:false reason party_invalid" do
    res = PartyPreparation::AppLinkBuilder.call(party: nil)
    refute res[:ok]
    assert_equal :party_invalid, res[:reason]
  end
end
