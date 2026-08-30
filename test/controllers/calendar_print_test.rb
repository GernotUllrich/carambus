# frozen_string_literal: true

require "test_helper"

# Die Druckansicht des Kalenders (`?print=1`): die ganze Scope-Saison, eigenes Layout ohne
# Navigation und Scope-Band.
#
# ⚠️ Der eigentliche Defekt vom 2026-08-30 lag NICHT hier, sondern im CSS: eine globale Regel
# `@media print { body > *:not(#game-protocol-modal) { display: none } }` aus
# `components/game_protocol_modal.css` blendete beim Drucken den gesamten Seiteninhalt aus —
# auf JEDER Seite ausser dem Spielprotokoll. Der Ausdruck kam leer aus dem Drucker, obwohl die
# Seite im Browser vollstaendig aussah. Der letzte Test hier haelt die Bindung an das Modal fest.
class CalendarPrintTest < ActionDispatch::IntegrationTest
  BASE_ID = 59_950_000

  setup do
    @region = regions(:nbv)
    @season = seasons(:current)
    @tag = Date.current.beginning_of_month + 9
    @monat = @tag.strftime("%Y-%m")
  end

  def turnier!(offset, titel, discipline: disciplines(:pool_8ball))
    Tournament.create!(id: BASE_ID + offset, title: titel, season: @season,
      organizer: @region, organizer_type: "Region", region_id: @region.id,
      discipline: discipline, date: @tag.to_time + 11.hours)
  end

  def drucken(**params)
    get calendar_url(month: @monat, print: "1", **params)
  end

  test "die Druckansicht zeigt die Termine der Saison" do
    turnier!(1, "NDM Druckprobe")

    get calendar_url(scope: {region: @region.id, season: @season.id}, month: @monat)
    drucken
    assert_response :success
    assert_match(/NDM Druckprobe/, response.body)
  end

  test "sie kommt ohne Navigation und Scope-Band" do
    turnier!(2, "NDM Druckprobe zwei")

    get calendar_url(scope: {region: @region.id, season: @season.id}, month: @monat)
    drucken
    assert_response :success
    assert_select "nav", {count: 0}, "eigenes Layout, keine Navigation"
  end

  # Die Kopfzeile ersetzt auf Papier die Filterleiste — ohne sie weiss niemand, was fehlt.
  test "die Kopfzeile nennt den Ausschnitt samt Sparten" do
    turnier!(3, "NDM Cadre Druck", discipline: disciplines(:karambol_cadre_35_2))

    get calendar_url(scope: {region: @region.id, season: @season.id}, month: @monat)
    drucken(branch: "Karambol")
    assert_response :success
    assert_match(/Karambol/, response.body)
  end

  test "eine Sparte ohne Termine ergibt den Leer-Hinweis, keine kaputte Seite" do
    turnier!(4, "NDM 8-Ball Druck")
    # Im Fixture-Bestand gibt es nur `branch_pool` und `branch_karambol` — ohne diesen Record
    # faende der Controller die Sparte nicht und filterte gar nicht.
    Branch.find_or_create_by!(name: "Snooker") { |b| b.type = "Branch" }

    get calendar_url(scope: {region: @region.id, season: @season.id}, month: @monat)
    drucken(branch: "Snooker")
    assert_response :success
    assert_match(/#{Regexp.escape(I18n.t("calendars.print.empty"))}/, response.body)
  end

  # ⚠️ Regressionsschutz fuer den eigentlichen Bug. Es gibt ZWEI Dateien mit derselben Falle —
  # beim ersten Anlauf hatte ich nur eine gefunden, der Ausdruck blieb leer. Beide Regeln
  # muessen an ihren Container gebunden bleiben; unbedingt gelten sie anwendungsweit und jede
  # andere Druckseite kommt leer aus dem Drucker. Im Browser ist das unsichtbar, deshalb hier.
  {
    "game_protocol_modal.css" => "#game-protocol-modal",
    "game_protocol_print.css" => ".protocol-print-container"
  }.each do |datei, container|
    test "die Druck-Ausblendung in #{datei} ist an ihren Container gebunden" do
      css = Rails.root.join("app/assets/stylesheets/components", datei).read
      escaped = Regexp.escape(container)

      refute_match(/^\s*body\s*>\s*\*:not\(#{escaped}\)/, css,
        "eine unbedingte Regel blendet auf JEDER Druckseite alles aus")
      assert_match(/body:has\(#{escaped}\)\s*>\s*\*:not\(#{escaped}\)/, css)
    end
  end

  # `game_protocol_print.css` setzt global `@page { size: A4 landscape }` — eine At-Rule laesst
  # sich nicht an einen Selektor binden. Der Kalender setzt deshalb seine eigene Geometrie.
  test "die Druckansicht setzt ihr eigenes Seitenformat" do
    turnier!(5, "NDM Format")

    get calendar_url(scope: {region: @region.id, season: @season.id}, month: @monat)
    drucken
    assert_response :success
    assert_match(/@page\s*\{[^}]*portrait/, response.body,
      "sonst kaeme der Kalender im Querformat des Spielprotokolls")
  end
end
