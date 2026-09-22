# frozen_string_literal: true

require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:regular)
    @vorherige_locale = I18n.locale
    I18n.locale = :en
  end

  # 2026-09-23: `I18n.locale` ist THREAD-LOKAL und ueberlebt den Test. Ohne diesen teardown
  # lief jeder danach im selben Prozess ausgefuehrte Test auf Englisch weiter — je nach Seed.
  # Gemessen: TiebreakModalFormWiringTest (3 Tests) erwartet deutsche Modaltexte
  # ("Verlaengerung auf 25", "Anfangsball") und scheiterte an englischer Ausgabe; isoliert
  # 7/7 gruen. Eine nicht-deterministische Suite entwertet die Verifikation, auf die sich in
  # diesem Projekt jeder Plan stuetzt ("dieselbe Failure-Menge wie die Baseline").
  teardown do
    I18n.locale = @vorherige_locale
  end

  test "should render root page when user has preferences" do
    @user.update!(preferences: {
      "theme" => "dark",
      "locale" => "de",
      "timezone" => "Vienna"
    })

    sign_in @user
    get root_path

    assert_response :success
    assert_select "h1"
  end

  test "should render root page when user has no preferences" do
    @user.update!(preferences: {})
    sign_in @user
    get root_path

    assert_response :success
    assert_select "h1"
  end
end
