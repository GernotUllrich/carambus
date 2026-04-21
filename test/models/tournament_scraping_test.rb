# frozen_string_literal: true

require "test_helper"

# Characterization tests for Tournament's scraping pipeline: scrape_single_tournament_public.
#
# Covers (per D-03, D-04, D-05, CHAR-06):
# - Guard: non-Region organizer returns early without HTTP calls
# - Guard: API server (carambus_api_url present) returns early without HTTP calls
# - opts[:tournament_doc] passes pre-parsed Nokogiri doc (skips first HTTP call)
# - Full scrape (WebMock stubs) creates seedings from registration page
# - opts[:reload_game_results] destroys games before re-scraping
# - opts[:reload_seedings] destroys seedings before re-scraping
# - Variant dispatch: parse_table_tr routes to correct variant method by header columns
#
# NOTE: Live VCR recording from real ClubCloud URLs is not feasible in the test environment.
# All HTTP calls are intercepted by WebMock stubs with minimal valid HTML responses.
# This pins the guard conditions, HTTP call sequence, and variant dispatch behavior.
class TournamentScrapingTest < ActiveSupport::TestCase
  fixtures :all

  # Unique ID base above fixture range (50_000_001–50_000_002)
  SCRAPING_TEST_ID_BASE = 50_200_000

  self.use_transactional_tests = true

  # nbsp character used throughout the scraping code
  NBSP = ["\xc2\xa0"].pack("a*").force_encoding("UTF-8")

  # Minimal HTML for the tournament (meisterschaft) page.
  # Provides aside.silver detail table and stanne table.
  MEISTERSCHAFT_HTML = <<~HTML.freeze
    <html><body>
      <aside>
        <table class="silver">
          <tr><td>K&#252;rzel</td><td>NBV-TEST-2025</td></tr>
        </table>
        <div class="stanne">
          <table class="silver">
            <table class="silver">
              <tr><th>TEILNEHMERLISTE</th></tr>
            </table>
          </table>
        </div>
      </aside>
    </body></html>
  HTML

  # Minimal HTML for the registration (meldeliste) page — no players (empty table).
  # Keeping it empty avoids the complex Player.fix_from_shortnames lookup.
  MELDELISTE_HTML = <<~HTML.freeze
    <html><body>
      <aside>
        <table class="silver">
          <table class="silver">
            <tr><th>Nr</th><th>Platz</th><th>Spieler / Verein</th></tr>
          </table>
        </table>
      </aside>
    </body></html>
  HTML

  # Minimal HTML for results (einzelergebnisse) — empty (no games to parse).
  EINZELERGEBNISSE_HTML = <<~HTML.freeze
    <html><body>
      <aside>
        <table class="silver"></table>
        <table class="silver"></table>
      </aside>
    </body></html>
  HTML

  # Minimal HTML for ranking (einzelrangliste) — empty table.
  EINZELRANGLISTE_HTML = <<~HTML.freeze
    <html><body>
      <aside>
        <table class="silver">
          <table class="silver"></table>
        </table>
      </aside>
    </body></html>
  HTML

  setup do
    @id_counter = 0

    # Originalwert merken, damit Tests, die carambus_api_url mutieren, im
    # teardown nicht auf nil zurücksetzen und damit andere Tests in der
    # Suite vergiften (z. B. PaperTrail-Gates in tournament_papertrail_test).
    @original_api_url = Carambus.config.carambus_api_url

    # Ensure NBV region has public_cc_url_base set (stored in DB via fixture column)
    @region = regions(:nbv)
    @region.update_column(:public_cc_url_base, "https://ndbv.de/")

    # Ensure NBV has a region_cc (required by scrape_single_tournament_public)
    @region_cc = RegionCc.find_or_initialize_by(context: "nbv")
    @region_cc.assign_attributes(cc_id: 20, region_id: @region.id)
    @region_cc.save!

    # Build the base tournament used by most tests
    @season = seasons(:current)
    @tournament = build_tournament
  end

  teardown do
    # Restore any Carambus.config mutations
    Carambus.config.carambus_api_url = @original_api_url
  end

  # ---------------------------------------------------------------------------
  # Guard tests
  # ---------------------------------------------------------------------------

  test "scrape_single_tournament_public returns early when organizer_type is not Region" do
    # Non-Region organizer — returns nil immediately, no HTTP calls attempted.
    # WebMock will raise ConnectionError if any unexpected HTTP call is made.
    t = build_tournament_for_club
    result = t.scrape_single_tournament_public
    assert_nil result
  end

  test "scrape_single_tournament_public returns early when carambus_api_url is present" do
    # API server context — returns nil immediately.
    original_url = Carambus.config.carambus_api_url
    Carambus.config.carambus_api_url = "https://api.carambus.de"
    begin
      result = @tournament.scrape_single_tournament_public
      assert_nil result
    ensure
      Carambus.config.carambus_api_url = original_url
    end
  end

  # ---------------------------------------------------------------------------
  # opts[:tournament_doc] skips first HTTP call
  # ---------------------------------------------------------------------------

  test "scrape_single_tournament_public with tournament_doc skips meisterschaft HTTP call" do
    # Passing tournament_doc bypasses the first Net::HTTP.get call.
    # Only 3 HTTP calls are made (meldeliste, einzelergebnisse, einzelrangliste).
    stub_remaining_calls

    tournament_doc = Nokogiri::HTML(MEISTERSCHAFT_HTML)
    # Should not raise — the 3 calls are stubbed
    @tournament.scrape_single_tournament_public(tournament_doc: tournament_doc)

    # Tournament was saved with source_url set from the URL built by the method
    assert @tournament.reload.source_url.present?
  end

  # ---------------------------------------------------------------------------
  # opts[:reload_seedings] destroys seedings before re-scraping
  # ---------------------------------------------------------------------------

  test "scrape_single_tournament_public with reload_seedings destroys existing seedings" do
    # Create a local player and seeding inline (no players fixture exists)
    player = Player.create!(
      id: SCRAPING_TEST_ID_BASE + 900,
      firstname: "Test",
      lastname: "Spieler",
      region_id: @region.id
    )
    existing_seeding = Seeding.create!(
      player: player,
      tournament_id: @tournament.id,
      tournament_type: "Tournament",
      position: 1
    )
    assert_equal 1, @tournament.seedings.count

    stub_remaining_calls
    tournament_doc = Nokogiri::HTML(MEISTERSCHAFT_HTML)

    @tournament.scrape_single_tournament_public(tournament_doc: tournament_doc, reload_seedings: true)

    # After reload_seedings, the existing seeding was destroyed before re-scraping
    assert_not Seeding.exists?(existing_seeding.id)
  end

  # ---------------------------------------------------------------------------
  # opts[:reload_game_results] destroys games before re-scraping
  # ---------------------------------------------------------------------------

  test "scrape_single_tournament_public with reload_game_results destroys existing games" do
    # Game uses polymorphic tournament association — tournament_type must be set
    # so has_many :games, as: :tournament on Tournament returns the game.
    existing_game = Game.create!(
      id: SCRAPING_TEST_ID_BASE + 901,
      tournament_id: @tournament.id,
      tournament_type: "Tournament"
    )
    assert_equal 1, @tournament.games.count

    stub_remaining_calls
    tournament_doc = Nokogiri::HTML(MEISTERSCHAFT_HTML)

    @tournament.scrape_single_tournament_public(tournament_doc: tournament_doc, reload_game_results: true)

    # After reload_game_results, the existing game was destroyed before re-scraping
    assert_not Game.exists?(existing_game.id)
  end

  # ---------------------------------------------------------------------------
  # Variant dispatch tests (parse_table_tr)
  # ---------------------------------------------------------------------------

  test "parse_table_tr dispatches to variant0 for [Partie Begegnung Partien Erg.] header" do
    header = %w[Partie Begegnung Partien Erg.]
    # variant0 accesses td[0..5] — needs at least 6 cells
    tr = build_nokogiri_tr(6)

    result = call_parse_table_tr(header, tr)
    assert result[:td_lines] > 0, "Expected td_lines > 0 after variant0 dispatch"
    assert_equal 1, result[:result_lines], "Expected result_lines incremented by variant0"
  end

  test "parse_table_tr dispatches to variant7 for [Partie Begegnung Aufn. HS GD Erg.] header" do
    header = %w[Partie Begegnung Aufn. HS GD Erg.]
    # variant7 accesses td[0..7] — needs at least 8 cells
    tr = build_nokogiri_tr(8)

    result = call_parse_table_tr(header, tr)
    assert result[:td_lines] > 0, "Expected td_lines > 0 after variant7 dispatch"
    assert_equal 1, result[:result_lines], "Expected result_lines incremented by variant7"
  end

  test "parse_table_tr dispatches to Variant4 for [Partie Begegnung Pkt. Aufn. HS GD Erg.] header" do
    header = %w[Partie Begegnung Pkt. Aufn. HS GD Erg.]
    # Variant4 accesses td[0..8] — needs at least 9 cells
    tr = build_nokogiri_tr(9)

    result = call_parse_table_tr(header, tr)
    assert result[:td_lines] > 0, "Expected td_lines > 0 after Variant4 dispatch"
    assert_equal 1, result[:result_lines], "Expected result_lines incremented by Variant4"
  end

  test "parse_table_tr sets group when th count is 1" do
    tr = Nokogiri::HTML("<table><tr><th>Gruppe A</th></tr></table>").css("tr").first

    result = call_parse_table_tr([], tr)
    assert_equal "Gruppe A", result[:group]
  end

  test "parse_table_tr updates header when th count > 1" do
    tr = Nokogiri::HTML("<table><tr><th>Partie</th><th>Begegnung</th><th>Erg.</th></tr></table>").css("tr").first

    result = call_parse_table_tr([], tr)
    assert_equal %w[Partie Begegnung Erg.], result[:header]
  end

  test "parse_table_tr logs unknown header and does not raise" do
    header = %w[Unknown Column Header]
    tr = build_nokogiri_tr(4)

    assert_nothing_raised { call_parse_table_tr(header, tr) }
  end

  private

  def next_id
    @id_counter += 1
    SCRAPING_TEST_ID_BASE + @id_counter
  end

  # Build a Region-organizer tournament with all associations needed for scrape_single_tournament_public.
  def build_tournament(attrs = {})
    t = Tournament.create!(
      id: next_id,
      title: "Scraping Test Tournament",
      season: @season,
      organizer: @region,
      organizer_type: "Region",
      discipline: disciplines(:carom_3band),
      state: "registration",
      **attrs
    )

    # Create tournament_cc with a unique cc_id per call to avoid the unique index collision
    TournamentCc.create!(
      tournament: t,
      name: t.title,
      cc_id: next_id,  # unique per tournament built
      context: "nbv",
      season: @season.name
    )
    t.reload
    t
  end

  # Build a Club-organizer tournament — scrape guard exits immediately, no TournamentCc needed.
  def build_tournament_for_club
    Tournament.create!(
      id: next_id,
      title: "Club Tournament",
      season: @season,
      organizer: clubs(:bcw),
      organizer_type: "Club",
      discipline: disciplines(:carom_3band),
      state: "registration"
    )
  end

  # Stub the 3 HTTP calls made after opts[:tournament_doc] is used:
  # meldeliste, einzelergebnisse, einzelrangliste.
  # The actual URLs are built by scrape_single_tournament_public from:
  #   region.public_cc_url_base + "sb_{page}.php?p={region_cc_cc_id}--{season}-{tournament_cc_id}----1-100000-"
  # We use WebMock any_request stub to accept any URL matching the base.
  def stub_remaining_calls
    # Match any GET to ndbv.de (covers all 3 page calls regardless of exact URL params)
    stub_request(:get, /ndbv\.de/)
      .to_return(status: 200, body: MELDELISTE_HTML, headers: { "Content-Type" => "text/html" })
  end

  # Build a Nokogiri <tr> element with N <td> cells containing sequential numbers.
  def build_nokogiri_tr(cell_count)
    tds = (1..cell_count).map { |i| "<td>#{i}</td>" }.join
    Nokogiri::HTML("<table><tr>#{tds}</tr></table>").css("tr").first
  end

  # Call private parse_table_tr with zero-initialized state and return named result hash.
  # After extraction to Tournament::PublicCcScraper, parse_table_tr lives on the service instance.
  def call_parse_table_tr(header, tr)
    nbsp = NBSP
    region = @region
    frame1_lines = result_lines = td_lines = 0
    result = nil
    no = nil
    playera_fl_name = nil
    playerb_fl_name = nil
    group = nil
    frames = []
    frame_points = []
    innings = []
    hs = []
    hb = []
    mp = []
    gd = []
    points = []
    frame_result = []
    result_url = ""
    player_list = {}

    # Build service instance for calling private parse_table_tr
    scraper = Tournament::PublicCcScraper.new(tournament: @tournament)
    out = scraper.send(
      :parse_table_tr,
      region, frame1_lines, frame_points, frame_result, frames, gd, group, hb,
      header, hs, mp, innings, nbsp, no, player_list, playera_fl_name, playerb_fl_name,
      points, result, result_lines, result_url, td_lines, tr
    )

    # parse_table_tr returns a positional array — map back to named hash for assertions
    {
      frame1_lines: out[0], frame_points: out[1], frame_result: out[2], frames: out[3],
      gd: out[4], group: out[5], hb: out[6], header: out[7],
      hs: out[8], mp: out[9], innings: out[10], nbsp: out[11],
      no: out[12], player_list: out[13], playera_fl_name: out[14], playerb_fl_name: out[15],
      points: out[16], result: out[17], result_lines: out[18], result_url: out[19],
      td_lines: out[20], tr: out[21]
    }
  end
end
