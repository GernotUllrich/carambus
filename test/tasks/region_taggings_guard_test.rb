# frozen_string_literal: true

require "test_helper"
require "rake"

# Regressions-/Charakterisierungstests für den Recurrence-Guard (Plan 02-01).
# Belegt: die derivation-basierten Re-Tag-Tasks brechen ohne FORCE_DERIVATION_RETAG=1 ab
# (schützen die kuratierte globale Taggung), und MIT Override reproduzieren sie den Hazard
# (global_context-Downgrade) — der Grund, warum der Guard existiert.
# Kein skip_unless_api_server nötig: Guard + Downgrade laufen über update_columns, kein PaperTrail.
class RegionTaggingsGuardTest < ActiveSupport::TestCase
  # Eigener id-Offset >= MIN_ID (50_000_000), getrennt von den anderen region_taggings-Testdateien.
  REGION_BASE_ID = 52_000_300

  DERIVATION_TASKS = %w[
    region_taggings:update_all
    region_taggings:update_existing_versions
    region_taggings:set_global_context
  ].freeze

  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    ENV.delete("FORCE_DERIVATION_RETAG")
  end

  teardown do
    ENV.delete("FORCE_DERIVATION_RETAG")
    Rake::Task.clear
  end

  def invoke(task_name)
    Rake::Task[task_name].reenable
    Rake::Task[task_name].invoke
  end

  test "all derivation retag tasks abort without override and mutate nothing" do
    region = Region.create!(id: REGION_BASE_ID + 1, shortname: "GRD1", name: "Guarded Global",
      global_context: true, region_id: nil)

    DERIVATION_TASKS.each do |task_name|
      assert_raises(RuntimeError, "#{task_name} muss ohne Override abbrechen") do
        capture_io { invoke(task_name) }
      end
    end

    assert_equal true, region.reload.global_context, "keiner der Guards darf mutieren"
    assert_nil region.reload.region_id
  end

  # Der Hazard: update_all setzt pro Record global_context = record.global_context? (rake-Zeile ~164).
  # Für eine kuratierte globale Region liefert global_context? aber false -> Downgrade.
  # Deterministisch geprüft über die Ableitung selbst (kein Full-DB-Lauf, der in der
  # Fixture-Transaktion durch einen rescue-ten Fehler PG::InFailedSqlTransaction auslöst).
  test "the derivation update_all relies on would downgrade a curated global region (the hazard)" do
    region = Region.create!(id: REGION_BASE_ID + 2, shortname: "GRD2", name: "Downgrade Me",
      global_context: true, region_id: nil)

    assert_equal false, region.global_context?,
      "global_context? liefert für eine global getaggte Region false -> update_all würde sie downgraden"
  end

  # Der Override öffnet das Gate: mit FORCE_DERIVATION_RETAG=1 greift der Recurrence-Guard nicht mehr.
  # Robust gegen das PG-Test-Artefakt: falls der Full-DB-Lauf in der Fixture-Transaktion scheitert,
  # darf es NICHT mehr die Guard-Meldung sein.
  test "override opens the gate: guard no longer blocks update_all" do
    Region.create!(id: REGION_BASE_ID + 3, shortname: "GRD3", name: "Override On",
      global_context: true, region_id: nil)
    ENV["FORCE_DERIVATION_RETAG"] = "1"

    raised = nil
    begin
      capture_io { invoke("region_taggings:update_all") }
    rescue => e
      raised = e
    end

    refute_match(/Recurrence-Schutz/, raised&.message.to_s,
      "mit Override darf der Guard nicht mehr greifen (verbleibende Fehler sind Test-Transaktions-Artefakte)")
  ensure
    ENV.delete("FORCE_DERIVATION_RETAG")
  end

  test "RegionTaggable.update_existing_versions class method is gated without override" do
    assert_raises(RuntimeError, "Klassenmethode muss ohne Override abbrechen") do
      RegionTaggable.update_existing_versions
    end
  end
end
