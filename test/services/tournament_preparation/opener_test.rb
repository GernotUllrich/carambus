# frozen_string_literal: true

require "test_helper"

class TournamentPreparation::OpenerTest < ActiveSupport::TestCase
  setup do
    @tournament = tournaments(:local)
    # Lokales Test-Turnier braucht ein tournament_cc, sonst Frühabbruch.
    @tournament_cc = TournamentCc.create!(
      cc_id: 80_903, context: "nbv", tournament: @tournament,
      status: "open"
    )
    @tournament.reload
  end

  test "tournament nil → :tournament_invalid, kein Sync" do
    sync_calls = 0
    Version.stub(:update_from_carambus_api, ->(**_) { sync_calls += 1 }) do
      res = TournamentPreparation::Opener.call(tournament: nil)
      refute res[:ok]
      assert_equal :tournament_invalid, res[:reason]
    end
    assert_equal 0, sync_calls
  end

  test "tournament ohne tournament_cc → :tournament_invalid" do
    t = Tournament.create!(
      title: "Ohne TCC", season_id: 50_000_001,
      organizer_id: 50_000_001, organizer_type: "Region",
      discipline_id: 50_000_001, state: "tournament_mode_defined",
      date: 1.week.from_now
    )
    res = TournamentPreparation::Opener.call(tournament: t)
    refute res[:ok]
    assert_equal :tournament_invalid, res[:reason]
  end

  test "Carambus.config.carambus_api_url blank → :no_authority_configured, kein Sync, Link mitgegeben" do
    sync_calls = 0
    Carambus.stub(:config, OpenStruct.new(carambus_api_url: "", carambus_domain: "lvh.me:3007")) do
      Version.stub(:update_from_carambus_api, ->(**_) { sync_calls += 1 }) do
        res = TournamentPreparation::Opener.call(tournament: @tournament)
        refute res[:ok]
        assert_equal :no_authority_configured, res[:reason]
        assert_equal @tournament.title, res[:tournament_name]
        assert_match(%r{/tournaments/#{@tournament.id}\z}, res[:preparation_url])
      end
    end
    assert_equal 0, sync_calls, "Sync darf bei Authority-Lage NICHT laufen"
  end

  test "Sync-Erfolg → ok:true, Status-Block, absolute URL" do
    sync_calls = []
    Carambus.stub(:config, OpenStruct.new(carambus_api_url: "http://api.example", carambus_domain: "lvh.me:3007")) do
      Version.stub(:update_from_carambus_api, ->(**kw) { sync_calls << kw }) do
        res = TournamentPreparation::Opener.call(tournament: @tournament)
        assert res[:ok], res.inspect
        assert_equal @tournament.title, res[:tournament_name]
        # Status-Block: 5 Felder
        assert_equal "open", res[:status][:tournament_cc_status]
        assert_equal "tournament_mode_defined", res[:status][:tournament_state]
        assert_equal true, res[:status][:plan_chosen] # Fixture hat tournament_plan_id
        assert_kind_of Integer, res[:status][:seedings_count]
        assert_kind_of Integer, res[:status][:games_count]
        assert_match(%r{lvh\.me:3007/tournaments/#{@tournament.id}\z}, res[:preparation_url])
      end
    end
    # Genau EIN Sync-Aufruf mit dem richtigen Argument
    assert_equal 1, sync_calls.size
    assert_equal @tournament.id, sync_calls.first[:update_tournament_from_cc]
  end

  test "Sync-Exception → :sync_failed, Link trotzdem mitgegeben (AC-3)" do
    Carambus.stub(:config, OpenStruct.new(carambus_api_url: "http://api.example", carambus_domain: "lvh.me:3007")) do
      Version.stub(:update_from_carambus_api, ->(**_) { raise StandardError, "Authority offline" }) do
        res = TournamentPreparation::Opener.call(tournament: @tournament)
        refute res[:ok]
        assert_equal :sync_failed, res[:reason]
        assert_equal "Authority offline", res[:error]
        # Sportwart bekommt trotzdem den Link
        assert_match(%r{/tournaments/#{@tournament.id}\z}, res[:preparation_url])
      end
    end
  end
end
