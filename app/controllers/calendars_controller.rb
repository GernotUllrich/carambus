# frozen_string_literal: true

# Terminkalender: Turniere und Liga-Spieltage gemeinsam.
#
# Bewusst OHNE Auth-Filter — die Seite zeigt nichts, was `tournaments#index` und `leagues#index`
# nicht schon oeffentlich zeigen (leagues_controller.rb nimmt `index`/`show` ausdruecklich aus).
#
# **Region, Saison und Sparte kommen von oben.** Die Anwendung fuehrt ein globales Scope-Band
# (Scopable, `Current.scope`); der Kalender LIEST es und schreibt es nie — ein Schreiben aus der
# Seite heraus wuerde den Ausschnitt still verschieben (siehe `Scopable#scope_band_form_path`).
#
# Die kalender-eigenen Achsen stehen im URL, damit ein Kalenderblatt teilbar bleibt:
# `month`, `dbu`, `view`, `kind`, `group`, `discipline`.
class CalendarsController < ApplicationController
  VIEW_MODES = %w[agenda grid].freeze
  KINDS = %w[single team].freeze

  # Wahl "ohne Zuordnung" im Gruppen-Selektor. Eigener Wert, weil "" bereits "alle" heisst.
  GROUP_NONE = "none"

  def show
    @region = Region.find(current_region_id)
    @branch = current_branch_id && Branch.find_by(id: current_branch_id)

    @month = parse_month(params[:month]) || default_month
    @from = @month.beginning_of_month
    @to = @month.end_of_month

    @include_dbu = params[:dbu] != "0"
    @view_mode = VIEW_MODES.include?(params[:view]) ? params[:view] : "agenda"
    @group = params[:group].presence
    @discipline_name = params[:discipline].presence
    # Eine gewaehlte Gruppe IST eine Turnier-Achse (Spieltage tragen keine Kategorie). Sie setzt
    # `kind` deshalb auf "single" — aber SICHTBAR: @kind steuert auch den Einzel/Mannschaft-
    # Schalter, der Nutzer sieht die Umschaltung, statt dass die Spieltage still verschwinden.
    @kind = KINDS.include?(params[:kind]) ? params[:kind] : nil
    @kind = "single" if @group.present?

    query = Calendar::Query.new(
      region: @region, from: @from, to: @to,
      branch: @branch, include_dbu: @include_dbu,
      kind: @kind, group: @group, discipline_name: @discipline_name
    )
    @entries = query.call
    # Die Selektor-Optionen kommen aus DEMSELBEN Ausschnitt und Zeitraum — nicht aus
    # `CategoryCc.all`/`Discipline.all`. Gemessen am 2026-08-27: ausserhalb des NBV ist
    # `category_cc_id` durchgaengig nil (BVNR 178/178, DBU 71/71, BVB 69/69, BLMR 31/31), ein
    # statischer Selektor waere dort ein leeres Bedienelement.
    @group_options = query.group_options
    @discipline_options = query.discipline_options

    # Die aus dem MONAT abgeleitete Saison, nicht die des Bands: die Monatsnavigation ist frei
    # (Betreiber-Entscheidung), Band und Inhalt koennen also auseinanderlaufen. Der Kopf nennt
    # deshalb, zu welcher Saison der gezeigte Monat gehoert — der Widerspruch wird sichtbar
    # statt still.
    @season = Season.season_from_date(@from)
  end

  private

  # "YYYY-MM"; leer -> nil (dann greift `default_month`). Unsinn faellt auf den laufenden Monat
  # zurueck, statt zu werfen — ein kaputter Link soll eine Seite zeigen, keinen Fehler.
  def parse_month(raw)
    return nil if raw.blank?

    Date.strptime(raw.to_s, "%Y-%m").beginning_of_month
  rescue ArgumentError, TypeError
    Date.current.beginning_of_month
  end

  # Einstiegsmonat ohne expliziten `month`-Parameter: der erste Monat der Scope-Saison.
  # Saison = 1. Juli bis 30. Juni (Konvention aus `Season.season_from_date`: `(date - 6.month).year`).
  # Liegt "heute" in dieser Saison, gewinnt der laufende Monat — sonst landete man im Juli,
  # obwohl "jetzt" gemeint war.
  def default_month
    start_year = Season.find_by(id: current_season_id)&.name.to_s[/\A(\d{4})/, 1]&.to_i
    return Date.current.beginning_of_month if start_year.nil? || start_year.zero?

    erster = Date.new(start_year, 7, 1)
    heute = Date.current.beginning_of_month
    (heute >= erster && heute < erster + 1.year) ? heute : erster
  end
end
