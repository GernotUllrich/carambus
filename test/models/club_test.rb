# frozen_string_literal: true

require "test_helper"

class ClubTest < ActiveSupport::TestCase
  # --- Change-Gate-Content (Phase 23, Roster): Club.roster_content ---
  # Format der Mitgliederliste seit cbmemdet.php (2026-11): Links `memberPage(<Pass-Nr.>)` in article table.silver.

  def players_doc(links_html)
    Nokogiri::HTML(<<~HTML)
      <article><section><table class="silver">
        #{links_html}
      </table></section></article>
    HTML
  end

  def member(pass, name) = "<tr><td><a href='#' onClick='return memberPage(#{pass})' title='#{name}' class='cc_bluelink'>#{name}</a><br>Pass-Nr.: #{pass}</td></tr>"

  test "roster_content extrahiert Spielerzeilen (Name|Pass-Nr.), sortiert" do
    content = Club.roster_content(players_doc(member(77, "Zabel, Anton") + member(42, "Alt, Berta")))
    assert_equal "Alt, Berta|42\nZabel, Anton|77", content
  end

  test "roster_content: neuer Spieler ändert den content (digest kippt → deep)" do
    base = Club.roster_content(players_doc(member(11, "A, X")))
    added = Club.roster_content(players_doc(member(11, "A, X") + member(12, "B, Y")))
    refute_equal base, added
  end

  test "roster_content: entfernter Spieler ändert den content (kein Fehl-Skip bei Roster-Schrumpfung)" do
    full = Club.roster_content(players_doc(member(11, "A, X") + member(12, "B, Y")))
    shrunk = Club.roster_content(players_doc(member(11, "A, X")))
    refute_equal full, shrunk
  end

  test "roster_content: fehlende Liste bzw. nil → leerer String (führt zu stale→deep)" do
    assert_equal "", Club.roster_content(nil)
    assert_equal "", Club.roster_content(Nokogiri::HTML("<aside><table class=\"silver\"><tr><th>x</th></tr></table></aside>"))
  end

  # cc_source_region: aus welcher CC werden Vereinsdaten gezogen? Regionen ohne eigene CC → DBU-CC.
  # Der Grund für den Fix: TBV (migriert, public_cc_url_base leer) wurde bisher nie gescrapt.
  test "cc_source_region: Region mit eigener CC-URL scrapt aus ihrer eigenen CC" do
    region = regions(:nbv)
    region.update_column(:public_cc_url_base, "https://ndbv.de/")
    assert_equal region, Club.new(region: region).cc_source_region
  end

  test "cc_source_region: CC-lose Region ohne CC-URL (z.B. TBV) fällt auf die DBU-CC zurück" do
    region = regions(:nbv) # als CC-lose Region simuliert: URL entfernt
    region.update_column(:public_cc_url_base, nil)
    assert_equal regions(:dbu), Club.new(region: region).cc_source_region
  end

  test "cc_source_region: BBV fällt weiterhin auf die DBU-CC zurück (Verhaltenserhalt)" do
    region = regions(:bbv)
    region.update_column(:public_cc_url_base, "https://billardbayern.de/")
    assert_equal regions(:dbu), Club.new(region: region).cc_source_region,
      "BBV muss trotz eigener URL auf die DBU-CC fallen (hartkodiert erhalten)"
  end
end
