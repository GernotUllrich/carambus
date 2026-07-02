# frozen_string_literal: true

# Globaler Ausschnitt ("Scope-Band"): haelt Region/Saison als Session-Scope und stellt ihn
# ueber Current.scope bereit. SearchService wendet ihn als FK-Filter (region_id/season_id) an —
# nur dort, wo das Modell die Spalte fuehrt. Kein Eingriff in die User-Suche (params[:sSearch]),
# daher kein Leck ins Suchfeld.
#
# KEIN "Alle": jede Facette ist immer ein konkreter Wert. Defaults (bis User-Preferences in 02-02):
#   Region = NBV (Region[1], pragmatisch — aktuell einzige real genutzte Region; DBU ist einfach
#   eine waehlbare Region), Saison = aktuelle Saison. Regionale Server setzen die Region aus dem
#   Server-Kontext; globaler Server nutzt bis 02-02 diese Defaults.
# Branch/Disziplin-Facette folgt in 02-02 zusammen mit branch_id (BranchTaggable, analog RegionTaggable).
module Scopable
  extend ActiveSupport::Concern

  # Facette (Band-Feldname) => FK-Spalte auf den Modellen.
  SCOPE_FACETS = {
    "region" => "region_id",
    "season" => "season_id"
  }.freeze

  included do
    helper_method :current_scope, :current_region_id, :current_season_id,
                  :scope_region_options, :scope_season_options, :scope_season_transition?
  end

  private

  # Liest params[:scope] und merged in session[:scope]. Werte sind konkrete IDs (kein "Alle").
  def capture_scope
    session[:scope] ||= {}
    scope_params = params[:scope]
    return unless scope_params.respond_to?(:key?)

    SCOPE_FACETS.each_key do |facet|
      next unless scope_params.key?(facet)
      session[:scope][facet] = scope_params[facet].to_s.strip.presence
    end
  end

  # Stellt den Ausschnitt als FK-Filter fuer SearchService bereit (Current, pro Request).
  def set_current_scope
    Current.scope = {
      "region_id" => current_region_id,
      "season_id" => current_season_id
    }.compact
  end

  def current_scope
    (session[:scope] || {}).slice(*SCOPE_FACETS.keys)
  end

  # Immer ein konkreter Wert: Session -> Default (kein "Alle").
  def current_region_id
    (current_scope["region"].presence || default_region_id)&.to_i
  end

  def current_season_id
    (current_scope["season"].presence || default_season_id)&.to_i
  end

  # Default-Region: pragmatisch NBV (per shortname, sonst erste Region). 02-02: User-Preference/Server-Kontext.
  def default_region_id
    @default_region_id ||= Region.find_by(shortname: "NBV")&.id || Region.order(:id).first&.id
  end

  # Default-Saison. Im Saison-Umbruch (bis ~Mitte August) ist die kommende Saison noch in Planung
  # (Vorsaison abgeschlossen mit Endergebnissen/Ranglisten) -> dann gilt die Vorsaison als Default.
  # Feinere/User-Defaults folgen in 02-02.
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

  # True, wenn der Default aktuell die Vorsaison ist (Umbruch, keine explizite User-Wahl).
  def scope_season_transition?
    current_scope["season"].blank? && transition_previous_season.present?
  end

  # --- Options-Quellen fuer die Band-View (Werte = IDs, kein "Alle") ---

  def scope_region_options
    Region.order(:shortname).pluck(:shortname, :id)
  end

  def scope_season_options
    Season.order(id: :desc).limit(20).pluck(:name, :id)
  end
end
