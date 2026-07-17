# frozen_string_literal: true

require "test_helper"

# Charakterisierungstests für die vier Sync-Mechanismen, auf die der
# Phase-41-Datenabgleich-Task (region_taggings:fix_international_organizer_context,
# siehe Plan 02) angewiesen ist. Diese Tests rühren den Task selbst NICHT an —
# sie fixieren nur das darunterliegende ActiveRecord + PaperTrail-Verhalten,
# das 41-RESEARCH.md gegen den Gem-Source verifiziert hat.
class RegionTaggableSyncTest < ActiveSupport::TestCase
  # IDs >= MIN_ID (50_000_000) — niemals bestehende Produktions-ids wiederverwenden
  # (siehe 41-CONTEXT.md: UMB-Region und deren gestecktes Beispielturnier).
  REGION_BASE_ID = 52_000_200

  # Selektionskriterium (locked, siehe 41-CONTEXT.md), Byte-für-Byte identisch
  # mit der Query, die der Plan-02-Task ausführen wird:
  # betroffene Regions = alle Region, die Organizer eines region_id-IS-NULL
  # Tournament ODER League sind UND global_context != true.
  def affected_regions
    ids = (Tournament.where(region_id: nil, organizer_type: "Region").distinct.pluck(:organizer_id) +
           League.where(region_id: nil, organizer_type: "Region").distinct.pluck(:organizer_id)).uniq
    Region.where(id: ids).where.not(global_context: true)
  end

  test "selection returns only regions organizing a region_id-nil record with global_context not true" do
    season = seasons(:current)

    # region_intl: internationale Organizer-Region, noch nicht getaggt -> MUSS selektiert werden
    region_intl = Region.create!(id: REGION_BASE_ID + 1, shortname: "INTL", name: "Intl Body", global_context: false, region_id: nil)
    # region_fixed: bereits global_context: true -> NICHT selektiert (Idempotenz-Filter greift)
    region_fixed = Region.create!(id: REGION_BASE_ID + 2, shortname: "FIXD", name: "Already Global", global_context: true, region_id: nil)
    # region_reg: deutscher Regional-Verband, organisiert Turniere MIT region_id -> NICHT selektiert
    region_reg = Region.create!(id: REGION_BASE_ID + 3, shortname: "REGD", name: "Regional", global_context: false)
    # region_league: internationale Organizer-Region, organisiert eine League (nicht Tournament) -> MUSS selektiert werden
    region_league = Region.create!(id: REGION_BASE_ID + 4, shortname: "LEAG", name: "League Organizer", global_context: false, region_id: nil)

    Tournament.create!(
      title: "Intl Tournament",
      season: season,
      organizer: region_intl,
      single_or_league: "single",
      date: 1.week.from_now,
      region_id: nil
    )

    Tournament.create!(
      title: "Already Fixed Tournament",
      season: season,
      organizer: region_fixed,
      single_or_league: "single",
      date: 1.week.from_now,
      region_id: nil
    )

    Tournament.create!(
      title: "Regional Tournament",
      season: season,
      organizer: region_reg,
      single_or_league: "single",
      date: 1.week.from_now,
      region_id: region_reg.id
    )

    League.create!(
      name: "Intl League",
      shortname: "LEAG",
      organizer: region_league,
      season: season,
      region_id: nil
    )

    ids = affected_regions.pluck(:id)
    assert_includes ids, region_intl.id
    assert_includes ids, region_league.id, "Tournament OR League Union-Klausel muss League-Organizer ebenfalls selektieren"
    assert_not_includes ids, region_fixed.id
    assert_not_includes ids, region_reg.id
  end

  test "selection is idempotent: after global_context flips true the region drops out" do
    season = seasons(:current)

    region_intl = Region.create!(id: REGION_BASE_ID + 1, shortname: "INTL", name: "Intl Body", global_context: false, region_id: nil)

    Tournament.create!(
      title: "Intl Tournament",
      season: season,
      organizer: region_intl,
      single_or_league: "single",
      date: 1.week.from_now,
      region_id: nil
    )

    assert_includes affected_regions.pluck(:id), region_intl.id

    # update_columns genügt hier — dieser Test prüft die QUERY, nicht das Versionierungsverhalten
    region_intl.update_columns(global_context: true)

    assert_not_includes affected_regions.pluck(:id), region_intl.id, "ein zweiter Task-Lauf darf nichts mehr selektieren"
  end

  # Die folgenden zwei Tests laufen nur auf dem API-Server (PaperTrail ist nur
  # aktiv, wenn Carambus.config.carambus_api_url leer ist — siehe LocalProtector).

  test "region update! global_context_true creates a new version tagged global_context true from the record column" do
    skip_unless_api_server

    region_intl = Region.create!(id: REGION_BASE_ID + 5, shortname: "INT2", name: "Intl Body 2", global_context: false, region_id: nil)

    before = region_intl.versions.count
    # Echte Spaltenänderung -> normaler PaperTrail after_update-Callback feuert,
    # anschließend tagt RegionTaggable#update_version_region_data die Version
    # aus den AKTUELLEN Record-Spalten (nicht aus global_context?).
    region_intl.update!(global_context: true)

    assert_equal before + 1, region_intl.versions.count, "update! muss eine NEUE Version erzeugen (nicht bypassed)"

    v = region_intl.versions.reload.last
    assert_equal true, v.global_context, "Version muss aus der global_context-SPALTE des Records getaggt werden"
    # region_intl.region_id ist hier nil (Top-Level-Verband, keiner deutschen LV zugeordnet).
    # assert_nil statt assert_equal(nil, ...) vermeidet die Minitest-6-Deprecation-Warnung.
    if region_intl.region_id.nil?
      assert_nil v.region_id, "Version muss die EIGENE region_id-Spalte des Records tragen"
    else
      assert_equal region_intl.region_id, v.region_id, "Version muss die EIGENE region_id-Spalte des Records tragen"
    end
  end

  test "tournament touch_forces_version with blank object_changes and populated object, ordered after region version" do
    skip_unless_api_server

    region_intl = Region.create!(id: REGION_BASE_ID + 6, shortname: "INT3", name: "Intl Body 3", global_context: false, region_id: nil)
    tournament = Tournament.create!(
      id: REGION_BASE_ID + 7,
      title: "Intl Stuck Tournament",
      season: seasons(:current),
      organizer: region_intl,
      single_or_league: "single",
      date: 1.week.from_now,
      region_id: nil
    )

    region_intl.update!(global_context: true)
    region_version = region_intl.versions.reload.last

    before = tournament.versions.count
    # tournament.touch erzwingt eine Version trotz Null-Attribut-Diff
    # (Events::Update#changed_notably? touch-Spezialfall, siehe 41-RESEARCH.md Q3).
    tournament.touch

    tv = tournament.versions.reload.last
    assert_equal before + 1, tournament.versions.count, "touch muss trotz Null-Attribut-Diff eine Version erzeugen"
    assert tv.object_changes.blank?, "touch-Version darf keine object_changes speichern"
    assert tv.object.present?, "touch-Version muss den vollen object-Snapshot speichern (Client-Apply-Fallback)"
    assert tv.id > region_version.id, "Tournament-Version muss NACH der Region-Version geordnet sein (organizer muss beim Apply schon existieren)"
  end
end
