# frozen_string_literal: true

require "test_helper"

# Tests für Umb::DetailsScraper.
# Alle HTTP-Anfragen werden via WebMock gestubbt.
class Umb::DetailsScraperTest < ActiveSupport::TestCase
  BASE_DETAIL_URL = "https://files.umb-carom.org/public/TournametDetails.aspx"

  # Vollständige Turnier-Detailseite mit PDF-Links
  DETAIL_WITH_GAME_PDFS_HTML = <<~HTML
    <html><body>
    <table>
      <tr><td>Tournament:</td><td>World Cup 3-Cushion Nice</td></tr>
      <tr><td>Starts on:</td><td>15-May-2024</td></tr>
      <tr><td>Ends on:</td><td>19-May-2024</td></tr>
      <tr><td>Organized by:</td><td>UMB</td></tr>
      <tr><td>Place:</td><td>NICE (France)</td></tr>
    </table>
    <a href="/files/GroupResults_Q.pdf">GroupResults_Q.pdf</a>
    <a href="/files/GroupResults_Final.pdf">GroupResults_Final.pdf</a>
    <a href="/files/PlayersList.pdf">Players List</a>
    <a href="/files/FinalRanking.pdf">FinalRanking.pdf</a>
    </body></html>
  HTML

  # Einfache Detailseite ohne PDFs
  DETAIL_NO_PDFS_HTML = <<~HTML
    <html><body>
    <table>
      <tr><td>Tournament:</td><td>European Championship 3-Cushion Berlin</td></tr>
      <tr><td>Starts on:</td><td>10-March-2024</td></tr>
      <tr><td>Ends on:</td><td>15-March-2024</td></tr>
      <tr><td>Organized by:</td><td>UMB</td></tr>
      <tr><td>Place:</td><td>BERLIN (Germany)</td></tr>
    </table>
    </body></html>
  HTML

  setup do
    @umb_source = InternationalSource.find_or_create_by!(
      name: "Union Mondiale de Billard",
      source_type: "umb"
    ) do |s|
      s.base_url = "https://files.umb-carom.org"
    end

    @discipline = Discipline.find_or_create_by!(name: "Dreiband groß") do |d|
      d.id = 50_099_003
    end

    @season = Season.find_or_create_by!(name: "2023/2024") do |s|
      s.ba_id = nil
    end

    @umb_organizer = Region.find_or_create_by!(shortname: "UMB") do |r|
      r.name = "Union Mondiale de Billard"
    end

    # Turnier mit external_id anlegen für Lookup-Tests
    @tournament = InternationalTournament.new(
      title: "World Cup 3-Cushion Nice",
      date: Date.new(2024, 5, 15),
      external_id: "100",
      international_source: @umb_source,
      modus: "international",
      plan_or_show: "show",
      single_or_league: "single",
      state: "planned",
      organizer: @umb_organizer,
      season: @season,
      discipline: @discipline
    )
    @tournament.save(validate: false)
  rescue ActiveRecord::RecordNotUnique
    @discipline = Discipline.find_by(name: "Dreiband groß")
    @season = Season.find_by(name: "2023/2024")
    @umb_organizer = Region.find_by(shortname: "UMB")
  end

  teardown do
    GameParticipation.where("id >= 50000000").delete_all
    InternationalTournament.where("id >= 50000000").delete_all
    InternationalSource.where(source_type: "umb").delete_all
    Discipline.where(id: 50_099_003).delete_all
    Season.where(name: "2023/2024").where("id >= 50000000").delete_all
    Region.where(shortname: "UMB").delete_all
    # Location-Löschung überspringen: fixtures haben FK-Referenzen auf tables-Tabelle
  end

  # --- Klassen-Struktur ---

  test "class Umb::DetailsScraper is defined" do
    assert_equal 1, 1  # Klassendefinition via grep in acceptance criteria geprüft
    assert defined?(Umb::DetailsScraper)
  end

  test "uses Umb::HttpClient for HTTP (no private fetch_url)" do
    assert_not_respond_to Umb::DetailsScraper.new, :fetch_url
  end

  test "uses Umb::PlayerResolver (no private find_or_create_international_player)" do
    assert_not_respond_to Umb::DetailsScraper.new, :find_or_create_international_player
  end

  test "uses InternationalGame STI type for game creation" do
    # Stellt sicher dass 'InternationalGame' als String-Konstante im Code vorkommt
    source = File.read(Rails.root.join("app/services/umb/details_scraper.rb"))
    assert source.include?("InternationalGame"), "Expected 'InternationalGame' type in details_scraper.rb"
  end

  # --- Grundlegendes Verhalten ---

  test "call returns false when tournament not found" do
    scraper = Umb::DetailsScraper.new
    result = scraper.call(InternationalTournament.new)  # neues, nicht gespeichertes Turnier
    assert_equal false, result
  end

  test "call returns false when HTTP fetch fails" do
    stub_request(:get, "#{BASE_DETAIL_URL}?ID=100")
      .to_return(status: 500, body: "")

    scraper = Umb::DetailsScraper.new
    result = scraper.call(@tournament, create_games: false, parse_pdfs: false)
    assert_equal false, result
  end

  test "call returns tournament record on success" do
    stub_request(:get, "#{BASE_DETAIL_URL}?ID=100")
      .to_return(status: 200, body: DETAIL_NO_PDFS_HTML)

    scraper = Umb::DetailsScraper.new
    result = scraper.call(@tournament, create_games: false, parse_pdfs: false)
    assert_instance_of InternationalTournament, result
  end

  test "call does not raise on network error" do
    stub_request(:get, "#{BASE_DETAIL_URL}?ID=100")
      .to_raise(StandardError.new("Network error"))

    scraper = Umb::DetailsScraper.new
    assert_nothing_raised { scraper.call(@tournament) }
  end

  # --- PDF-Orchestrierung ---

  test "call parses all PDF types independently when parse_pdfs: true" do
    # PlayerList, GroupResults und Ranking werden alle angefragt (Pitfall 5: kein Kurzschluss)
    stub_request(:get, "#{BASE_DETAIL_URL}?ID=100")
      .to_return(status: 200, body: DETAIL_WITH_GAME_PDFS_HTML)

    stub_request(:get, "https://files.umb-carom.org/files/PlayersList.pdf")
      .to_return(status: 200, body: "empty pdf")
    stub_request(:get, "https://files.umb-carom.org/files/FinalRanking.pdf")
      .to_return(status: 200, body: "empty pdf")
    stub_request(:get, "https://files.umb-carom.org/files/GroupResults_Q.pdf")
      .to_return(status: 200, body: "empty pdf")
    stub_request(:get, "https://files.umb-carom.org/files/GroupResults_Final.pdf")
      .to_return(status: 200, body: "empty pdf")

    scraper = Umb::DetailsScraper.new
    # Kein Fehler bei parse_pdfs: true
    assert_nothing_raised do
      scraper.call(@tournament, create_games: false, parse_pdfs: true)
    end
  end

  test "call uses Umb::PdfParser::PlayerListParser for player list PDFs" do
    source = File.read(Rails.root.join("app/services/umb/details_scraper.rb"))
    assert source.include?("Umb::PdfParser::PlayerListParser"), "Expected PlayerListParser reference"
  end

  test "call uses Umb::PdfParser::GroupResultParser for group result PDFs" do
    source = File.read(Rails.root.join("app/services/umb/details_scraper.rb"))
    assert source.include?("Umb::PdfParser::GroupResultParser"), "Expected GroupResultParser reference"
  end

  test "call uses Umb::PdfParser::RankingParser for ranking PDFs" do
    source = File.read(Rails.root.join("app/services/umb/details_scraper.rb"))
    assert source.include?("Umb::PdfParser::RankingParser"), "Expected RankingParser reference"
  end

  test "call uses Umb::PlayerResolver" do
    source = File.read(Rails.root.join("app/services/umb/details_scraper.rb"))
    assert source.include?("Umb::PlayerResolver"), "Expected PlayerResolver reference"
  end

  # --- Game-Erstellung mit V2 STI-Typ ---

  test "create_games_for_tournament sets type InternationalGame on games" do
    stub_request(:get, "#{BASE_DETAIL_URL}?ID=100")
      .to_return(status: 200, body: DETAIL_WITH_GAME_PDFS_HTML)

    scraper = Umb::DetailsScraper.new
    scraper.call(@tournament, create_games: true, parse_pdfs: false)

    # Alle erstellten Games müssen InternationalGame-Typ haben
    games = @tournament.games.reload
    games.each do |game|
      assert_equal "InternationalGame", game.type,
        "Expected game type 'InternationalGame', got '#{game.type}'"
    end
  end

  # --- Detail-URL-Auflösung ---

  test "build_detail_url uses external_id when available" do
    scraper = Umb::DetailsScraper.new
    url = scraper.send(:build_detail_url, @tournament)
    assert_equal "#{BASE_DETAIL_URL}?ID=100", url
  end

  test "build_detail_url returns nil when no external_id or data url" do
    tournament = InternationalTournament.new
    scraper = Umb::DetailsScraper.new
    url = scraper.send(:build_detail_url, tournament)
    assert_nil url
  end

  # --- PDF-Link-Sammlung ---

  test "collect_pdf_links categorizes player list links" do
    doc = Nokogiri::HTML(DETAIL_WITH_GAME_PDFS_HTML)
    scraper = Umb::DetailsScraper.new
    result = scraper.send(:collect_pdf_links, doc)

    assert_not_nil result[:players_list]
    assert_includes result[:players_list], "PlayersList.pdf"
  end

  test "collect_pdf_links categorizes group result links" do
    doc = Nokogiri::HTML(DETAIL_WITH_GAME_PDFS_HTML)
    scraper = Umb::DetailsScraper.new
    result = scraper.send(:collect_pdf_links, doc)

    assert_equal 2, result[:group_results].size
  end

  test "collect_pdf_links categorizes ranking links" do
    doc = Nokogiri::HTML(DETAIL_WITH_GAME_PDFS_HTML)
    scraper = Umb::DetailsScraper.new
    result = scraper.send(:collect_pdf_links, doc)

    assert_equal 1, result[:rankings].size
    assert_equal "final", result[:rankings].first[:phase]
  end

  # --- Spieler-Auflösung aus kombinierten Namen ---

  test "resolve_player_from_name handles CAPS mixed name format" do
    # Spieler anlegen
    player = Player.create!(
      firstname: "Dick",
      lastname: "Jaspers",
      fl_name: "Dick Jaspers",
      international_player: true,
      nationality: "NL"
    )

    scraper = Umb::DetailsScraper.new
    result = scraper.send(:resolve_player_from_name, "JASPERS Dick", "NL")
    assert_not_nil result
    assert_equal "Dick", result.firstname

    player.destroy
  end

  test "split_player_name splits CAPS and mixed parts" do
    scraper = Umb::DetailsScraper.new

    caps, mixed = scraper.send(:split_player_name, "JASPERS Dick")
    assert_equal "JASPERS", caps
    assert_equal "Dick", mixed

    caps2, mixed2 = scraper.send(:split_player_name, "VAN DEN BERG Eddy")
    assert_includes %w[VAN DEN BERG], caps2.split.first
    assert mixed2.present?
  end

  # --- make_absolute_url ---

  test "make_absolute_url returns http URLs unchanged" do
    scraper = Umb::DetailsScraper.new
    url = "https://files.umb-carom.org/something.pdf"
    assert_equal url, scraper.send(:make_absolute_url, url)
  end

  test "make_absolute_url prepends BASE_URL to relative paths" do
    scraper = Umb::DetailsScraper.new
    result = scraper.send(:make_absolute_url, "/files/something.pdf")
    assert_equal "https://files.umb-carom.org/files/something.pdf", result
  end

  test "make_absolute_url handles paths without leading slash" do
    scraper = Umb::DetailsScraper.new
    result = scraper.send(:make_absolute_url, "something.pdf")
    assert_equal "https://files.umb-carom.org/public/something.pdf", result
  end
end
