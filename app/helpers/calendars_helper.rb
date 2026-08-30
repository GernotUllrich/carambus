# frozen_string_literal: true

module CalendarsHelper
  # --- Grenzen des Kalender-Stroms -----------------------------------------------------------
  #
  # ⚠️ Die DATENRAENDER taugen NICHT als Grenze. Gemessen am 2026-08-27: `tournaments.date` laeuft
  # von 0001-01-03 bis 2999-09-18, `parties.date` ab 2002, und der NBV traegt einen
  # Epoch-Null-Monat 1970-01. Ein Strom, der sich an min/max haelt, scrollt ins Jahr 1.
  #
  # Genommen wird deshalb dieselbe Regel, die das Scope-Band schon benutzt
  # (`Scopable#scope_season_options`): gueltige Saisons sind `2009..(aktuelles Startjahr + 2)`.
  # Begruendung steht im Season-Modell — id und ba_id sind durch das Scrapen internationaler
  # Turniere verrutscht, nur der Name "yyyy/yyyy+1" ist verlaesslich; "1911/1912" und
  # "Unknown Season" sind Ausreisser. Saison = 1. Juli bis 30. Juni
  # (`Season.season_from_date`: `(date - 6.month).year`).
  ERSTE_SAISON = 2009

  # [erster Monat, letzter Monat] des Stroms — heute 2009-07 .. 2029-06.
  def calendar_month_bounds
    startjahr = Season.current_season&.name.to_s[/\A(\d{4})/, 1]&.to_i
    startjahr = (Date.current - 6.months).year if startjahr.nil? || startjahr.zero?

    [Date.new(ERSTE_SAISON, 7, 1), Date.new(startjahr + 3, 6, 1)]
  end

  def calendar_month_in_bounds?(monat)
    von, bis = calendar_month_bounds
    monat.present? && monat >= von && monat <= bis
  end

  # `count` Monatsanfaenge ab `from` — positiv vorwaerts, negativ rueckwaerts (dann liegen sie
  # VOR `from` und kommen aufsteigend zurueck, damit sie sich am Stueck davorsetzen lassen).
  # Ausserhalb der Grenzen wird abgeschnitten, nicht gewuerfelt: der Strom endet dort.
  def calendar_months(from, count)
    return [] if from.blank? || count.to_i.zero?

    start = from.beginning_of_month
    schritte = count.to_i
    monate =
      if schritte.positive?
        (1..schritte).map { |i| start >> i }
      else
        (1..schritte.abs).map { |i| start << i }.reverse
      end

    monate.select { |m| calendar_month_in_bounds?(m) }
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
  # Seit dem Wegfall des Monatsrasters wird nur noch der Farbstreifen (:rail) gelesen.
  BRANCH_STYLES = {
    "Karambol" => {
      rail: "bg-primary-600 dark:bg-primary-400"
    },
    "Pool" => {
      rail: "bg-info-600 dark:bg-info-400"
    },
    "Snooker" => {
      rail: "bg-danger-600 dark:bg-danger-400"
    },
    "Kegel" => {
      rail: "bg-warning-600 dark:bg-warning-400"
    }
  }.freeze

  NEUTRAL = {
    rail: "bg-gray-400 dark:bg-gray-500"
  }.freeze

  # Der schmale Farbstreifen braucht eine KRAEFTIGE Stufe — mit `-100` (der Chip-Flaeche) ist
  # ein 4px-Rail praktisch unsichtbar und traegt seinen Zweck nicht.
  def calendar_branch_rail(name)
    BRANCH_STYLES.fetch(name.to_s, NEUTRAL)[:rail]
  end

  # Filter-URL, die den bestehenden Zustand beibehaelt und nur einen Wert austauscht.
  #
  # Region und Saison stehen NICHT darin — die kommen aus dem globalen Scope-Band (Session).
  # Die Sparten stehen nur dann darin, wenn sie SCHON aus dem URL kamen (`@url_branches`,
  # gesetzt in `CalendarsController#ausschnitt_lesen`).
  #
  # ⚠️ Bewusst nicht `@branches`: sonst schriebe der erste Klick auf irgendeinen Filter die
  # Band-Sparte in den URL und liesse sie dort kleben — eine spaetere Umstellung im Band bliebe
  # dann wirkungslos, ohne dass man saehe warum.
  def calendar_url(overrides = {})
    base = {month: @month.strftime("%Y-%m"),
            dbu: (@include_dbu ? nil : "0"),
            branch: calendar_branch_param(@url_branches),
            kind: @kind, group: @group, discipline: @discipline_name,
            location: @location_name}
    calendar_path(base.merge(overrides).compact)
  end

  # Sparten-Namen -> Wert des `branch`-Parameters ("Karambol,Kegel"); leer -> nil, damit
  # `compact` ihn aus dem URL wirft. Nimmt Branch-Records oder blanke Namen.
  def calendar_branch_param(branches)
    namen = Array.wrap(branches).filter_map { |b| b.respond_to?(:name) ? b.name.presence : b.presence }
    namen.any? ? namen.join(",") : nil
  end

  # Die Achsen-Parameter fuer den Nachschub-Endpoint des Stroms — OHNE `month` und `view`
  # (die bestimmt der Strom selbst) und ohne den Ausschnitt (der steht in der Session; ihn in den
  # URL zu schreiben waere genau die Doppelstruktur, die 42-02 beseitigt hat).
  #
  # Die URL-Sparten gehoeren hier hinein: sonst traegt die erste Kachel den Filter und jede
  # nachgeladene nicht — beim Scrollen tauchten die fremden Sparten wieder auf.
  def calendar_stream_params
    {dbu: (@include_dbu ? nil : "0"), branch: calendar_branch_param(@url_branches),
     kind: @kind, group: @group,
     discipline: @discipline_name, location: @location_name}.compact
  end

  # Die URL fuer den Sparten-Selektor: schaltet EINE Sparte in der aktuellen Menge an oder aus.
  #
  # Mehrfachauswahl, weil die Sparte hier eine MENGE ist (ein Karambol-Ort bringt „Karambol,
  # Kegel" mit). Die anderen Selektoren der Leiste sind Einfachauswahl und tauschen ihren Wert;
  # dieser rechnet die neue Menge aus.
  def calendar_branch_toggle_url(name)
    aktuell = Array.wrap(@url_branches).map(&:name)
    neu = aktuell.include?(name) ? (aktuell - [name]) : (aktuell + [name])
    calendar_url(branch: calendar_branch_param(neu))
  end

  # Anzeigetext der aktuellen Auswahl fuer den eingeklappten Selektor — leer, wenn keine
  # Sparte gesetzt ist (dann zeigt das Partial „Alle Sparten").
  def calendar_branch_summary
    Array.wrap(@url_branches).map(&:name).join(" + ")
  end

  # Zurueck zur Anfangssicht: Einstiegsmonat und KEINE Achsen-Filter. Der Ausschnitt
  # (Region/Saison/Sparte) bleibt: der gehoert dem Scope-Band, nicht dieser Seite.
  def calendar_reset_path
    calendar_path
  end

  # True, wenn ueberhaupt etwas zurueckzusetzen ist (sonst waere der Knopf Zierde).
  # Die URL-Sparten zaehlen mit: sie sind eine Achse dieses Blatts und verschwinden beim Reset.
  def calendar_filters_active?
    @kind.present? || @group.present? || @discipline_name.present? || @location_name.present? ||
      @url_branches.present? || !@include_dbu || @month != @default_month
  end

  # Anzeigetext einer Orts-Option. `LOCATION_NONE` ist kein Ort, sondern der sichtbare Fall
  # "Termin ohne Austragungsort" — im BVNR betrifft das ein knappes Dutzend Turniere je Saison.
  def calendar_location_label(value)
    (value == Calendar::Query::LOCATION_NONE) ? t("calendars.filter.location_none") : value
  end

  # Kopfzeile der Druckansicht: welcher Ausschnitt und welche Filter im Ausdruck stecken.
  # Auf Papier gibt es keine Filterleiste — ohne diese Zeile weiss niemand mehr, was fehlt.
  def calendar_print_scope_line
    teile = [@region.shortname.presence || @region.name]
    teile << @branches.map(&:name).join(" + ") if @branches.present?
    teile << t("calendars.filter.kind_single") if @kind == "single"
    teile << t("calendars.filter.kind_team") if @kind == "team"
    teile << calendar_group_label(@group) if @group.present?
    teile << @discipline_name if @discipline_name.present?
    teile << calendar_location_label(@location_name) if @location_name.present?
    teile << t("calendars.filter.region_only", region: @region.shortname.presence || @region.name) unless @include_dbu
    teile.join(" · ")
  end

  # Anzeigetext einer Gruppen-Option. `Calendar::Query::GROUP_NONE` ist keine Kategorie, sondern
  # der sichtbare Fall "Turnier ohne Zuordnung" — CC-lose Turniere duerfen nicht still wegfallen.
  def calendar_group_label(value)
    (value == Calendar::Query::GROUP_NONE) ? t("calendars.filter.group_none") : value
  end
end
