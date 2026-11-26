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

  # --- POST-Budget je Lauf (die CC sperrt die IP nach einigen hundert Anfragen) ---
  class FakeCcClient
    attr_reader :member_calls

    def initialize(members, budget = nil)
      @members = members
      @member_calls = 0
      @budget = budget
    end

    def url_for(page, **params) = "https://cc.example/#{page}?#{params.to_query}"
    def club_doc(_cc_id) = Nokogiri::HTML("<aside><table class='silver'><tr><td>Verein</td><td>Budget-Club</td></tr></table></aside>")

    def members_doc(_cc_id)
      rows = @members.map { |pass, name| "<tr><td><a href='#' onClick='return memberPage(#{pass})' title='#{name}' class='cc_bluelink'>#{name}</a></td></tr>" }
      Nokogiri::HTML("<article><section><table class='silver'>#{rows.join}</table></section></article>")
    end

    def member_doc(_cc_id, pass)
      @member_calls += 1
      @budget[:left] -= 1 if @budget # wie ClubCloudPublicClient#post
      Nokogiri::HTML("<aside><table class='silver'></table><table class='silver'><tr><td>DBU-Nr.</td><td>#{pass}</td></tr></table></aside>")
    end
  end

  def budget_club = Club.create!(id: 50_000_000 + 97_001, name: "Budget-Club", shortname: "BC", region: regions(:nbv))

  test "POST-Budget: Verein mit mehr Mitgliedern als Rest wird ganz übersprungen, Fingerprint bleibt stale" do
    club = budget_club
    budget = {left: 2, deferred: 0}
    client = FakeCcClient.new([[1, "A, X"], [2, "B, Y"], [3, "C, Z"]], budget)

    club.scrape_club(Season.current_season, 1, "https://cc.example/", client: client, player_details: true, post_budget: budget)

    assert_equal 0, client.member_calls
    assert_equal({left: 2, deferred: 1}, budget)
    assert_nil ScrapeFingerprint.find_by(fingerprintable: club), "kein commit → nächster Lauf liest den Verein"
  end

  test "POST-Budget: reicht es, werden alle Mitglieder gelesen und das Budget sinkt" do
    club = budget_club
    budget = {left: 5, deferred: 0}
    client = FakeCcClient.new([[1, "A, X"], [2, "B, Y"]], budget)

    club.scrape_club(Season.current_season, 1, "https://cc.example/", client: client, player_details: true, post_budget: budget)

    assert_equal 2, client.member_calls
    assert_equal({left: 3, deferred: 0}, budget)
  end
end
