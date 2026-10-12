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

  # --- Plan 19-02: weitere Traversal-Varianten. Ziel ist jeweils eine Probe-Datei AUSSERHALB von
  # docs/ (tmp/zz_traversal_probe.md) mit einem Marker. Geprueft wird nicht nur der Status, sondern
  # dass der Marker nie in der Antwort steht — ein 200 aus einem Rueckfall innerhalb von docs/ waere
  # sonst von einer gelungenen Traversal nicht zu unterscheiden.

  PROBE_MARKER = "zz-traversal-probe-19-02"

  def with_probe_outside_docs
    probe = Rails.root.join("tmp", "zz_traversal_probe.md")
    FileUtils.mkdir_p(probe.dirname)
    File.write(probe, "# Probe\n\n#{PROBE_MARKER}\n")
    yield
  ensure
    FileUtils.rm_f(probe)
  end

  def assert_probe_not_served
    assert_response :not_found
    assert_not_includes response.body, PROBE_MARKER
  end

  test "Traversal mit kodierten Punkten wird abgewiesen" do
    with_probe_outside_docs do
      get "/docs_page/de/%2e%2e/tmp/zz_traversal_probe"
      assert_probe_not_served
    end
  end

  test "absoluter Pfad wird abgewiesen" do
    with_probe_outside_docs do
      get "/docs_page/de/#{CGI.escape(Rails.root.join("tmp", "zz_traversal_probe").to_s)}"
      assert_probe_not_served
    end
  end

  test "Locale aus dem Query-String fuehrt nicht aus docs/ heraus" do
    with_probe_outside_docs do
      get "/docs_page/zz_traversal_probe", params: {locale: "../tmp"}
      assert_probe_not_served
    end
  end

  test "absolute Locale aus dem Query-String fuehrt nicht aus docs/ heraus" do
    with_probe_outside_docs do
      get "/docs_page/zz_traversal_probe", params: {locale: Rails.root.join("tmp").to_s}
      assert_probe_not_served
    end
  end
end
