# frozen_string_literal: true

require "test_helper"

# Tests for Tournament::PublicCcScraper ApplicationService.
#
# Verifies that the service delegates correctly from Tournament and that
# guard conditions are preserved after extraction from Tournament.
class Tournament::PublicCcScraperTest < ActiveSupport::TestCase
  fixtures :all

  SCRAPER_TEST_ID_BASE = 50_300_000

  self.use_transactional_tests = true

  setup do
    @id_counter = 0

    # Originalwert merken, damit Tests, die carambus_api_url mutieren, im
    # teardown nicht hart auf nil zurücksetzen und damit andere Tests der
    # Suite vergiften.
    @original_api_url = Carambus.config.carambus_api_url

    @region = regions(:nbv)
    @region.update_column(:public_cc_url_base, "https://ndbv.de/")

    @region_cc = RegionCc.find_or_initialize_by(context: "nbv")
    @region_cc.assign_attributes(cc_id: 30, region_id: @region.id)
    @region_cc.save!

    @season = seasons(:current)
    @tournament = build_tournament
  end

  teardown do
    Carambus.config.carambus_api_url = @original_api_url
  end

  # ---------------------------------------------------------------------------
  # Guard: non-Region organizer returns nil without HTTP calls
  # ---------------------------------------------------------------------------

  test "call returns nil when organizer_type is not Region" do
    t = Tournament.create!(
      id: next_id,
      title: "Club Scraper Test",
      season: @season,
      organizer: clubs(:bcw),
      organizer_type: "Club",
      discipline: disciplines(:carom_3band),
      state: "registration"
    )
    result = Tournament::PublicCcScraper.call(tournament: t, opts: {})
    assert_nil result
  end

  # ---------------------------------------------------------------------------
  # Guard: API server context returns nil without HTTP calls
  # ---------------------------------------------------------------------------

  test "call returns nil when carambus_api_url is present" do
    Carambus.config.carambus_api_url = "https://api.carambus.de"
    result = Tournament::PublicCcScraper.call(tournament: @tournament, opts: {})
    assert_nil result
  end

  # ---------------------------------------------------------------------------
  # Integration: service executes successfully with WebMock stubs
  # ---------------------------------------------------------------------------

  test "call executes without error when tournament_doc is provided" do
    # Auf Local Servern (carambus_api_url gesetzt) returnt PublicCcScraper früh
    # und setzt source_url nicht — der Integrationspfad ist nur auf API-Servern relevant.
    skip_unless_api_server

    # Stub the 3 remaining HTTP calls (meldeliste, einzelergebnisse, einzelrangliste)
    stub_request(:get, /ndbv\.de/)
      .to_return(status: 200, body: minimal_html, headers: { "Content-Type" => "text/html" })

    tournament_doc = Nokogiri::HTML(meisterschaft_html)
    assert_nothing_raised do
      Tournament::PublicCcScraper.call(tournament: @tournament, opts: { tournament_doc: tournament_doc })
    end

    # source_url was set by the service
    assert @tournament.reload.source_url.present?
  end

  private

  def next_id
    @id_counter += 1
    SCRAPER_TEST_ID_BASE + @id_counter
  end

  def build_tournament
    t = Tournament.create!(
      id: next_id,
      title: "PublicCcScraper Test Tournament",
      season: @season,
      organizer: @region,
      organizer_type: "Region",
      discipline: disciplines(:carom_3band),
      state: "registration"
    )
    TournamentCc.create!(
      tournament: t,
      name: t.title,
      cc_id: next_id,
      context: "nbv",
      season: @season.name
    )
    t.reload
    t
  end

  def meisterschaft_html
    <<~HTML
      <html><body>
        <aside>
          <table class="silver">
            <tr><td>K&#252;rzel</td><td>NBV-SCRAPER-2025</td></tr>
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
  end

  def minimal_html
    <<~HTML
      <html><body>
        <aside>
          <table class="silver"></table>
          <table class="silver"></table>
        </aside>
      </body></html>
    HTML
  end
end
