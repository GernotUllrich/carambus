# frozen_string_literal: true

require "test_helper"

class TournamentPreparation::AppLinkBuilderTest < ActiveSupport::TestCase
  setup do
    @tournament = tournaments(:local)
    @tcc = TournamentCc.create!(cc_id: 80_905, context: "nbv", tournament: @tournament)
    @tournament.reload
    @ctx = {user_id: 1, cc_region: "NBV"}
  end

  test "tournament nil → :tournament_invalid" do
    res = TournamentPreparation::AppLinkBuilder.call(tournament: nil)
    refute res[:ok]
    assert_equal :tournament_invalid, res[:reason]
  end

  test "tournament ohne tournament_cc → :tournament_invalid" do
    t = Tournament.create!(
      title: "Ohne TCC", season_id: 50_000_001,
      organizer_id: 50_000_001, organizer_type: "Region",
      discipline_id: 50_000_001, state: "tournament_mode_defined",
      date: 1.week.from_now
    )
    res = TournamentPreparation::AppLinkBuilder.call(tournament: t)
    refute res[:ok]
    assert_equal :tournament_invalid, res[:reason]
  end

  test "config gesetzt → Deep-Link mit allen cb_-Params, encodiert" do
    Carambus.stub(:config, OpenStruct.new(
      tournament_app_url: "http://192.168.2.210:3131/app/",
      external_app_api_base_url: "http://192.168.2.210:3131"
    )) do
      res = TournamentPreparation::AppLinkBuilder.call(tournament: @tournament, server_context: @ctx)
      assert res[:ok], res.inspect
      link = res[:app_link]
      assert link.start_with?("http://192.168.2.210:3131/app/?"), link
      assert_match(/cb_tournament_cc_id=80905/, link)
      assert_match(/cb_region=NBV/, link)
      # api_base url-encoded (": " und "/" → %3A %2F)
      assert_match(/cb_base_url=http%3A%2F%2F192.168.2.210%3A3131/, link)
    end
  end

  test "DEV-43-C: Same-Origin-Default — relativer /app/-Link OHNE cb_base_url" do
    # Keine App-Config gesetzt → relativer Default /app/, App leitet base_url aus location.origin ab.
    Carambus.stub(:config, OpenStruct.new(carambus_domain: "lvh.me:3007")) do
      res = TournamentPreparation::AppLinkBuilder.call(tournament: @tournament, server_context: @ctx)
      assert res[:ok]
      link = res[:app_link]
      assert link.start_with?("/app/?"), link
      assert_match(/cb_region=NBV/, link)
      assert_match(/cb_tournament_cc_id=80905/, link)
      # Punkt 2: globaler DB-PK im Link (deterministische Auflösung)
      assert_match(/cb_tournament_id=#{@tournament.id}/, link)
      refute_match(/cb_base_url/, link, "Same-Origin → kein cb_base_url")
    end
  end

  test "cross-origin: external_app_api_base_url gesetzt → cb_base_url im Link" do
    Carambus.stub(:config, OpenStruct.new(
      tournament_app_url: "http://192.168.2.210:8123/",
      external_app_api_base_url: "http://192.168.2.210:3131"
    )) do
      res = TournamentPreparation::AppLinkBuilder.call(tournament: @tournament, server_context: @ctx)
      assert res[:ok]
      link = res[:app_link]
      assert link.start_with?("http://192.168.2.210:8123/?"), link
      assert_match(/cb_base_url=http%3A%2F%2F192.168.2.210%3A3131/, link)
    end
  end

  test "app_base mit vorhandenem Query → & statt ? als Trenner" do
    Carambus.stub(:config, OpenStruct.new(
      tournament_app_url: "http://host/app/?v=2",
      external_app_api_base_url: "http://host:3131"
    )) do
      res = TournamentPreparation::AppLinkBuilder.call(tournament: @tournament, server_context: @ctx)
      assert res[:ok]
      assert_match(%r{\?v=2&cb_region=}, res[:app_link])
    end
  end
end
