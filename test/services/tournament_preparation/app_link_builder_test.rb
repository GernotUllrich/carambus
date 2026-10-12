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

  teardown do
    User.where("email LIKE ?", "%test17x06%").delete_all
  end

  def tournament_without_cc(region_id:)
    Tournament.create!(
      title: "Ohne TCC", season_id: 50_000_001,
      organizer_id: 50_000_001, organizer_type: "Region",
      discipline_id: 50_000_001, state: "tournament_mode_defined",
      date: 1.week.from_now, region_id: region_id
    )
  end

  def create_service_account(shortname)
    User.create!(email: "carambus-app-#{shortname}-bridge@carambus.de", password: "password123",
      confirmed_at: Time.current)
  end

  # Plan 17-06: vorher :tournament_invalid — ohne ClubCloud-Bezug gab es gar keinen Link.
  test "tournament ohne tournament_cc und ohne Region → :region_missing" do
    Carambus.stub(:config, OpenStruct.new) do
      res = TournamentPreparation::AppLinkBuilder.call(tournament: tournament_without_cc(region_id: nil))
      refute res[:ok]
      assert_equal :region_missing, res[:reason]
    end
  end

  test "Plan 17-06: tournament ohne tournament_cc mit Region → Link aus der Turnier-Region, ohne cb_tournament_cc_id" do
    t = tournament_without_cc(region_id: regions(:nbv).id)
    Carambus.stub(:config, OpenStruct.new) do
      res = TournamentPreparation::AppLinkBuilder.call(tournament: t)
      assert res[:ok], res.inspect
      link = res[:app_link]
      assert link.start_with?("/app/?"), link
      assert_match(/cb_region=NBV/, link)
      assert_match(/cb_tournament_id=#{t.id}(&|\z)/, link)
      refute_match(/cb_tournament_cc_id/, link)
    end
  end

  test "Plan 17-06: genau ein Dienstkonto → cb_email im Link" do
    create_service_account("test17x06a")
    Carambus.stub(:config, OpenStruct.new) do
      res = TournamentPreparation::AppLinkBuilder.call(tournament: @tournament, server_context: @ctx)
      assert res[:ok], res.inspect
      assert_match(/cb_email=carambus-app-test17x06a-bridge%40carambus.de/, res[:app_link])
    end
  end

  test "Plan 17-06: zwei Dienstkonten → kein cb_email im Link" do
    create_service_account("test17x06a")
    create_service_account("test17x06b")
    Carambus.stub(:config, OpenStruct.new) do
      res = TournamentPreparation::AppLinkBuilder.call(tournament: @tournament, server_context: @ctx)
      assert res[:ok], res.inspect
      refute_match(/cb_email/, res[:app_link])
    end
  end

  test "Plan 17-06: kein Dienstkonto → kein cb_email im Link" do
    assert_equal 0, User.where("email LIKE ?", "carambus-app-%-bridge@carambus.de").count,
      "precondition: Test-DB ohne Dienstkonto"
    Carambus.stub(:config, OpenStruct.new) do
      res = TournamentPreparation::AppLinkBuilder.call(tournament: @tournament, server_context: @ctx)
      assert res[:ok], res.inspect
      refute_match(/cb_email/, res[:app_link])
    end
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
