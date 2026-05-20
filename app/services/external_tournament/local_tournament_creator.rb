# frozen_string_literal: true

module ExternalTournament
  # Plan 17-02: Lokal-Turnier-Anlage fuer app-gesteuerte Turniere (3BandMannschaftsTurnier).
  #
  # Legt ein lokales Carambus-Tournament OHNE TournamentPlan/Executor an (D-17-vision-1):
  # die App besitzt den Turnierplan, Carambus stellt nur Engine + Datenhaltung. Pflichtfelder
  # season (current) + polymorpher organizer (= Region). manual_assignment=true, weil die App
  # Spiele manuell auf Tische legt (umgeht zugleich die data["table_ids"]-Validierung).
  #
  # Idempotenz via tournaments.external_id (region-scoped). Erzeugt zusaetzlich einen schlanken
  # TournamentMonitor via Tournament#initialize_tournament_monitor — dessen do_reset ueberspringt
  # den plan-abhaengigen Block, wenn kein tournament_plan vorhanden ist (kein Crash).
  #
  # Hinweis: id >= Tournament::MIN_ID wird auf einem echten Local-Server durch die
  # ID-Sequence-Konfiguration garantiert (wie bei round_start-Games), nicht durch diesen Service.
  class LocalTournamentCreator
    Result = Struct.new(:tournament, :created?, keyword_init: true)

    def initialize(region:, payload:)
      @region = region
      @payload = payload.is_a?(Hash) ? payload.deep_symbolize_keys : payload
    end

    def call
      external_id = @payload[:external_id].to_s
      raise ArgumentError, "external_id is required" if external_id.blank?

      existing = Tournament.where(region_id: @region.id, external_id: external_id).first
      if existing
        ensure_tournament_monitor(existing)
        return Result.new(tournament: existing, created?: false)
      end

      tournament = Tournament.create!(
        season: Season.current_season,
        organizer: @region,
        region_id: @region.id,
        location_id: resolve_location_id,
        discipline: resolve_discipline,
        title: @payload[:title].presence || "App Tournament #{external_id}",
        external_id: external_id,
        manual_assignment: true,
        date: Time.current
      )
      ensure_tournament_monitor(tournament)
      Result.new(tournament: tournament, created?: true)
    end

    private

    def ensure_tournament_monitor(tournament)
      tournament.initialize_tournament_monitor if tournament.tournament_monitor.blank?
      tournament.reload
    end

    # Location optional; id (global) vor cc_id (region-scoped, D-15-07-A).
    def resolve_location_id
      loc = @payload[:location] || {}
      if loc[:id].present?
        Location.find_by(id: loc[:id])&.id
      elsif loc[:cc_id].present?
        Location.find_by(cc_id: loc[:cc_id], region_id: @region.id)&.id
      end
    end

    def resolve_discipline
      name = (@payload[:discipline] || {})[:name].presence
      return nil if name.blank?
      Discipline.find_by(name: name)
    end
  end
end
