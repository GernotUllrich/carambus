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
    ENV.delete("LIMIT")
    ENV.delete("ONLY_IDS")
    ENV.delete("ARMED")
  end

  # Eine GLOBALE Liga (id < MIN_ID), die eine heute noch greifende Validierung verletzt.
  #
  # NICHT MEHR UEBER `shortname`: seit `07d82ec0` gilt die Pflicht nur noch `on: :create` — der
  # BillardArea-Altbestand konnte sie nie erfuellen, und jeder Massenlauf kippte daran.
  # Bestandsrecords sind damit gueltig.
  #
  # STATTDESSEN DIE `cc_id`-EINDEUTIGKEIT (greift weiterhin auf UPDATE): zwei Ligen derselben Region
  # und Saison mit derselben `cc_id`. Bewusst NICHT die Namens-Eindeutigkeit — die haengt am `name`,
  # und Tests, die den Namen umschreiben (Snapshot-Faelle), machten den Record dabei versehentlich
  # wieder gueltig.
  def invalid_global_league(id: 3_800_001)
    shared = {organizer_type: "Region", organizer_id: regions(:nbv).id,
              season: seasons(:current), cc_id: 880_000 + (id % 1000)}

    twin = League.new(shared.merge(id: id + 10_000_000, name: "Zwilling #{id}", shortname: "ZW"))
    twin.unprotected = true
    twin.save!(validate: false)

    l = League.new(shared.merge(id: id, name: "Alt-Liga #{id}", shortname: "AL"))
    l.unprotected = true
    l.save!(validate: false)
    assert_not l.valid?, "Testvoraussetzung: der Record muss ungueltig sein"
    l
  end

  def run_task(name)
    Rake::Task[name].reenable
    capture_io { Rake::Task[name].invoke }.first
  end

  def run_task_armed(name)
    ENV["ARMED"] = "1"
    run_task(name)
  ensure
    ENV.delete("ARMED")
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
    assert_match(/must be unique/i, message, "die Meldung nennt die verletzte Regel")
    assert_includes ids, league.id
  end

  test "AC-1: die Task-Ausgabe nennt Modell, Zahl und Meldung" do
    invalid_global_league(id: 3_800_002)
    ENV["MODELS"] = "League"

    output = run_task("sync_health:invalid_census")

    assert_match(/League/, output)
    assert_match(/ungueltig=/, output)
    assert_match(/must be unique/i, output)
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
    assert_not league.valid?, "der ungueltige Record bleibt unangetastet"
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

  # ---------------------------------------------------------------------------
  # 37-03 — der Nachlauf. Ab hier wird GESCHRIEBEN.
  # ---------------------------------------------------------------------------

  # AC-1 — der Trockenlauf zaehlt, was der Census zaehlt, und schreibt nichts.
  test "AC-1 (37-03): der Trockenlauf nennt die Menge und schreibt nichts" do
    invalid_global_league(id: 3_900_001)
    versions_before = Version.count
    ENV["MODELS"] = "League"

    output = run_task("sync_health:redeliver")

    assert_match(/DRY-RUN/, output)
    assert_match(/League\s+\d+ Records wuerden je eine neue Version bekommen/, output)
    assert_equal versions_before, Version.count, "der Trockenlauf darf nichts schreiben"
  end

  # AC-2 — genau eine Version, Record unveraendert und weiterhin ungueltig.
  test "AC-2 (37-03): der ARMED-Lauf erzeugt genau eine Version und aendert den Record nicht" do
    skip_unless_api_server

    league = invalid_global_league(id: 3_900_002)
    versions_before = league.versions.count
    ENV["MODELS"] = "League"
    ENV["ONLY_IDS"] = league.id.to_s

    run_task_armed("sync_health:redeliver")

    league.reload
    assert_equal versions_before + 1, league.versions.count, "genau eine neue Version"
    assert_not league.valid?, "der Nachlauf repariert keine Daten"
    assert_not league.valid?, "der Record bleibt ungueltig — er wird nur ausgeliefert"
  end

  # AC-3 — keine Kollateral-Aenderung durch fremde Callbacks.
  test "AC-3 (37-03): branch_id bleibt nil, die Version traegt keine branch_id-Aenderung" do
    skip_unless_api_server

    league = invalid_global_league(id: 3_900_003)
    league.update_columns(branch_id: nil)
    ENV["MODELS"] = "League"
    ENV["ONLY_IDS"] = league.id.to_s

    run_task_armed("sync_health:redeliver")

    assert_nil league.reload.branch_id, "set_branch_id muss ausgehaengt sein (trifft 5 810 Ligen auf Prod)"
    changes = league.versions.last.object_changes.to_s
    assert_no_match(/branch_id/, changes, "keine unbeauftragte branch_id-Aenderung im Sync-Batch")
  end

  # AC-4 — Begrenzung, damit der erste Prod-Lauf klein bleiben kann.
  test "AC-4 (37-03): LIMIT begrenzt die Menge je Modell" do
    skip_unless_api_server

    3.times { |i| invalid_global_league(id: 3_900_010 + i) }
    versions_before = Version.count
    ENV["MODELS"] = "League"
    ENV["LIMIT"] = "1"

    run_task_armed("sync_health:redeliver")

    assert_equal versions_before + 1, Version.count, "LIMIT=1 schreibt genau eine Version"
  end

  # AC-5 (neu, aus der Generalprobe) — die Version muss die Region des Records tragen.
  # Ohne sie greift der Sync-Filter `region_id IS NULL OR region_id = ?` fuer JEDE Instanz, und wo der
  # Record lokal fehlt, legt der Apply ihn an: tbv bekaeme tausende NBV-Ligen.
  test "AC-5 (37-03): die Nachlauf-Version traegt region_id und global_context des Records" do
    skip_unless_api_server

    league = invalid_global_league(id: 3_900_030)
    league.update_columns(region_id: regions(:nbv).id, global_context: false)
    ENV["MODELS"] = "League"
    ENV["ONLY_IDS"] = league.id.to_s

    run_task_armed("sync_health:redeliver")

    version = league.reload.versions.order(:id).last
    assert_equal regions(:nbv).id, version.region_id,
      "ungetaggt reiste die Version an ALLE Instanzen — auch an Server ohne diesen Record"
    assert_equal false, version.global_context
  end

  test "AC-5 (37-03): Modelle ohne region_id bleiben korrekt ungetaggt" do
    # DisciplineCc/TournamentPlan tragen keine Region — sie sind global, und `nil` ist dort richtig.
    assert_nothing_raised do
      SyncHealthCensus.stamp_region!(TournamentPlan.new, Version.new)
    end
  end

  # AC-2 (verschaerft, aus der Generalprobe): der Nachlauf soll AUSLIEFERN, nicht aendern.
  # Auf der Dev-DB stempelte `stamp_source_kind` nebenbei 4 430 Ligen — weil dort `source_kind` leer
  # war. Der Task muss so etwas ZEIGEN, statt es still im Sync-Batch mitreisen zu lassen.
  test "AC-2 (37-03): Zusatzaenderungen fremder Callbacks werden gemeldet" do
    skip_unless_api_server

    league = invalid_global_league(id: 3_900_040)
    # Ohne source_url, aber mit ba_id klassifiziert `Provenance::Classifier` als :ba — der Stempel
    # greift also und macht den Record beim Speichern dirty.
    league.update_columns(source_kind: nil, source_url: nil, ba_id: 990_001)
    ENV["MODELS"] = "League"
    ENV["ONLY_IDS"] = league.id.to_s

    output = run_task_armed("sync_health:redeliver")

    assert_match(/ZUSATZAENDERUNGEN/, output, "der Stempel-Callback muss sichtbar werden")
    assert_match(/source_kind/, output)
  end

  test "AC-2 (37-03): der Trockenlauf zeigt die Zusatzaenderung vorab — ohne zu schreiben" do
    league = invalid_global_league(id: 3_900_041)
    league.update_columns(source_kind: nil, source_url: nil, ba_id: 990_002)
    versions_before = Version.count
    ENV["MODELS"] = "League"

    output = run_task("sync_health:redeliver")

    assert_match(/Stichprobe/, output)
    assert_match(/source_kind/, output)
    assert_equal versions_before, Version.count, "die Vorschau laeuft in einer zurueckgerollten Transaktion"
    assert_nil league.reload.source_kind, "und darf den Record nicht veraendern"
  end

  # Die Gegenprobe zur zentralen Option: ohne `validate: false` ginge es nicht.
  # Haelt fest, WARUM sie im Task steht — genau daran ist der erste ARMED-Lauf in 34-01 gescheitert.
  test "Gegenprobe: ein Speichern MIT Validierung scheitert an genau diesen Records" do
    league = invalid_global_league(id: 3_900_020)

    assert_not league.save, "Vorbedingung: mit Validierung nicht speicherbar"
    assert league.save(validate: false), "ohne Validierung schon — deshalb steht die Option im Task"
  end

  # Die Aushaengung darf keinen Callback an Modelle haengen, die ihn nie hatten.
  test "without_branch_tagging fasst nur BranchTaggable-Modelle an" do
    before = Seeding._save_callbacks.select { |c| c.kind == :before }.map(&:filter)

    SyncHealthCensus.without_branch_tagging([League, Seeding]) { nil }

    after = Seeding._save_callbacks.select { |c| c.kind == :before }.map(&:filter)
    assert_equal before, after, "Seeding kennt set_branch_id nicht und darf ihn nicht bekommen"
    assert_includes League._save_callbacks.select { |c| c.kind == :before }.map(&:filter), :set_branch_id,
      "League muss den Callback danach wieder tragen"
  end
end
