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
# `month`, `dbu`, `kind`, `group`, `discipline`, `location`.
#
# Dazu `branch` als einzige Ausnahme von "kommt von oben": ein Link darf Sparten mitbringen
# (kommagetrennt, mehrere erlaubt), ohne sie im Band zu setzen (siehe `ausschnitt_lesen`).

#
# Es gibt genau EINE Ansicht: den Strom (Betreiber-Entscheidung 2026-08-27, "Strom ist die
# einzig sinnvolle Anzeige"). Agenda und Monatsraster als eigene Ansichten sind entfallen;
# die Agenda lebt als Inhalt der Monatskacheln weiter.
class CalendarsController < ApplicationController
  include CalendarsHelper

  KINDS = %w[single team].freeze

  # Wahl "ohne Zuordnung" im Gruppen-Selektor. Eigener Wert, weil "" bereits "alle" heisst.
  GROUP_NONE = "none"

  # Kacheln je Ladung im Strom — vor und nach dem Einstiegsmonat bzw. je Nachschub.
  STREAM_BATCH = 6
  STREAM_MAX_BATCH = 12

  def show
    ausschnitt_lesen
    achsen_lesen

    @default_month = default_month
    @month = parse_month(params[:month]) || @default_month
    @from = @month.beginning_of_month
    @to = @month.end_of_month

    # Die Selektor-Optionen kommen aus dem AUSSCHNITT (Region · Saison · Sparte) — nicht aus dem
    # gerade sichtbaren Zeitfenster.
    #
    # ⚠️ Frueher (42-02) kamen sie aus dem angezeigten Monat. Das erzeugte einen Zustand, in dem
    # ein GESETZTER Filter unsichtbar wird: "NordCup" waehlen, in einen Monat ohne NordCup
    # blaettern — und die Option verschwindet aus der Leiste, obwohl sie weiter greift. Man sieht
    # dann nicht mehr, worauf man eingeschraenkt hat. Betreiber-Befund vom 2026-08-27.
    #
    # Nicht statisch aus `CategoryCc.all`/`Discipline.all`: gemessen ist `category_cc_id`
    # ausserhalb des NBV durchgaengig nil (BVNR 178/178, DBU 71/71, BVB 69/69, BLMR 31/31) —
    # dort gehoert gar kein Gruppen-Selektor hin.
    optionen = optionen_abfrage
    @group_options = optionen.group_options
    @discipline_options = optionen.discipline_options
    @location_options = optionen.location_options

    # Die aus dem MONAT abgeleitete Saison, nicht die des Bands: die Monatsnavigation ist frei
    # (Betreiber-Entscheidung), Band und Inhalt koennen also auseinanderlaufen. Der Kopf nennt
    # deshalb, zu welcher Saison der gezeigte Monat gehoert — der Widerspruch wird sichtbar
    # statt still.
    @season = Season.season_from_date(@from)

    # Erstladung des Stroms serverseitig: ohne JavaScript steht damit schon etwas da.
    # Auf dem Scoreboard genau EIN Monat statt des Stroms. Dort sind die Bildlaufleisten
    # unbedienbar, ein Strom waere also ab der ersten Bildschirmhoehe unerreichbar.
    # Geblaettert wird mit den ‹ › der Filterleiste, die es ohnehin schon gibt.
    #
    # Tragfaehig, weil ein Vereinskalender duenn ist: BC Wedel hat 3-9 Termine je Monat
    # (gemessen 2026-09-01), das passt auf eine Seite. Ein regionsweiter Spitzenmonat mit
    # dreistelliger Terminzahl wuerde auch hier ueberlaufen — dann braeuchte es zusaetzlich
    # eine Blaetterung INNERHALB des Monats.
    monate = helpers.scoreboard_context? ? [@month] : stream_erstladung(@month)
    @stream_kacheln = stream_kacheln(monate)

    # Druckansicht: die GANZE Scope-Saison, unabhaengig davon, wie weit jemand gescrollt hat
    # (Betreiber-Entscheidung 2026-08-28) — ein Ausdruck soll immer dasselbe bedeuten. Eigenes
    # Layout ohne Navigation, Sidebar und Scope-Band: gedruckt wird nur der Inhalt.
    return unless params[:print].present?

    @stream_kacheln = stream_kacheln(saison_monate)
    render :print, layout: "calendar_print"
  end

  # Nachschub fuer den Strom: eine Reihe Monatskacheln als HTML-Fragment (ohne Layout).
  #
  # `from` = Monat, VON dem aus geladen wird (exklusiv); `count` positiv = spaetere Monate,
  # negativ = fruehere. Ausserhalb der Stromgrenzen kommt eine leere Antwort — daran erkennt
  # der Stimulus-Controller, dass Schluss ist.
  def months
    ausschnitt_lesen
    achsen_lesen

    von = parse_month(params[:from])
    anzahl = params[:count].to_i.clamp(-STREAM_MAX_BATCH, STREAM_MAX_BATCH)
    monate = von ? calendar_months(von, anzahl) : []

    render partial: "month_tiles", locals: {kacheln: stream_kacheln(monate)}, layout: false
  end

  private

  # Ausschnitt aus dem Scope-Band (Session) — mit EINER Ausnahme: die Sparten darf der URL
  # mitbringen (`?branch=Karambol,Kegel`, kommagetrennt).
  #
  # ⚠️ Das weicht von 42-02 ab, aber nur LESEND: das Band wird weiterhin nie geschrieben. Anlass
  # ist der Kalender-Link am Scoreboard — an einem Karambol-Ort sind Pool- und Snooker-Termine
  # Rauschen, und ein Link kann die Session-Sparte nicht setzen, ohne sie jedem stillschweigend
  # umzustellen (genau das verbietet 42-02).
  #
  # ⚠️ MEHRERE, nicht eine: eine Tischart traegt mehrere Sparten. Auf dem kleinen Billard und
  # dem Match Billard wird sowohl Karambol als auch Kegel gespielt (Betreiber-Auskunft
  # 2026-08-29: die meisten Kegel-Disziplinen auf dem kleinen Tisch, 5-Pin auch auf dem
  # grossen). Ein Spielort schraenkt deshalb auf eine MENGE ein — das Scope-Band kann das
  # nicht, es fuehrt genau eine Sparte.
  #
  # Damit daraus kein unsichtbarer Filter wird, zeigt die Filterleiste einen eigenen Chip,
  # sobald die Sparten aus dem URL kommen — das Scope-Band zeigt ja weiter den Session-Wert.
  #
  # Unbekannte Namen fallen still weg; bleibt nichts uebrig, greift wieder das Band (wie
  # `parse_month`): ein kaputter Link soll eine Seite zeigen, keinen Fehler.
  def ausschnitt_lesen
    @region = Region.find(current_region_id)
    @url_branches = url_branches
    @branches =
      if @url_branches.any?
        @url_branches
      else
        Array.wrap(current_branch_id && Branch.find_by(id: current_branch_id))
      end
  end

  # Die Sparten aus dem URL, in der Reihenfolge des Parameters und ohne Dubletten.
  def url_branches
    namen = params[:branch].to_s.split(",").map(&:strip).reject(&:blank?).uniq
    return [] if namen.empty?

    namen.filter_map { |name| Branch.find_by(name: name) }
  end

  # Die kalender-eigenen Achsen. EINE Stelle fuer `show` UND `months` — zwei Kopien laufen
  # garantiert auseinander, und dann traegt eine nachgeladene Kachel andere Filter als die
  # erste Ladung.
  def achsen_lesen
    @include_dbu = params[:dbu] != "0"
    @group = params[:group].presence
    @discipline_name = params[:discipline].presence
    @location_name = params[:location].presence
    # Eine gewaehlte Gruppe IST eine Turnier-Achse (Spieltage tragen keine Kategorie). Sie setzt
    # `kind` deshalb auf "single" — aber SICHTBAR: @kind steuert auch den Einzel/Mannschaft-
    # Schalter, der Nutzer sieht die Umschaltung, statt dass die Spieltage still verschwinden.
    @kind = KINDS.include?(params[:kind]) ? params[:kind] : nil
    @kind = "single" if @group.present?
  end

  # Der Zeitraum der Scope-Saison (1. Juli bis 30. Juni, Konvention aus `Season.season_from_date`).
  # Grundlage der Selektor-Optionen. Ohne brauchbaren Saisonnamen faellt es auf den angezeigten
  # Monat zurueck — lieber eine knappe Liste als eine Ausnahme.
  def saison_zeitraum
    jahr = Season.find_by(id: current_season_id)&.name.to_s[/\A(\d{4})/, 1]&.to_i
    return [@from, @to] if jahr.nil? || jahr.zero?

    [Date.new(jahr, 7, 1), Date.new(jahr + 1, 6, 30)]
  end

  # Die Abfrage HINTER den Selektoren: ganze Scope-Saison, und OHNE die Achsen-Filter.
  #
  # ⚠️ Die Optionen haengen am Ausschnitt (Region · Saison · Sparte) — nicht aneinander. Liesse
  # man `group` mitwirken, schrumpfte die Disziplin-Liste, sobald eine Gruppe gewaehlt ist; dann
  # verschwaende dort eine gesetzte Disziplin genauso, wie vorher eine gesetzte Gruppe verschwand.
  def optionen_abfrage
    von, bis = saison_zeitraum
    Calendar::Query.new(region: @region, from: von, to: bis,
      branch: @branches, include_dbu: @include_dbu)
  end

  def kalender_abfrage(von, bis)
    Calendar::Query.new(
      region: @region, from: von, to: bis,
      branch: @branches, include_dbu: @include_dbu,
      kind: @kind, group: @group, discipline_name: @discipline_name,
      location_name: @location_name
    )
  end

  # Alle Monate der Scope-Saison, in denen etwas liegen KANN (Juli bis Juni) — Grundlage der
  # Druckansicht. Leere Monate fallen erst beim Rendern weg, nicht hier: sonst haenge die
  # Entscheidung "leer?" an einer zweiten Abfrage.
  def saison_monate
    von, bis = saison_zeitraum
    monat = von.beginning_of_month
    monate = []
    while monat <= bis
      monate << monat
      monat >>= 1
    end
    monate.select { |m| calendar_month_in_bounds?(m) }
  end

  # Je Monat EINE Abfrage. Bewusst nicht eine ueber den ganzen Bereich mit nachtraeglicher
  # Aufteilung: `Calendar::Entry#days` verteilt mehrtaegige Turniere auf ihre Tage, ein Turnier
  # ueber den Monatswechsel landete dann in BEIDEN Kacheln.
  def stream_kacheln(monate)
    monate.map { |m| [m, kalender_abfrage(m.beginning_of_month, m.end_of_month).call] }
  end

  # Erste Ladung des Stroms: der Einstiegsmonat und die folgenden.
  #
  # ⚠️ BEWUSST nichts davor. Ein erster Entwurf lud sechs Monate vor dem Einstiegsmonat mit —
  # im Browser stand dann Mai 2026 mit 196 Terminen ganz oben, und wer November wollte, scrollte
  # erst an sechs Riesenkacheln vorbei. Frueheres holt der Controller beim Hochscrollen nach.
  def stream_erstladung(monat)
    ([monat] + calendar_months(monat, STREAM_BATCH)).select { |m| calendar_month_in_bounds?(m) }
  end

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
