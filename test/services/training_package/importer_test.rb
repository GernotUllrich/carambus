# frozen_string_literal: true

require "test_helper"

class TrainingPackage::ImporterTest < ActiveSupport::TestCase
  include TrainingPackageTestHelper

  setup do
    wipe_training_tables!
    @graph = build_training_graph
    @package = via_file(TrainingPackage::Exporter.call)
  end

  # --- Trockenlauf und Rundlauf ------------------------------------------------

  test "dry run classifies every row as new in an empty target and writes nothing" do
    wipe_training_tables!

    report = import(@package)

    assert report.ok?, report.errors.inspect
    refute report.applied
    TrainingPackage::TABLES.each do |table|
      assert_equal @package["tables"][table].size, report.tables[table][:new], table
    end
    assert training_row_counts.values.all?(&:zero?), "Trockenlauf darf nichts schreiben"
  end

  test "apply into an empty target reproduces the package exactly, parents before children" do
    wipe_training_tables!

    report = import(@package, apply: true)

    assert report.ok?, report.errors.inspect
    assert report.applied
    reexported = via_file(TrainingPackage::Exporter.call)
    assert_equal @package["tables"], reexported["tables"]
    assert @graph[:child].id < @graph[:parent].id, "Testvoraussetzung: Kind hat die kleinere ID"
  end

  test "importing the same package again changes nothing" do
    report = import(@package, apply: true)

    assert report.ok?, report.errors.inspect
    TrainingPackage::TABLES.each do |table|
      assert_equal 0, report.tables[table][:new], table
      assert_equal 0, report.tables[table][:changed], table
      assert_equal @package["tables"][table].size, report.tables[table][:unchanged], table
    end
  end

  test "a changed row is detected and written" do
    row = @package["tables"]["table_zones"].first
    row["label"] = "Umbenannte Zone"
    rehash!(@package)

    report = import(@package, apply: true)

    assert report.ok?, report.errors.inspect
    assert_equal 1, report.tables["table_zones"][:changed]
    zone = TableZone.find(row["id"])
    assert_equal "Umbenannte Zone", zone.label
    assert_equal Time.iso8601(row["updated_at"]), zone.updated_at, "Zeitstempel kommen aus dem Paket, nicht von jetzt"
  end

  test "keeps translations_synced_at from the package although the title changed" do
    synced = "2026-09-01T08:00:00.000000Z"
    row = @package["tables"]["training_concepts"].find { |r| r["id"] == @graph[:dominance].id }
    row["title"] = "Dominanz (neu)"
    row["title_de"] = "Dominanz (neu)"
    row["translations_synced_at"] = synced
    rehash!(@package)

    report = import(@package, apply: true)

    assert report.ok?, report.errors.inspect
    assert_equal Time.iso8601(synced), @graph[:dominance].reload.translations_synced_at
  end

  # --- Abbruch vor jedem Schreiben ----------------------------------------------

  test "aborts on a digest mismatch" do
    @package["tables"]["table_zones"].first["label"] = "manipuliert"
    assert_aborts(@package, /Prüfsumme/)
  end

  test "aborts when the target schema lacks the package schema version" do
    @package["manifest"]["schema_version"] = "29990101000000"
    assert_aborts(@package, /Schema/)
  end

  test "aborts on a column the target does not know" do
    @package["tables"]["table_zones"].first["erfundene_spalte"] = 1
    rehash!(@package)
    assert_aborts(@package, /erfundene_spalte/)
  end

  test "aborts on a reference that points outside the package" do
    @package["tables"]["shot_events"].first["shot_id"] = 6_999_999
    rehash!(@package)
    assert_aborts(@package, /shot_events.*shot_id/)
  end

  test "aborts when a referenced discipline is missing in the target" do
    @package["tables"]["training_concept_disciplines"].first["discipline_id"] = 6_999_999
    rehash!(@package)
    assert_aborts(@package, /Discipline/)
  end

  test "aborts when the target holds the same key under another id" do
    TableZone.create!(id: gid, key: "pkg_other", label: "Andere", zone_type: "custom")
    @package["tables"]["table_zones"].first["key"] = "pkg_other"
    rehash!(@package)
    assert_aborts(@package, /pkg_other/)
  end

  test "aborts on a local id inside the package" do
    @package["tables"]["table_zones"].first["id"] = ApplicationRecord::MIN_ID + 1
    rehash!(@package)
    assert_aborts(@package, /MIN_ID|lokal/)
  end

  test "aborts when the role does not match the server" do
    assert_aborts(@package, /authority/, role: "authority")
  end

  # --- Verwaiste Datensaetze -----------------------------------------------------

  test "without prune, rows only in the target are reported and kept" do
    extra = TrainingConcept.create!(id: gid, title: "Nur im Ziel", axis: "conception")

    report = import(@package, apply: true)

    assert report.ok?, report.errors.inspect
    assert_equal [extra.id], report.tables["training_concepts"][:only_in_target]
    assert TrainingConcept.exists?(extra.id)
  end

  test "with prune from the package, orphans are deleted children first" do
    orphan_parent = TrainingExample.create!(id: gid, title: "Waise Eltern")
    orphan_child = TrainingExample.create!(id: gid, title: "Waise Kind", parent: orphan_parent)
    orphan_shot = Shot.create!(id: gid, training_example: orphan_child, shot_type: "ideal", sequence_number: 1,
      title: "Waise Stoss", source_language: "de")
    ShotEvent.create!(id: gid, shot: orphan_shot, sequence_number: 1, event_type: "sperre")
    @package["manifest"]["prune"] = true

    report = import(@package, apply: true)

    assert report.ok?, report.errors.inspect
    refute TrainingExample.exists?(orphan_parent.id)
    refute TrainingExample.exists?(orphan_child.id)
    refute Shot.exists?(orphan_shot.id)
    assert_equal 2, report.tables["training_examples"][:deleted]
    assert TrainingExample.exists?(@graph[:parent].id), "Paketdaten bleiben"
  end

  # --- Atomar ----------------------------------------------------------------------

  test "a failure late in the import rolls back everything written before" do
    wipe_training_tables!
    @package["tables"]["shot_events"].first["sequence_number"] = 0 # verletzt die Validierung
    rehash!(@package)

    report = import(@package, apply: true)

    refute report.ok?
    refute report.applied
    assert training_row_counts.values.all?(&:zero?), "nichts darf uebrig bleiben"
  end

  # --- Sequenzen je Zielrolle ---------------------------------------------------------

  test "authority: sequences move into the authority id block" do
    with_role_environment(local: false, basename: "carambus_api") do
      preserving_sequences do
        set_sequence("training_concepts", 1) # sonst stuende sie in der Testumgebung ohnehin ueber 50 Mio.

        report = import(@package, apply: true, role: "authority")

        assert report.ok?, report.errors.inspect
        assert_operator next_id("training_concepts"), :>, TrainingPackage::AUTHORITY_ID_BLOCK
      end
    end
  end

  test "training authority: sequences move behind the highest id below the authority block" do
    TrainingConcept.create!(id: TrainingPackage::AUTHORITY_ID_BLOCK + 3, title: "Ausreisser", axis: "conception")
    @package = via_file(TrainingPackage::Exporter.call)
    with_role_environment(local: false, basename: "carambus_train") do
      preserving_sequences do
        set_sequence("training_concepts", 1)

        report = import(@package, apply: true, role: "training_authority")

        assert report.ok?, report.errors.inspect
        assert_equal @graph[:dam].id + 1, next_id("training_concepts")
      end
    end
  end

  test "staging: sequences stay untouched" do
    preserving_sequences do
      before = sequence_value("training_concepts")
      import(@package, apply: true)
      assert_equal before, sequence_value("training_concepts")
    end
  end

  # --- Versionen (nur API-Szenario) -------------------------------------------------

  test "on an API server every written row leaves a version, a repeat import none" do
    skip_unless_api_server
    wipe_training_tables!
    with_role_environment(local: false, basename: "carambus_api") do
      preserving_sequences do
        assert_difference -> { PaperTrail::Version.count }, @package["manifest"]["counts"].values.sum do
          import(@package, apply: true, role: "authority")
        end
        assert_no_difference -> { PaperTrail::Version.count } do
          import(@package, apply: true, role: "authority")
        end
      end
    end
  end

  private

  # Staging verlangt einen Local Server. Der Test stellt ihn her, statt ihn aus der lokalen
  # carambus.yml zu erwarten — so laeuft die Datei im Local- wie im API-Szenario.
  def import(package, apply: false, role: "staging")
    run = proc { TrainingPackage::Importer.call(package: package, role: role, apply: apply) }
    (role == "staging") ? ApplicationRecord.stub(:local_server?, true, &run) : run.call
  end

  def assert_aborts(package, pattern, role: "staging")
    before = training_row_counts
    report = import(package, apply: true, role: role)
    refute report.ok?, "Abbruch erwartet"
    assert report.errors.any? { |e| e.match?(pattern) }, "erwartet #{pattern.inspect}, war: #{report.errors.inspect}"
    assert_equal before, training_row_counts, "vor dem Abbruch darf nichts geschrieben sein"
  end

  def rehash!(package)
    package["manifest"]["sha256"] = TrainingPackage.digest(package["tables"])
  end

  def with_role_environment(local:, basename:, &block)
    Carambus.config.basename = basename
    ApplicationRecord.stub(:local_server?, local, &block)
  end

  def sequence_name(table)
    ActiveRecord::Base.connection.select_value("SELECT pg_get_serial_sequence('#{table}', 'id')")
  end

  def sequence_value(table)
    ActiveRecord::Base.connection.select_one("SELECT last_value, is_called FROM #{sequence_name(table)}")
  end

  def set_sequence(table, value)
    ActiveRecord::Base.connection.execute("SELECT setval('#{sequence_name(table)}', #{value})")
  end

  def next_id(table)
    ActiveRecord::Base.connection.select_value("SELECT nextval('#{sequence_name(table)}')")
  end

  # setval ist nicht transaktional — ohne Rueckstellung wandert die Sequenz ueber den Test hinaus.
  def preserving_sequences
    saved = TrainingPackage::TABLES.index_with { |t| sequence_value(t) }
    yield
  ensure
    saved&.each do |table, v|
      ActiveRecord::Base.connection.execute(
        "SELECT setval('#{sequence_name(table)}', #{v["last_value"].to_i}, #{v["is_called"] ? "true" : "false"})"
      )
    end
  end
end
