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
end
