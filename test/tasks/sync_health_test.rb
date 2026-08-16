# frozen_string_literal: true

require "test_helper"
require "rake"

# Task-Test fuer sync_health:invalid_census und sync_health:stale_tracer (Plan 37-02).
# Modelliert auf test/tasks/region_taggings_test.rb (load_tasks/reenable/clear).
#
# Der Census ist ein Messinstrument — seine Tests pruefen deshalb genau drei Dinge: dass er das
# Modell-Set ENTDECKT (eine gepflegte Liste altert lautlos), dass er richtig ZAEHLT, und dass er
# NICHTS SCHREIBT.
class SyncHealthTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  teardown do
    Rake::Task.clear
    ENV.delete("MODELS")
    ENV.delete("IDS")
  end

  # Eine GLOBALE Liga (id < MIN_ID), die die heutige Pflichtpruefung verletzt — dasselbe Vorbild wie
  # in test/models/version_test.rb (37-01): `validates :shortname, presence: true` fuer
  # Region-Veranstalter trifft 4 430 der 6 436 Ligen auf der Authority.
  def invalid_global_league(id: 3_800_001)
    l = League.new(id: id, name: "Alt-Liga #{id}", organizer_type: "Region",
      organizer_id: regions(:nbv).id, season: seasons(:current))
    l.shortname = nil
    l.unprotected = true
    l.save!(validate: false)
    assert_not l.valid?, "Testvoraussetzung: der Record muss ungueltig sein"
    l
  end

  def run_task(name)
    Rake::Task[name].reenable
    capture_io { Rake::Task[name].invoke }.first
  end

  # AC-2 — das Modell-Set wird entdeckt, nicht gepflegt.
  test "AC-2: das Modell-Set stammt aus LocalProtector, nicht aus einer Liste" do
    discovered = SyncHealthCensus.models

    assert_includes discovered, League
    assert_includes discovered, Tournament
    assert_includes discovered, Player

    # Unabhaengig nachgerechnet: wer LocalProtector einbindet, muss auftauchen. Faellt das
    # auseinander, ist irgendwo doch eine Liste entstanden.
    Rails.application.eager_load!
    expected = ApplicationRecord.descendants.select do |k|
      k.include?(LocalProtector) && !k.abstract_class? && k.table_exists?
    rescue
      false
    end

    assert_equal expected.map(&:name).sort, discovered.map(&:name).sort
    assert_operator discovered.size, :>=, 40, "die Replikationsflaeche sind ~50 Modelle"
  end

  test "MODELS= schraenkt das Set ein" do
    assert_equal %w[League Tournament], SyncHealthCensus.models("League,Tournament").map(&:name).sort
    assert_equal ["League"], SyncHealthCensus.models(" League ").map(&:name)
  end

  # AC-1 — Zahl UND Ursache.
  test "AC-1: der Census zaehlt den ungueltigen Record und nennt seine Meldung" do
    league = invalid_global_league

    result = SyncHealthCensus.scan(League)

    assert_operator result[:invalid], :>=, 1
    message, ids = result[:by_message].find { |_msg, list| list.include?(league.id) }
    assert message.present?, "der Record muss unter einer Meldung gruppiert sein"
    assert_match(/Shortname/i, message, "die Meldung nennt die verletzte Regel")
    assert_includes ids, league.id
  end

  test "AC-1: die Task-Ausgabe nennt Modell, Zahl und Meldung" do
    invalid_global_league(id: 3_800_002)
    ENV["MODELS"] = "League"

    output = run_task("sync_health:invalid_census")

    assert_match(/League/, output)
    assert_match(/ungueltig=/, output)
    assert_match(/Shortname/i, output)
    assert_match(/SUMME/, output)
  end

  test "IDS=1 gibt die IDs aus, die 37-03 braucht" do
    league = invalid_global_league(id: 3_800_003)
    ENV["MODELS"] = "League"
    ENV["IDS"] = "1"

    output = run_task("sync_health:invalid_census")

    assert_match(/IDs:/, output)
    assert_match(/#{league.id}/, output)
  end

  # AC-4 — read-only, nachweislich. Ein Messinstrument, das misst und dabei schreibt, ist keins.
  test "AC-4: der Census schreibt nichts" do
    league = invalid_global_league(id: 3_800_004)
    versions_before = Version.count
    updated_before = league.updated_at

    ENV["MODELS"] = "League,Tournament"
    run_task("sync_health:invalid_census")

    assert_equal versions_before, Version.count, "kein Record wurde geschrieben"
    assert_equal updated_before.to_i, league.reload.updated_at.to_i
    assert_nil league.shortname, "der ungueltige Record bleibt unangetastet"
  end

  # AC-3 — der Tracer trennt den BEWEIS von der blossen Ungueltigkeit.
  test "AC-3: der Tracer weist Records ohne source_kind aus und trennt sie von ungueltig" do
    league = invalid_global_league(id: 3_800_005)
    league.update_columns(source_kind: nil)

    output = run_task("sync_health:stale_tracer")

    assert_match(/ohne source_kind=/, output)
    assert_match(/davon ungueltig=/, output)
    assert_match(/#{league.id}/, output)
    assert_match(/SUMME beweisbar zurueckgesetzt/, output)
  end

  test "AC-4: auch der Tracer schreibt nichts" do
    versions_before = Version.count

    run_task("sync_health:stale_tracer")

    assert_equal versions_before, Version.count
  end
end
