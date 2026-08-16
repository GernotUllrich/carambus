# frozen_string_literal: true

require "test_helper"

# Pfadaufloesung von StaticController#docs_page.
#
# Hintergrund: 215 der 437 Doku-Dateien heissen schlicht <name>.md ohne
# Locale-Suffix. Die Aufloesung kannte nur <name>.<locale>.md, <locale>/<name>.md
# und <name>/<locale>.md — diese Dateien waren damit gar nicht abrufbar, obwohl
# sie existieren und aus der Doku heraus verlinkt werden.
#
# Die Fixtures legen echte Dateien unter docs/ an, damit der Test nicht am
# jeweiligen Doku-Bestand haengt.
class StaticDocsPageTest < ActionDispatch::IntegrationTest
  BASE = Rails.root.join("docs", "zz_test_docs_page")

  setup do
    FileUtils.mkdir_p(BASE)
    File.write(BASE.join("neutral.md"), "# Neutral\n\nSprachneutraler Inhalt.\n")
    File.write(BASE.join("beides.de.md"), "# Deutsch\n\nDeutscher Inhalt.\n")
    File.write(BASE.join("beides.en.md"), "# English\n\nEnglish content.\n")
    File.write(BASE.join("nur_englisch.en.md"), "# English only\n\nEnglish content.\n")
  end

  teardown do
    FileUtils.rm_rf(BASE)
  end

  # --- der behobene Fall ---

  test "sprachneutrale Datei ohne Locale-Suffix ist abrufbar" do
    get "/docs_page/de/zz_test_docs_page/neutral"

    assert_response :success
    assert_match "Sprachneutraler Inhalt", response.body
  end

  test "sprachneutrale Datei ist auch unter en abrufbar" do
    get "/docs_page/en/zz_test_docs_page/neutral"

    assert_response :success
    assert_match "Sprachneutraler Inhalt", response.body
  end

  # --- Vorrang: die exakte Sprache gewinnt weiterhin ---

  test "exakte Locale hat Vorrang vor sprachneutral und Fremdsprache" do
    get "/docs_page/de/zz_test_docs_page/beides"

    assert_response :success
    assert_match "Deutscher Inhalt", response.body
    assert_no_match(/English content/, response.body)
  end

  test "Rueckfall auf die Fremdsprache bleibt erhalten" do
    get "/docs_page/de/zz_test_docs_page/nur_englisch"

    assert_response :success
    assert_match "English content", response.body
  end

  # --- Abgrenzungen ---

  test "nicht vorhandene Seite bleibt 404" do
    get "/docs_page/de/zz_test_docs_page/gibt_es_nicht"

    assert_response :not_found
  end

  test "Directory Traversal wird abgewiesen" do
    get "/docs_page/de/zz_test_docs_page/../../config/database"

    assert_response :not_found
  end
end
