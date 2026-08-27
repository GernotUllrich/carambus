# frozen_string_literal: true

module CalendarsHelper
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
