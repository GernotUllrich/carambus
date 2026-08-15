# frozen_string_literal: true

require "test_helper"

# Plan 36-03: der Job stoesst die Authority an, die ERGEBNISZEILEN frisch einzulesen.
# Gegenstueck zu EntryListSyncJobTest; die Guards sind bewusst identisch.
class GameResultSyncJobTest < ActiveJob::TestCase
  def released_tournament(overrides = {})
    Tournament.create!({
      title: "Freigegeben", shortname: "FREI", season: seasons(:current),
      organizer: regions(:nbv), region_id: regions(:nbv).id, discipline: disciplines(:one),
      date: Time.zone.local(2025, 10, 11, 10, 0)
    }.merge(overrides))
  end

  test "enqueue_for reiht auf einem lokalen Server ein" do
    Carambus.config.carambus_api_url = "http://local.test"
    t = released_tournament

    assert_enqueued_with(job: GameResultSyncJob,
      args: [{region_id: regions(:nbv).id, season_id: seasons(:current).id}]) do
      GameResultSyncJob.enqueue_for(tournament: t)
    end
  ensure
    Carambus.config.carambus_api_url = ""
  end

  test "enqueue_for reiht auf der Authority NICHT ein (kein Selbst-Anstoß)" do
    Carambus.config.carambus_api_url = ""   # leer => Authority
    t = released_tournament

    assert_no_enqueued_jobs { GameResultSyncJob.enqueue_for(tournament: t) }
  end

  test "enqueue_for überspringt einen Entwurf" do
    Carambus.config.carambus_api_url = "http://local.test"
    t = released_tournament(data: {"draft" => true})

    assert_no_enqueued_jobs { GameResultSyncJob.enqueue_for(tournament: t) }
  ensure
    Carambus.config.carambus_api_url = ""
  end

  test "enqueue_for überspringt ein Turnier ohne Region" do
    Carambus.config.carambus_api_url = "http://local.test"
    t = released_tournament
    t.update_column(:region_id, nil)

    assert_no_enqueued_jobs { GameResultSyncJob.enqueue_for(tournament: t) }
  ensure
    Carambus.config.carambus_api_url = ""
  end

  test "perform ruft update_from_carambus_api mit import_game_results" do
    captured = nil
    Version.stub(:update_from_carambus_api, ->(opts) { captured = opts }) do
      GameResultSyncJob.new.perform(region_id: 16, season_id: 18)
    end

    # NICHT import_entry_list — der Parameter waehlt auf der Authority den Importer aus
    # (versions_controller.rb:102 vs. :112).
    assert_equal 16, captured[:import_game_results]
    assert_nil captured[:import_entry_list]
    assert_equal 18, captured[:season_id]
    assert_equal 16, captured[:region_id], "region_id filtert die zurückgelieferten Versionen"
  end
end
