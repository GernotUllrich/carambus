# frozen_string_literal: true

# Reine Ableitung des globalen Ausschnitts (Scope-Band) aus Session + User.
# Genutzt von Scopable (HTTP-Controller, before_action) UND SearchReflex (ActionCable-
# Live-Suche), damit die Default-Regeln nur an EINER Stelle existieren — der Reflex laeuft
# NICHT durch die Controller-before_actions, wuerde Current.scope sonst nicht kennen.
#
# region/season: immer ein konkreter Wert (kein "Alle"). Prioritaet:
#   Session -> User-Preference (preferences["scope"]) -> Server-Kontext (nur Region) -> Fallback
#   (Region=NBV pragmatisch, Saison=aktuelle bzw. im Umbruch die Vorsaison).
# branch: KEIN Fallback -> nil bedeutet "Alle Branchen" (kein Filter); eine gesetzte
#   Branch-Preference wird aber als Default respektiert.
class ScopeResolver
  SCOPE_FACETS = %w[region season branch].freeze

  def initialize(session_scope: nil, user: nil)
    @session_scope = (session_scope || {}).slice(*SCOPE_FACETS)
    @user = user
  end

  # FK-Filter-Hash fuer SearchService (Current.scope). branch_id nil faellt via compact raus.
  def fk_scope
    {
      "region_id" => region_id,
      "season_id" => season_id,
      "branch_id" => branch_id
    }.compact
  end

  # Immer konkret: Session -> Preference -> Server-Kontext -> NBV.
  def region_id
    (@session_scope["region"].presence || preferred("region") || server_context_region_id || default_region_id)&.to_i
  end

  # Immer konkret: Session -> Preference -> Default (aktuelle/Umbruch-Vorsaison).
  def season_id
    (@session_scope["season"].presence || preferred("season") || default_season_id)&.to_i
  end

  # Branch: Session -> Preference; sonst nil = "Alle Branchen".
  def branch_id
    (@session_scope["branch"].presence || preferred("branch")).presence&.to_i
  end

  # True, wenn der Saison-Default aktuell die Vorsaison ist (Umbruch, keine explizite Wahl:
  # weder Session noch Preference).
  def season_transition?
    @session_scope["season"].blank? && preferred("season").blank? && transition_previous_season.present?
  end

  private

  # Per-User-Default aus preferences["scope"][facet] (z.B. {"region" => 7}). nil, wenn kein User
  # oder kein Wert. Defensiv gegen fehlende/andersartige preferences.
  def preferred(facet)
    return nil unless @user.respond_to?(:preferences)
    @user.preferences.is_a?(Hash) ? @user.preferences.dig("scope", facet).presence : nil
  end

  # Server-Kontext-Region (nur regionale Server): Carambus.config.context = Region-Shortname
  # (Muster wie admin/settings_controller.rb). Globaler Server (context leer) -> nil.
  def server_context_region_id
    return @server_context_region_id if defined?(@server_context_region_id)

    ctx = Carambus.config.context.to_s.strip.presence
    @server_context_region_id = ctx && Region.find_by(shortname: ctx)&.id
  end

  # Default-Region: pragmatisch NBV (per shortname, sonst erste Region).
  def default_region_id
    @default_region_id ||= Region.find_by(shortname: "NBV")&.id || Region.order(:id).first&.id
  end

  # Default-Saison. Im Saison-Umbruch (bis ~Mitte August) ist die kommende Saison noch in Planung
  # (Vorsaison abgeschlossen mit Endergebnissen/Ranglisten) -> dann gilt die Vorsaison als Default.
  def default_season_id
    @default_season_id ||= (transition_previous_season || Season.current_season)&.id
  end

  # Vorsaison, solange wir uns im Saison-Umbruch befinden (heute <= 15.08. des Startjahres der
  # aktuellen Saison); sonst nil. Wird auch fuer den dezenten Band-Hinweis genutzt.
  def transition_previous_season
    return @transition_previous_season if defined?(@transition_previous_season)

    @transition_previous_season = begin
      current = Season.current_season
      start_year = current&.name.to_s[/\A(\d{4})/, 1]&.to_i
      if current && start_year && Date.current <= Date.new(start_year, 8, 15)
        previous_season(current)
      end
    end
  end

  # Vorsaison ueber ba_id (ordnungsstabil, unabhaengig von lokalen id>=MIN_ID-Records).
  def previous_season(season)
    return nil unless season&.ba_id
    Season.where("ba_id < ?", season.ba_id).order(ba_id: :desc).first
  end
end
