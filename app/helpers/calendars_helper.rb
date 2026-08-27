# frozen_string_literal: true

module CalendarsHelper
  # --- Wochenstruktur des Monatsrasters ------------------------------------------------------
  #
  # Die Woche beginnt am SAMSTAG. Gemessen am 2026-08-27: die Liga-Spieltage haeufen sich am
  # Samstag (25/26: Sa 6729, So 4245), die Turniere am Sonntag (204 von 421). Ab Samstag stehen
  # beide Spitzen nebeneinander am linken Rand statt getrennt an beiden Enden.
  WEEK_START = :saturday

  # Die Wochentage in Anzeigereihenfolge als `wday`-Werte.
  #
  # ⚠️ Dieser Array IST zugleich der Index in `I18n.t("date.abbr_day_names")` — das ist
  # SONNTAGS-basiert (0 = "So" … 6 = "Sa"). Die frühere Kopfzeile rechnete das mit `(i + 1) % 7`
  # auf Montag um; ab Samstag ist der Versatz ein anderer, deshalb hier ausgeschrieben statt
  # gerechnet. Geprüft: liefert ["Sa", "So", "Mo", "Di", "Mi", "Do", "Fr"].
  WDAY_ORDER = [6, 0, 1, 2, 3, 4, 5].freeze

  # Kurznamen der Wochentage in Anzeigereihenfolge.
  def calendar_weekday_labels
    namen = I18n.t("date.abbr_day_names")
    WDAY_ORDER.map { |wday| namen[wday] }
  end

  # Spurbreiten: belegt = Platz fuer einen Termin-Chip, leer = gerade die Tageszahl.
  SPUR_BELEGT = "minmax(6rem, 1fr)"
  SPUR_LEER = "2.5rem"
  SPUR_BELEGT_REM = 6
  SPUR_LEER_REM = 2.5

  # `grid-template-columns` + Mindestbreite fuer das Monatsraster, abgeleitet aus den
  # Wochentagen, an denen der ANGEZEIGTE Monat Termine hat.
  #
  # ⚠️ Warum ein inline `style` und keine Tailwind-Klasse: Tailwind scannt den Quelltext und
  # erkennt nur LITERALE Klassennamen. Ein zusammengesetztes `grid-cols-[#{...}]` landet nicht im
  # kompilierten CSS — genau der Fehler, an dem in 42-01 `bg-info-100` und `bg-danger-100`
  # fehlten. Der UI-Guard erlaubt das ausdruecklich: er flaggt Hex, `<style>`-Bloecke und
  # `style="…color…"`; reine Layout-Styles bleiben bewusst ungeflaggt (lib/ui_hex_guard.rb).
  #
  # ⚠️ Warum datengetrieben und nicht schlicht "Mo–Fr schmal": gemessen am 2026-08-27 laufen
  # NBV, BLMR und BVB zu 100 % am Wochenende — die DBU aber nur zu 37 % (Fr 10, Mo 12, Mi 13)
  # und BVNR zu 61 % (Mo 22, Di 24, Mi 22). Die DBU-Ueberlagerung ist per Default AN. Eine feste
  # Regel wuerde genau diese Termine unlesbar quetschen.
  def calendar_grid_style(belegte_wdays)
    belegt = Array(belegte_wdays).map(&:to_i).uniq
    # Defensiv: ohne einen einzigen belegten Tag bleibt alles breit — lieber unveraendert als
    # zu sieben Zahlenspalten zusammengefallen. (Die Seite zeigt dann ohnehin den Leer-Hinweis.)
    voll = belegt.empty?

    spuren = WDAY_ORDER.map { |wday| (voll || belegt.include?(wday)) ? SPUR_BELEGT : SPUR_LEER }
    breite = WDAY_ORDER.sum { |wday| (voll || belegt.include?(wday)) ? SPUR_BELEGT_REM : SPUR_LEER_REM }

    "grid-template-columns: #{spuren.join(" ")}; min-width: #{breite}rem;"
  end

  # Sparte -> fertige Utility-Klassen.
  #
  # ⚠️ Die Klassennamen stehen AUSGESCHRIEBEN da und werden nicht zusammengesetzt. Tailwind
  # scannt den Quelltext (`content` in tailwind.config.js umfasst `app/helpers/**/*.rb`) und
  # erkennt nur literale Klassennamen — ein `"bg-#{ramp}-100"` landet NICHT im kompilierten CSS.
  # Gemessen am 2026-08-27: `bg-info-100` und `bg-danger-100` fehlten dort komplett, Pool und
  # Snooker waeren farblos geblieben, waehrend `primary` und `warning` zufaellig funktionierten,
  # weil sie anderswo ausgeschrieben vorkommen.
  #
  # Abgebildet auf die vorhandenen Ramps (docs/ui-conventions.md), keine neuen Farben.
  BRANCH_STYLES = {
    "Karambol" => {
      chip: "bg-primary-100 text-primary-900 dark:bg-primary-900 dark:text-primary-100",
      border: "border-primary-500",
      rail: "bg-primary-600 dark:bg-primary-400"
    },
    "Pool" => {
      chip: "bg-info-100 text-info-900 dark:bg-info-900 dark:text-info-100",
      border: "border-info-500",
      rail: "bg-info-600 dark:bg-info-400"
    },
    "Snooker" => {
      chip: "bg-danger-100 text-danger-900 dark:bg-danger-900 dark:text-danger-100",
      border: "border-danger-500",
      rail: "bg-danger-600 dark:bg-danger-400"
    },
    "Kegel" => {
      chip: "bg-warning-100 text-warning-900 dark:bg-warning-900 dark:text-warning-100",
      border: "border-warning-500",
      rail: "bg-warning-600 dark:bg-warning-400"
    }
  }.freeze

  NEUTRAL = {
    chip: "bg-gray-100 text-gray-900 dark:bg-gray-700 dark:text-gray-100",
    border: "border-gray-400",
    rail: "bg-gray-400 dark:bg-gray-500"
  }.freeze

  def calendar_branch_classes(name)
    BRANCH_STYLES.fetch(name.to_s, NEUTRAL)[:chip]
  end

  # Der schmale Farbstreifen braucht eine KRAEFTIGE Stufe — mit `-100` (der Chip-Flaeche) ist
  # ein 4px-Rail praktisch unsichtbar und traegt seinen Zweck nicht.
  def calendar_branch_rail(name)
    BRANCH_STYLES.fetch(name.to_s, NEUTRAL)[:rail]
  end

  def calendar_branch_border(name)
    BRANCH_STYLES.fetch(name.to_s, NEUTRAL)[:border]
  end

  # Filter-URL, die den bestehenden Zustand beibehaelt und nur einen Wert austauscht.
  #
  # Region, Saison und Sparte stehen NICHT darin — die kommen aus dem globalen Scope-Band
  # (Session), nicht aus dem URL. Hier stehen nur die kalender-eigenen Achsen.
  def calendar_url(overrides = {})
    base = {month: @month.strftime("%Y-%m"),
            dbu: (@include_dbu ? nil : "0"),
            view: ((@view_mode == "agenda") ? nil : @view_mode),
            kind: @kind, group: @group, discipline: @discipline_name}
    calendar_path(base.merge(overrides).compact)
  end

  # Anzeigetext einer Gruppen-Option. `Calendar::Query::GROUP_NONE` ist keine Kategorie, sondern
  # der sichtbare Fall "Turnier ohne Zuordnung" — CC-lose Turniere duerfen nicht still wegfallen.
  def calendar_group_label(value)
    (value == Calendar::Query::GROUP_NONE) ? t("calendars.filter.group_none") : value
  end
end
