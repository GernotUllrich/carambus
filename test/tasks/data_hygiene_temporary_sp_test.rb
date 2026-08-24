# frozen_string_literal: true

require "test_helper"
require "rake"

# Tests fuer `data_hygiene:temporary_season_participations` (Plan 39-01).
#
# Der Task entfernt alle SeasonParticipation im Status "temporary" (Regel b,
# Betreiber-Entscheidung 2026-08-24) und ist rollenbewusst: auf der Authority erzeugt das
# `.destroy` die Version, die die Loeschung nach unten repliziert; auf einem local Server
# entsteht keine Version (LocalProtector aktiviert has_paper_trail dort nicht), dafuer muss
# der Guard gegen globale Records ausdruecklich entsperrt werden.
#
# WICHTIG fuer die Rollen-Tests: `LocalProtector#disallow_saving_global_records` gibt unter
# `Rails.env.test?` frueh `true` zurueck, und `LocalProtectorTestOverride` (test_helper.rb)
# schaltet den Schutz ohnehin ab — der Guard laesst sich hier also nicht echt ausloesen.
# Der Rollenzweig wird deshalb an der gesetzten `unprotected`-Flagge geprueft, nicht an
# einem erwarteten Rollback.
class DataHygieneTemporarySpTest < ActiveSupport::TestCase
  BASE_ID = 53_900_000

  # Zeichnet auf, fuer welche Records der Task `unprotected = true` gesetzt hat.
  # Ein prepend-Spy statt einer Mock-Bibliothek — mocha ist im Projekt nicht verfuegbar.
  module UnprotectedSpy
    def self.calls
      @calls ||= []
    end

    def self.reset!
      @calls = []
    end

    def unprotected=(value)
      UnprotectedSpy.calls << [id, value]
      super
    end
  end
  SeasonParticipation.prepend(UnprotectedSpy)

  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    ENV.delete("ARMED")
    UnprotectedSpy.reset!
    @season = seasons(:current)
    @club = clubs(:bcw)
    @temporary = 3.times.map do |i|
      SeasonParticipation.create!(id: BASE_ID + i, season: @season, club: @club,
        player: create_player(i), status: "temporary")
    end
    @active = SeasonParticipation.create!(id: BASE_ID + 100, season: @season, club: @club,
      player: create_player(100), status: "active")
    @ohne_status = SeasonParticipation.create!(id: BASE_ID + 101, season: @season, club: @club,
      player: create_player(101), status: nil)
  end

  teardown do
    ENV.delete("ARMED")
    Rake::Task.clear
  end

  def create_player(i)
    Player.create!(id: BASE_ID + 500 + i, lastname: "Test#{i}", firstname: "SP")
  end

  def run_task
    Rake::Task["data_hygiene:temporary_season_participations"].reenable
    Rake::Task["data_hygiene:temporary_season_participations"].invoke
  end

  test "DRY-RUN berichtet und aendert nichts" do
    before = SeasonParticipation.count
    out = capture_io { run_task }.first

    assert_equal before, SeasonParticipation.count
    assert_equal 3, SeasonParticipation.where(status: "temporary").where(id: @temporary.map(&:id)).count
    assert_match(/DRY-RUN/, out)
    assert_match(/Wirkung auf Player#club/, out)
  end

  test "ARMED entfernt temporary und laesst active/nil unangetastet" do
    ENV["ARMED"] = "1"
    capture_io { run_task }

    assert_equal 0, SeasonParticipation.where(id: @temporary.map(&:id)).count
    assert SeasonParticipation.exists?(@active.id), "active darf nicht geloescht werden"
    assert SeasonParticipation.exists?(@ohne_status.id), "status nil darf nicht geloescht werden"
  end

  test "zweiter Lauf ist folgenlos (idempotent)" do
    ENV["ARMED"] = "1"
    capture_io { run_task }
    after_first = SeasonParticipation.count

    out = capture_io { run_task }.first
    assert_equal after_first, SeasonParticipation.count
    assert_match(/nichts zu tun \(idempotent\)/, out)
  end

  test "auf der Authority erzeugt jede Loeschung genau eine destroy-Version" do
    skip_unless_api_server
    ENV["ARMED"] = "1"
    ids = @temporary.map(&:id)
    before = Version.where(item_type: "SeasonParticipation", event: "destroy", item_id: ids).count

    out = capture_io { run_task }.first

    after = Version.where(item_type: "SeasonParticipation", event: "destroy", item_id: ids).count
    assert_equal 3, after - before, "Ohne Version bliebe der Record auf jedem Regional-Server liegen"
    assert_match(/Replikation ist gesichert/, out)
  end

  test "local Server entsperrt den Guard, die Authority nicht" do
    ENV["ARMED"] = "1"

    ApplicationRecord.stub(:local_server?, true) do
      capture_io { run_task }
    end
    gesetzt = UnprotectedSpy.calls.select { |(id, value)| @temporary.map(&:id).include?(id) && value }
    assert_equal 3, gesetzt.size, "auf einem local Server blockt before_destroy globale Records"

    # Gegenprobe: als Authority wird die Flagge nicht angefasst — der Guard ist dort inaktiv,
    # und der Verzicht haelt den Rollenunterschied im Code sichtbar.
    UnprotectedSpy.reset!
    weitere = 2.times.map do |i|
      SeasonParticipation.create!(id: BASE_ID + 200 + i, season: @season, club: @club,
        player: create_player(200 + i), status: "temporary")
    end
    ApplicationRecord.stub(:local_server?, false) do
      capture_io { run_task }
    end
    assert_equal 0, SeasonParticipation.where(id: weitere.map(&:id)).count, "geloescht werden sie trotzdem"
    assert_empty UnprotectedSpy.calls.select { |(_, value)| value },
      "als Authority setzt der Task unprotected nicht"
  end
end
