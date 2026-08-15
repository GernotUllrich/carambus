# frozen_string_literal: true

# Plan 27-01: Kopiert die TURNIER-STRUKTUR einer Saison in eine Zielsaison, um den Kaltstart eines
# Verbands zu loesen, der von der ClubCloud auf Carambus wechselt. Historische Turnierdaten sind fuer
# alle Verbaende aus dem CC-Scrape vorhanden und damit die natuerliche Vorlage.
#
# Verwendung (dry-run ist Default):
#   Tournament::SeasonCopier.new(region:, from_season:, to_season:).call
#   Tournament::SeasonCopier.new(region:, from_season:, to_season:, armed: true).call
#
# ⚠️ LEITPLANKE (Memory cc-season-rollover-contamination): Genau dieses Kopieren hat die ClubCloud
# beim Saison-Rollover falsch gemacht — sie kopierte den Vorjahres-Teilbaum INKLUSIVE Ergebnissen und
# Original-Datteln und erzeugte damit monatelange Datenverwirrung. Dieser Service kopiert
# ausschliesslich Struktur, verschiebt das Datum und markiert das Ergebnis als Entwurf:
#   - keine Seedings, keine Games, kein TournamentMonitor
#   - keine Provenienz fremder Quellen (ba_id/source_url/external_id/sync_date/ba_state)
#   - state bleibt der Default (new_tournament)
#
# PORO (kein ApplicationService) gemaess der Konvention von Tournament::RankingCalculator.
class Tournament::SeasonCopier
  # Struktur-Attribute, die eine Turnier-"Vorlage" ausmachen. Bewusst als WHITELIST gefuehrt:
  # eine Blacklist wuerde bei jeder neuen Spalte stillschweigend zu viel kopieren.
  STRUCTURE_ATTRIBUTES = %w[
    title shortname discipline_id modus age_restriction player_class tournament_plan_id
    innings_goal balls_goal handicap_tournier location_id location_text single_or_league
    team_size sets_to_win sets_to_play timeout timeouts kickoff_switches_with fixed_display_left
    color_remains_with_set allow_follow_up allow_overflow continuous_placements manual_assignment
    admin_controlled gd_has_prio time_out_warm_up_first_min time_out_warm_up_follow_up_min
  ].freeze

  # Eine Saison = 52 Wochen, NICHT "1 Jahr": so bleibt der Wochentag erhalten (Turniere liegen auf
  # Wochenenden — ein Samstagsturnier soll wieder auf einen Samstag fallen).
  WEEKS_PER_SEASON = 52

  Result = Struct.new(:created, :skipped_existing, :skipped_no_date, :planned, keyword_init: true)

  # Ein Quellturnier mit seinem Kopier-Status. Traegt das Turnier-Objekt selbst, damit die UI
  # daraus Disziplin, Branch und Datum rendern kann, ohne die Auswahllogik nachzubauen.
  #   :copyable       wird kopiert
  #   :already_copied liegt in der Zielsaison bereits als Kopie
  #   :no_date        Platzhalter-Datum (Epoch) — als Vorlage unbrauchbar
  Candidate = Struct.new(:tournament, :status, :new_date, keyword_init: true) do
    def copyable? = status == :copyable
  end

  # `only_source_ids: nil` = alle (Verhalten des Rake-Tasks, unveraendert).
  # Eine LEERE Liste bedeutet "nichts ausgewaehlt" und kopiert bewusst nichts — nicht "alle".
  def initialize(region:, from_season:, to_season:, armed: false, only_source_ids: nil)
    @region = region
    @from_season = from_season
    @to_season = to_season
    @armed = armed
    @only_source_ids = only_source_ids&.map(&:to_i)
  end

  # Vorschau fuer die UI: alle Quellturniere mit Status, ohne etwas zu schreiben.
  # Ignoriert `only_source_ids` — die Auswahl trifft der Anwender ja erst auf dieser Liste.
  def candidates
    distance = season_distance
    return [] if distance.nil? || !distance.positive?

    all_source_tournaments.map do |source|
      if !usable_date?(source.date)
        Candidate.new(tournament: source, status: :no_date)
      elsif already_copied?(source)
        Candidate.new(tournament: source, status: :already_copied)
      else
        Candidate.new(tournament: source, status: :copyable, new_date: shift(source.date, distance))
      end
    end
  end

  def call
    distance = season_distance
    raise ArgumentError, "Saison-Abstand nicht bestimmbar (#{@from_season&.name} -> #{@to_season&.name})" if distance.nil?
    raise ArgumentError, "Zielsaison liegt nicht nach der Quellsaison" unless distance.positive?

    result = Result.new(created: 0, skipped_existing: 0, skipped_no_date: 0, planned: [])

    source_tournaments.find_each do |source|
      unless usable_date?(source.date)
        result.skipped_no_date += 1
        next
      end
      if already_copied?(source)
        result.skipped_existing += 1
        next
      end

      new_date = shift(source.date, distance)
      result.planned << {id: source.id, title: source.title, from: source.date.to_date, to: new_date.to_date}

      next unless @armed

      create_copy(source, distance)
      result.created += 1
    end

    result
  end

  private

  # Einzelmeisterschaften der Quellsaison, die diese Region ausrichtet. Liga-Turniere bleiben aussen
  # vor — deren Struktur kommt aus dem Liga-Betrieb, nicht aus einer Saison-Kopie.
  def source_tournaments
    scope = all_source_tournaments
    scope = scope.where(id: @only_source_ids) unless @only_source_ids.nil?
    scope
  end

  def all_source_tournaments
    ::Tournament
      .where(season_id: @from_season.id, organizer_type: "Region", organizer_id: @region.id)
      # NICHT `where.not(single_or_league: "league")`: SQL schliesst NULL-Werte aus einem !=-Vergleich
      # aus — und die meisten Turniere haben dort NULL. Sie waeren stillschweigend nie kopiert worden.
      .where("single_or_league IS NULL OR single_or_league != ?", "league")
      .includes(:discipline)
      .order(:date)
  end

  # Idempotenz: in der Zielsaison darf pro Quellturnier hoechstens eine Kopie liegen. Der Schluessel
  # steht im data-Hash, weil es dafuer keine Spalte gibt (und keine Migration geben soll).
  #
  # Die Ziel-Turniere werden EINMAL eingesammelt statt je Quellturnier neu geladen: seit `candidates`
  # dieselbe Pruefung fuer die Vorschau nutzt, liefe die alte Fassung sonst zweimal ueber die
  # gesamte Zielsaison, je Quellturnier.
  def copied_source_ids
    @copied_source_ids ||= ::Tournament
      .where(season_id: @to_season.id, organizer_type: "Region", organizer_id: @region.id)
      .filter_map { |t| t.data["copied_from_tournament_id"].to_i if t.data.is_a?(Hash) }
      .to_set
  end

  def already_copied?(source)
    copied_source_ids.include?(source.id)
  end

  def create_copy(source, distance)
    attrs = source.attributes.slice(*STRUCTURE_ATTRIBUTES)
    attrs["season_id"] = @to_season.id
    attrs["region_id"] = @region.id
    attrs["organizer_type"] = "Region"
    attrs["organizer_id"] = @region.id
    attrs["date"] = shift(source.date, distance)
    attrs["end_date"] = shift(source.end_date, distance) if source.end_date.present?
    # CC-los angelegt — kein automatischer Upload (konsistent zu Plan 25-01).
    attrs["auto_upload_to_cc"] = false
    attrs["data"] = {"draft" => true, "copied_from_tournament_id" => source.id}

    ::Tournament.skip_cable_ready_updates do
      ::Tournament.create!(attrs)
    end
  end

  # Ein Turnier "ohne Datum" gibt es in diesem Modell nicht: `Tournament` setzt in einem before_save
  # `self.date = Time.at(0) if date.blank?` (tournament.rb:352). Ein Epoch-Datum ist also der
  # Platzhalter fuer "unbekannt" — eine Kopie davon waere Muell und wird uebersprungen.
  def usable_date?(time)
    time.present? && time.year > 1970
  end

  def shift(time, distance)
    return nil if time.blank?

    time + (distance * WEEKS_PER_SEASON).weeks
  end

  # Abstand in Saisons aus den NAMEN ("2024/2025" -> 2024), nicht aus IDs: IDs sind nicht
  # zwingend luecken- oder reihenfolgetreu.
  def season_distance
    from_year = start_year(@from_season)
    to_year = start_year(@to_season)
    return nil if from_year.nil? || to_year.nil?

    to_year - from_year
  end

  def start_year(season)
    name = season&.name.to_s
    return nil unless ::Season::VALID_NAME_REGEX.match?(name)

    name[0, 4].to_i
  end
end
