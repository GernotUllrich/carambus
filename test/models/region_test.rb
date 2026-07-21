# frozen_string_literal: true

require "test_helper"

class RegionTest < ActiveSupport::TestCase
  # cc_admin_base_url_from: leitet RegionCc.base_url (CC-Admin-Tenant-Host) aus dem
  # "Anmeldung"-Link der öffentlichen Region-Seite ab. Behebt die base_url-Falle, bei der
  # scrape_region_public public_cc_url_base in base_url schrieb → täglich CC-Admin-Login 404.
  test "cc_admin_base_url_from: Anmeldung-Link → base_url scheme://host (ohne Trailing-Slash)" do
    doc = Nokogiri::HTML(
      '<ul><li><a href="https://abc123def.club-cloud.de" title="Anmeldung NBV" target="_blank">Anmeldung</a></li></ul>'
    )
    assert_equal "https://abc123def.club-cloud.de",
      Region.new(shortname: "NBV").cc_admin_base_url_from(doc, "https://ndbv.de/")
  end

  test "cc_admin_base_url_from: href mit Pfad → nur scheme://host (Root, kein Slash)" do
    doc = Nokogiri::HTML('<a href="https://abc.club-cloud.de/admin/login.php">Anmeldung</a>')
    assert_equal "https://abc.club-cloud.de",
      Region.new.cc_admin_base_url_from(doc, "https://ndbv.de/")
  end

  test "cc_admin_base_url_from: kein Anmeldung-Link → nil (base_url bleibt unangetastet)" do
    doc = Nokogiri::HTML('<a href="https://ndbv.de/impressum">Impressum</a>')
    assert_nil Region.new.cc_admin_base_url_from(doc, "https://ndbv.de/")
  end

  test "cc_admin_base_url_from: Anmeldung-Anchor ohne href → nil" do
    doc = Nokogiri::HTML("<a>Anmeldung</a>")
    assert_nil Region.new.cc_admin_base_url_from(doc, "https://ndbv.de/")
  end

  # --- Change-Gate-Content (Phase 23, Ebene B): Region.tournament_list_content ---

  def einzel_doc(rows_html)
    Nokogiri::HTML(<<~HTML)
      <article>
        <table class="silver"><tr><th>x</th></tr></table>
        <table class="silver">
          <tr><th>Kopf1</th></tr>
          <tr><th>Kopf2</th></tr>
          #{rows_html}
        </table>
      </article>
    HTML
  end

  test "tournament_list_content extrahiert Turnierzeilen inkl. Link, sortiert" do
    doc = einzel_doc(<<~ROWS)
      <tr><td>2</td><td>10.02.2026</td><td><a href="sb_meisterschaft.php?p=1-2-3-88">Turnier B</a></td></tr>
      <tr><td>1</td><td>03.01.2026</td><td><a href="sb_meisterschaft.php?p=1-2-3-42">Turnier A</a></td></tr>
    ROWS
    content = Region.tournament_list_content(doc)
    assert_includes content, "sb_meisterschaft.php?p=1-2-3-88"
    assert_includes content, "sb_meisterschaft.php?p=1-2-3-42"
    # deterministisch sortiert → "1|03.01…" (Turnier A) vor "2|10.02…" (Turnier B)
    assert content.index("Turnier A") < content.index("Turnier B")
  end

  test "tournament_list_content: neues Turnier ändert den content (digest kippt → deep)" do
    base = Region.tournament_list_content(einzel_doc(
      '<tr><td>1</td><td>03.01.2026</td><td><a href="p=1-2-3-42">A</a></td></tr>'
    ))
    added = Region.tournament_list_content(einzel_doc(<<~ROWS))
      <tr><td>1</td><td>03.01.2026</td><td><a href="p=1-2-3-42">A</a></td></tr>
      <tr><td>2</td><td>10.02.2026</td><td><a href="p=1-2-3-88">B</a></td></tr>
    ROWS
    refute_equal base, added
  end

  test "tournament_list_content: geändertes Turnierdatum ändert den content" do
    base = Region.tournament_list_content(einzel_doc(
      '<tr><td>1</td><td>03.01.2026</td><td><a href="p=1-2-3-42">A</a></td></tr>'
    ))
    moved = Region.tournament_list_content(einzel_doc(
      '<tr><td>1</td><td>17.01.2026</td><td><a href="p=1-2-3-42">A</a></td></tr>'
    ))
    refute_equal base, moved
  end

  test "tournament_list_content: fehlende Tabelle bzw. nil → leerer String (führt zu stale→deep)" do
    assert_equal "", Region.tournament_list_content(nil)
    no_table = Nokogiri::HTML("<article><table class=\"silver\"><tr><th>x</th></tr></table></article>")
    assert_equal "", Region.tournament_list_content(no_table)
  end

  # --- Change-Gate-Content (Phase 23, Ebene B): Region.location_row_content ---

  def location_tr(inner)
    Nokogiri::HTML("<table><tr>#{inner}</tr></table>").css("tr")[0]
  end

  test "location_row_content: Zeile mit Link → Zellen|href" do
    tr = location_tr('<td>1</td><td><a href="location.php?p=x|55|">BC Test</a></td><td>Hauptstr. 1</td>')
    assert_equal "1|BC Test|Hauptstr. 1|location.php?p=x|55|", Region.location_row_content(tr)
  end

  test "location_row_content: geänderte Adresse ändert den content" do
    base = Region.location_row_content(location_tr('<td>1</td><td><a href="p=1">L</a></td><td>Alt 1</td>'))
    moved = Region.location_row_content(location_tr('<td>1</td><td><a href="p=1">L</a></td><td>Neu 2</td>'))
    refute_equal base, moved
  end

  test "location_row_content: Zeile ohne Link (Kopf/Footer) → nil" do
    assert_nil Region.location_row_content(location_tr("<td>kein Link</td>"))
  end

  # --- Fail-silent-Wächter (Befund 2026-07-21 SBV-Clubs): ScrapeListGuard ---

  def captured_scrape_warnings
    old_logger = Rails.logger
    io = StringIO.new
    Rails.logger = Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = old_logger
  end

  test "warn_if_empty: leere Liste trotz DB-Bestand → warn mit Label und Erwartung" do
    log = captured_scrape_warnings do
      assert ScrapeListGuard.warn_if_empty("Clubs SBV", 0, 209)
    end
    assert_includes log, "LEERE LISTE Clubs SBV"
    assert_includes log, "209 in der DB"
  end

  test "warn_if_empty: leere Liste ohne DB-Bestand → still (Neuanlage ist kein Fehler)" do
    log = captured_scrape_warnings do
      refute ScrapeListGuard.warn_if_empty("Clubs XYZ", 0, 0)
    end
    refute_includes log, "LEERE LISTE"
  end

  test "warn_if_empty: nicht-leere Liste → still" do
    log = captured_scrape_warnings do
      refute ScrapeListGuard.warn_if_empty("Clubs SBV", 27, 209)
    end
    refute_includes log, "LEERE LISTE"
  end
end
