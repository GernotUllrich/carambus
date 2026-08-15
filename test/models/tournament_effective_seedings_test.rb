# frozen_string_literal: true

require "test_helper"

# Characterization-Test fuer den Meldung<->Teilnahme-Diskriminator (Plan 32-03, Konzern A).
# Beweist, dass Tournament#effective_seedings / #has_local_seedings? das bisher ~10x duplizierte
# has_local-Idiom (has_local ? "id >= MIN_ID" : "id < MIN_ID") EXAKT reproduzieren.
# LocalProtector ist im Test deaktiviert (LocalProtectorTestOverride in test_helper.rb), daher koennen
# Seedings mit expliziten ids ober-/unterhalb Seeding::MIN_ID angelegt werden.
class TournamentEffectiveSeedingsTest < ActiveSupport::TestCase
  MIN = Seeding::MIN_ID
  # Lokale Test-ids weit oberhalb MIN_ID, um Kollisionen mit Fixture-Seedings (ab 50_000_001) zu vermeiden.
  LOCAL = 50_900_000

  # Rohes Idiom, inline nachgebaut — die Referenz, gegen die der Helfer verglichen wird.
  def raw_idiom_ids(tournament)
    has_local = tournament.seedings.where("seedings.id >= #{MIN}").any?
    scope = has_local ? "seedings.id >= #{MIN}" : "seedings.id < #{MIN}"
    tournament.seedings.where(scope).order(:id).pluck(:id)
  end

  def build_tournament(id)
    Tournament.create!(
      id: id,
      title: "Effective-Seedings Char-Test #{id}",
      season_id: 50_000_001,
      organizer_id: 50_000_001,
      organizer_type: "Region",
      discipline_id: 50_000_004,
      tournament_plan_id: 50_000_100,
      player_class: "1",
      state: "tournament_mode_defined",
      date: 2.weeks.from_now,
      handicap_tournier: false
    )
  end

  def add_seeding(tournament, id, state: "registered", position: 1)
    Seeding.create!(
      id: id,
      player_id: [50_001_001, 50_001_002].sample,
      tournament_id: tournament.id,
      tournament_type: "Tournament",
      state: state,
      position: position
    )
  end

  test "(a) CC-only: effective_seedings == die < MIN_ID-Menge, has_local? false" do
    t = build_tournament(9_600_001)
    add_seeding(t, 9_600_100, position: 1)
    add_seeding(t, 9_600_101, position: 2)

    assert_not t.has_local_seedings?
    assert_equal [9_600_100, 9_600_101], t.effective_seedings.order(:id).pluck(:id)
    assert_equal raw_idiom_ids(t), t.effective_seedings.order(:id).pluck(:id)
  end

  test "(b) local-only: effective_seedings == die >= MIN_ID-Menge, has_local? true" do
    t = build_tournament(9_600_002)
    add_seeding(t, LOCAL + 1, position: 1)
    add_seeding(t, LOCAL + 2, position: 2)

    assert t.has_local_seedings?
    assert_equal [LOCAL + 1, LOCAL + 2], t.effective_seedings.order(:id).pluck(:id)
    assert_equal raw_idiom_ids(t), t.effective_seedings.order(:id).pluck(:id)
  end

  test "(c) gemischt: effective_seedings == NUR die lokalen (>= MIN_ID), < MIN_ID ignoriert" do
    t = build_tournament(9_600_003)
    add_seeding(t, 9_600_200, position: 1)     # CC-Meldung
    add_seeding(t, LOCAL + 10, position: 2)    # lokaler Teilnehmer

    assert t.has_local_seedings?
    assert_equal [LOCAL + 10], t.effective_seedings.order(:id).pluck(:id)
    assert_equal raw_idiom_ids(t), t.effective_seedings.order(:id).pluck(:id)
  end

  test "(d) no_show: effective_seedings filtert state NICHT; Aufrufer schliesst no_show aus" do
    t = build_tournament(9_600_004)
    add_seeding(t, LOCAL + 20, state: "registered", position: 1)
    add_seeding(t, LOCAL + 21, state: "no_show", position: 2)

    # Helfer enthaelt das no_show-Seeding (keine state-Filterung im Helfer)
    assert_equal [LOCAL + 20, LOCAL + 21], t.effective_seedings.order(:id).pluck(:id)
    assert_equal raw_idiom_ids(t), t.effective_seedings.order(:id).pluck(:id)

    # Gegenprobe: der Aufrufer-typische no_show-Ausschluss wirkt weiterhin
    assert_equal [LOCAL + 20], t.effective_seedings.where.not(state: "no_show").order(:id).pluck(:id)
  end

  # ── Konzern B (Plan 32-05): state-aware Auswahl NUR im all-lokalen Fall auf region_server ──
  # cc_less_seedings? liest ApplicationRecord.region_server? → je Test stubben (minitest/mock, wie 32-02).

  test "(e) AC-1: globale Meldung vorhanden → MIN_ID-Zweig, state der lokalen egal (NBV-historisch-sicher)" do
    t = build_tournament(9_600_005)
    add_seeding(t, 9_600_300, state: "registered", position: 1)   # CC-Meldung (< MIN_ID)
    add_seeding(t, LOCAL + 110, state: "registered", position: 2) # lokaler Teilnehmer, noch registered (historisch)

    # Selbst als region_server bleibt es beim MIN_ID-Zweig, weil eine globale Meldung existiert.
    ApplicationRecord.stub(:region_server?, true) do
      assert_equal [LOCAL + 110], t.effective_seedings.order(:id).pluck(:id)
      assert_equal raw_idiom_ids(t), t.effective_seedings.order(:id).pluck(:id)
    end
  end

  test "(f) AC-2: all-lokal + region_server + finalisiert → seeded/participated, nicht registered" do
    t = build_tournament(9_600_006)
    add_seeding(t, LOCAL + 120, state: "registered", position: 1)   # nur gemeldet, nicht angetreten
    add_seeding(t, LOCAL + 121, state: "seeded", position: 2)       # Teilnehmer
    add_seeding(t, LOCAL + 122, state: "participated", position: 3) # Teilnehmer

    ApplicationRecord.stub(:region_server?, true) do
      assert_equal [LOCAL + 121, LOCAL + 122], t.effective_seedings.order(:id).pluck(:id)
    end
  end

  test "(g) AC-2: all-lokal + region_server + nur registered (vor Finalisierung) → registered als Fallback" do
    t = build_tournament(9_600_007)
    add_seeding(t, LOCAL + 130, state: "registered", position: 1)
    add_seeding(t, LOCAL + 131, state: "registered", position: 2)

    ApplicationRecord.stub(:region_server?, true) do
      assert_equal [LOCAL + 130, LOCAL + 131], t.effective_seedings.order(:id).pluck(:id)
    end
  end

  test "(h) Gate: all-lokal aber region_server? false → MIN_ID-Zweig (Rolle gated den State-Zweig)" do
    t = build_tournament(9_600_008)
    add_seeding(t, LOCAL + 140, state: "registered", position: 1)
    add_seeding(t, LOCAL + 141, state: "seeded", position: 2)

    ApplicationRecord.stub(:region_server?, false) do
      # kein State-Zweig: MIN_ID liefert BEIDE lokalen unabhaengig vom state
      assert_equal [LOCAL + 140, LOCAL + 141], t.effective_seedings.order(:id).pluck(:id)
      assert_equal raw_idiom_ids(t), t.effective_seedings.order(:id).pluck(:id)
    end
  end
end
