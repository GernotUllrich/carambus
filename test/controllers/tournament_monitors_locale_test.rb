# frozen_string_literal: true

require "test_helper"

# Plan 40-02: die Anzeigesprache wird auf der Turnierleiter-Seite bedienbar.
#
# Der eigentliche Prueffall ist AC-2: "nicht gesetzt" muss ein WAEHLBARER Zustand bleiben.
# `nil` reicht an die Tischsprache weiter, `"de"` ueberschreibt sie ausdruecklich — ein
# Formular, das nur zwischen zwei Sprachen umschaltet, zerstoert diese Unterscheidung.
class TournamentMonitorsLocaleTest < ActionDispatch::IntegrationTest
  BASE_ID = 54_200_000

  setup do
    # `ensure_local_server` laesst die Turnierleiter-Seite nur auf lokalen Servern zu;
    # dieses Repo IST die Authority, deshalb die Rolle fuer den Test umstellen (Muster aus
    # party_monitors_controller_test.rb).
    @original_api_url = Carambus.config.carambus_api_url
    Carambus.config.carambus_api_url = "http://local.test"

    @admin = users(:club_admin)
    @tournament = tournaments(:local)
    @tournament_monitor = TournamentMonitor.create!(id: BASE_ID + 1, tournament: @tournament)
    sign_in @admin
  end

  teardown do
    Carambus.config.carambus_api_url = @original_api_url
  end

  test "der Turnierleiter setzt die Anzeigesprache auf Englisch" do
    patch tournament_monitor_url(@tournament_monitor),
      params: {tournament_monitor: {locale: "en"}}

    assert_redirected_to tournament_monitor_url(@tournament_monitor)
    assert_equal "en", @tournament_monitor.reload.locale
  end

  # AC-2 — der Test, der die Kaskade aus 40-01 schuetzt.
  test "zuruecksetzen auf nicht gesetzt ergibt nil, nicht Deutsch" do
    @tournament_monitor.update!(locale: "en")

    patch tournament_monitor_url(@tournament_monitor),
      params: {tournament_monitor: {locale: ""}}

    assert_redirected_to tournament_monitor_url(@tournament_monitor)
    assert_nil @tournament_monitor.reload.locale,
      "Leerer Select-Wert muss nil ergeben — sonst hiesse 'nicht gesetzt' stillschweigend 'Deutsch' " \
      "und die Tischsprache kaeme nie zum Zug"
  end

  test "ein ungueltiger Wert wird abgelehnt statt still verworfen" do
    @tournament_monitor.update!(locale: "en")

    patch tournament_monitor_url(@tournament_monitor),
      params: {tournament_monitor: {locale: "xx"}}

    assert_response :success # render :edit, kein Redirect
    assert_equal "en", @tournament_monitor.reload.locale
  end

  test "die Turnierleiter-Seite zeigt die Sprachauswahl mit dem gewaehlten Wert" do
    @tournament_monitor.update!(locale: "en")

    get tournament_monitor_url(@tournament_monitor)

    assert_response :success
    assert_select "select[name='tournament_monitor[locale]']" do
      assert_select "option[value='']", count: 1
      assert_select "option[value='en'][selected]", count: 1
    end
  end
end
