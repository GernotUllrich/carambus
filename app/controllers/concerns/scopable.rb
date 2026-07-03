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
# Branch ist die EINE Ausnahme zur "kein Alle"-Regel: "Alle Branchen" (Default), weil Branch genuin
# quer-interessant ist und (noch) unklassifizierte Disziplinen (branch_id=nil) sonst durchs Raster fielen.
module Scopable
  extend ActiveSupport::Concern

  # Facette (Band-Feldname) => FK-Spalte auf den Modellen. "club" ist die kontext-sensitive
  # 3. Facette fuer Modelle mit scope_extra_facet == :club (Player) und wird join-basiert gefiltert.
  SCOPE_FACETS = {
    "region" => "region_id",
    "season" => "season_id",
    "branch" => "branch_id",
    "club" => "club_id"
  }.freeze

  included do
    helper_method :current_scope, :current_region_id, :current_season_id, :current_branch_id,
                  :current_club_id,
                  :scope_region_options, :scope_season_options, :scope_branch_options,
                  :scope_club_options, :scope_extra_facet,
                  :scope_season_transition?,
                  :current_region_shortname, :current_season_name, :current_branch_name,
                  :scope_indicator_label, :scope_indicator_primary, :scope_indicator_extra
  end

  private

  # Liest params[:scope] und merged in session[:scope]. Werte sind konkrete IDs (kein "Alle").
  def capture_scope
    session[:scope] ||= {}
    scope_params = params[:scope]
    return unless scope_params.respond_to?(:key?)

    captured = false
    SCOPE_FACETS.each_key do |facet|
      next unless scope_params.key?(facet)
      session[:scope][facet] = scope_params[facet].to_s.strip.presence
      captured = true
    end

    persist_scope_preference if captured
  end

  # Write-back: angemeldete User merken sich ihren Ausschnitt ueber Sessions hinweg
  # (preferences["scope"]). Nur bei echter Facetten-Aenderung, nur fuer current_user,
  # fehlerrobust (Preference-Schreiben darf den Request nie abbrechen).
  def persist_scope_preference
    return unless current_user

    prefs = current_user.preferences.is_a?(Hash) ? current_user.preferences.deep_dup : {}
    scope_pref = prefs["scope"].is_a?(Hash) ? prefs["scope"] : {}
    # Gesetzte Werte uebernehmen, geleerte ("Alle Branchen") entfernen -> Default greift wieder.
    current_scope.each { |facet, val| val.present? ? scope_pref[facet] = val : scope_pref.delete(facet) }
    prefs["scope"] = scope_pref
    current_user.update(preferences: prefs)
  rescue => e
    Rails.logger.warn("[Scopable] scope-preference write-back failed: #{e.message}")
  end

  # Stellt den Ausschnitt als FK-Filter fuer SearchService bereit (Current, pro Request).
  def set_current_scope
    Current.scope = scope_resolver.fk_scope
  end

  # Gemeinsame Ableitung (Session + User) — dieselbe Einheit nutzt auch SearchReflex (Live-Suche),
  # damit die Default-Regeln nur an einer Stelle existieren. Pro Request memoisiert.
  def scope_resolver
    @scope_resolver ||= ScopeResolver.new(session_scope: session[:scope], user: current_user)
  end

  def current_scope
    (session[:scope] || {}).slice(*SCOPE_FACETS.keys)
  end

  # View-nahe Helper: delegieren an den Resolver (Werte fuer die Band-Selects).
  def current_region_id
    scope_resolver.region_id
  end

  def current_season_id
    scope_resolver.season_id
  end

  def current_branch_id
    scope_resolver.branch_id
  end

  def current_club_id
    scope_resolver.club_id
  end

  # Aktuelles Modell (aus dem Controller-Namen) und dessen Scope-Zusatzfacette (:branch|:club).
  # Steuert, welche 3. Facette das Band zeigt. Defensiv: unbekannter Controller -> :branch (Default).
  def scope_model
    controller_name.classify.constantize
  rescue StandardError
    nil
  end

  def scope_extra_facet
    (scope_model.respond_to?(:scope_extra_facet) ? scope_model.scope_extra_facet : nil) || :branch
  end

  # True, wenn der Default aktuell die Vorsaison ist (Umbruch, keine explizite User-Wahl).
  def scope_season_transition?
    scope_resolver.season_transition?
  end

  # --- Anzeige-Label fuer den Region-Indikator im Sidebar-Kopf (reine Anzeige, kein State) ---
  # Uebersetzen die Resolver-IDs in Anzeigetext. Defensiv gegen nil (fehlende Records).

  def current_region_shortname
    Region.find_by(id: current_region_id)&.shortname
  end

  def current_season_name
    Season.find_by(id: current_season_id)&.name
  end

  # nil, wenn keine konkrete Branch gewaehlt ist ("Alle Branchen" -> im Label weggelassen).
  def current_branch_name
    id = current_branch_id
    id && Branch.find_by(id: id)&.name
  end

  # nil, wenn kein konkreter Club gewaehlt ist ("Alle Clubs"). Anzeige: shortname, sonst name.
  def current_club_name
    id = current_club_id
    return nil unless id
    club = Club.find_by(id: id)
    club && (club.shortname.presence || club.name.presence)
  end

  # Primaerzeile des Indikators: "NBV · 2025/26" (Region · Saison) — kurz, passt einzeilig.
  def scope_indicator_primary
    [current_region_shortname, current_season_name].compact.join(" · ")
  end

  # 3. Facette (Zweitzeile): Club auf players, sonst Branch — folgt scope_extra_facet, kann lang sein
  # (Club-Name) und wird im Sidebar-Kopf auf eine eigene Zeile gesetzt. nil, wenn nicht konkret gewaehlt.
  def scope_indicator_extra
    scope_extra_facet == :club ? current_club_name : current_branch_name
  end

  # Volltext (fuer Titel/aria/Present-Check): "NBV · 2025/26" bzw. "... · 1. BC Schwerin".
  def scope_indicator_label
    [scope_indicator_primary, scope_indicator_extra].compact.reject(&:blank?).join(" · ")
  end

  # --- Options-Quellen fuer die Band-View (Werte = IDs, kein "Alle") ---

  def scope_region_options
    Region.order(:shortname).pluck(:shortname, :id)
  end

  def scope_season_options
    Season.order(id: :desc).limit(20).pluck(:name, :id)
  end

  def scope_branch_options
    Branch.order(:name).pluck(:name, :id)
  end

  # Clubs der aktuellen Scope-Region (kaskadiert Region -> Club). Anzeige = shortname, sonst name;
  # namenlose Stub-/Placeholder-Clubs (weder shortname noch name) werden weggelassen. Werte = IDs,
  # kein "Alle" (Ausnahme wie Branch: das Band ergaenzt "Alle Clubs" selbst).
  def scope_club_options
    display = Arel.sql("COALESCE(NULLIF(clubs.shortname, ''), clubs.name)")
    Club.where(region_id: current_region_id)
        .where.not(name: [nil, ""])
        .order(display)
        .pluck(display, :id)
  end
end
