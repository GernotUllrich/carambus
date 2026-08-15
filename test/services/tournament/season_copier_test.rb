# frozen_string_literal: true

require "test_helper"

# Plan 27-01: Saison-Kopie der Turnier-STRUKTUR.
# Leitplanke aus dem CC-Rollover-Incident: niemals Ergebnisse, Seedings oder fremde Provenienz kopieren.
class Tournament::SeasonCopierTest < ActiveSupport::TestCase
  setup do
    @region = regions(:nbv)
    @from = seasons(:previous)   # 2024/2025
    @to = seasons(:current)      # 2025/2026
    @distance = 1

    # Quellturnier mit voller Provenienz, Seedings und Spielen — nichts davon darf mitkommen.
    @source = Tournament.create!(
      title: "Landesmeisterschaft Dreiband",
      shortname: "LM3B",
      season: @from,
      organizer: @region,
      region_id: @region.id,
      date: Time.zone.local(2024, 10, 12, 10, 0), # Samstag
      end_date: Time.zone.local(2024, 10, 13, 18, 0),
      player_class: "I",
      modus: "kickoff_switches_with_set",
      balls_goal: 150,
      innings_goal: 40,
      ba_id: 987_654,
      source_url: "https://example.invalid/tournament/1",
      sync_date: 1.day.ago,
      ba_state: "finished",
      state: "results_published"
    )
    player = Player.create!(lastname: "TEST", firstname: "Tim", fl_name: "T. Test")
    @source.seedings.create!(player_id: player.id, position: 1)
  end

  def copier(armed: false, from: @from, to: @to)
    Tournament::SeasonCopier.new(region: @region, from_season: from, to_season: to, armed: armed)
  end

  test "dry-run schreibt nichts, meldet aber was entstehen wuerde" do
    result = nil
    assert_no_difference("Tournament.count") do
      result = copier.call
    end

    assert_equal 0, result.created
    assert_equal 1, result.planned.size
    assert_equal "Landesmeisterschaft Dreiband", result.planned.first[:title]
  end

  test "ARMED kopiert die Struktur" do
    assert_difference("Tournament.count", 1) do
      copier(armed: true).call
    end

    copy = Tournament.where(season_id: @to.id, organizer: @region).order(:id).last
    assert_equal @source.title, copy.title
    assert_equal @source.shortname, copy.shortname
    assert_equal @source.player_class, copy.player_class
    assert_equal @source.balls_goal, copy.balls_goal
    assert_equal @source.innings_goal, copy.innings_goal
    assert_equal @source.modus, copy.modus
    assert_equal @to.id, copy.season_id
  end

  test "Datum wandert um n mal 52 Wochen und behaelt den Wochentag" do
    copier(armed: true).call
    copy = Tournament.where(season_id: @to.id, organizer: @region).order(:id).last

    expected = @source.date + (@distance * 52).weeks
    assert_equal expected.to_date, copy.date.to_date
    assert_equal @source.date.strftime("%A"), copy.date.strftime("%A"), "Wochentag muss erhalten bleiben"
    assert_equal (@source.end_date + (@distance * 52).weeks).to_date, copy.end_date.to_date
  end

  test "Provenienz, Ergebnisse und Laufzeit-Zustand werden NICHT kopiert" do
    copier(armed: true).call
    copy = Tournament.where(season_id: @to.id, organizer: @region).order(:id).last

    assert_nil copy.ba_id, "ba_id ist UNIQUE — darf nie mitkopiert werden"
    assert_nil copy.source_url
    assert_nil copy.sync_date
    assert_nil copy.ba_state
    assert_equal "new_tournament", copy.state
    assert_equal 0, copy.seedings.count, "Seedings duerfen nicht mitkopiert werden"
    assert_equal 0, copy.games.count
    refute copy.auto_upload_to_cc, "CC-los angelegt"
  end

  test "Kopie ist als Entwurf markiert und kennt ihre Quelle" do
    copier(armed: true).call
    copy = Tournament.where(season_id: @to.id, organizer: @region).order(:id).last

    assert_equal true, copy.data["draft"]
    assert_equal @source.id, copy.data["copied_from_tournament_id"]
  end

  test "zweiter ARMED-Lauf legt keine Dublette an" do
    copier(armed: true).call

    result = nil
    assert_no_difference("Tournament.count") do
      result = copier(armed: true).call
    end
    assert_equal 1, result.skipped_existing
    assert_equal 0, result.created
  end

  # Tournament setzt in einem before_save `self.date = Time.at(0) if date.blank?` — ein Turnier
  # "ohne Datum" traegt also das Epoch-Datum. Genau das muss der Copier als unbrauchbar erkennen.
  test "Turnier ohne brauchbares Datum (Epoch) wird uebersprungen" do
    t = Tournament.create!(title: "Ohne Datum", season: @from, organizer: @region, date: nil)
    assert_equal 1970, t.date.year, "Vorbedingung: before_save setzt Epoch"

    result = copier.call

    assert_equal 1, result.skipped_no_date
  end

  test "Liga-Turniere bleiben aussen vor" do
    Tournament.create!(title: "Liga-Sache", season: @from, organizer: @region,
      date: Time.zone.local(2024, 11, 2, 10, 0), single_or_league: "league")

    result = copier.call

    assert_equal 1, result.planned.size, "nur die Einzelmeisterschaft"
    refute_includes result.planned.map { |h| h[:title] }, "Liga-Sache"
  end

  test "Zielsaison vor Quellsaison wird abgelehnt" do
    assert_raises(ArgumentError) do
      copier(from: @to, to: @from).call
    end
  end

  # --- Auswahl einzelner Turniere (UI auf Tournament#index) ---

  test "candidates zeigt jedes Quellturnier mit Status, ohne zu schreiben" do
    zweites = Tournament.create!(title: "LM Einband", season: @from, organizer: @region,
      region_id: @region.id, date: Time.zone.local(2024, 11, 9, 10, 0))

    candidates = nil
    assert_no_difference("Tournament.count") do
      candidates = copier.candidates
    end

    assert_equal 2, candidates.size
    assert candidates.all?(&:copyable?)
    assert_equal [@source.id, zweites.id].sort, candidates.map { |c| c.tournament.id }.sort
    # Das Turnier-Objekt haengt dran, damit die UI Disziplin/Branch rendern kann.
    assert_kind_of Tournament, candidates.first.tournament
    assert_equal @source.date.to_date + 52.weeks, candidates.find { |c| c.tournament.id == @source.id }.new_date.to_date
  end

  test "candidates markiert bereits kopierte Turniere" do
    copier(armed: true).call

    statuses = copier.candidates.map(&:status)

    assert_equal [:already_copied], statuses
  end

  test "only_source_ids kopiert nur die Auswahl" do
    zweites = Tournament.create!(title: "LM Einband", season: @from, organizer: @region,
      region_id: @region.id, date: Time.zone.local(2024, 11, 9, 10, 0))

    result = Tournament::SeasonCopier.new(region: @region, from_season: @from, to_season: @to,
      armed: true, only_source_ids: [zweites.id]).call

    assert_equal 1, result.created
    # Auf die KOPIEN einschraenken: in der Zielsaison liegen bereits Fixture-Turniere der Region.
    kopien = Tournament.where(season_id: @to.id, organizer: @region)
      .select { |t| t.data.is_a?(Hash) && t.data["copied_from_tournament_id"].present? }
    assert_equal ["LM Einband"], kopien.map(&:title)
    assert_equal zweites.id, kopien.first.data["copied_from_tournament_id"]
  end

  # Eine leere Auswahl ist eine AUSSAGE ("nichts angehakt"), kein fehlender Parameter — sonst
  # wuerde ein versehentlich leeres Formular die ganze Saison kopieren.
  test "leere Auswahl kopiert nichts" do
    result = nil
    assert_no_difference("Tournament.count") do
      result = Tournament::SeasonCopier.new(region: @region, from_season: @from, to_season: @to,
        armed: true, only_source_ids: []).call
    end

    assert_equal 0, result.created
    assert_empty result.planned
  end

  test "planned traegt die Quell-ID fuer die Auswahl" do
    result = copier.call

    assert_equal [@source.id], result.planned.map { |h| h[:id] }
  end
end
