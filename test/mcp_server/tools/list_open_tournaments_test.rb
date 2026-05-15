# frozen_string_literal: true

require "test_helper"

class McpServer::Tools::ListOpenTournamentsTest < ActiveSupport::TestCase
  setup do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    ENV["CC_FED_ID"] = nil
    ENV["CC_REGION"] = nil
    McpServer::CcSession.reset!
  end

  teardown do
    ENV["CARAMBUS_MCP_MOCK"] = nil
    ENV["CC_FED_ID"] = nil
    ENV["CC_REGION"] = nil
  end

  # Plan 14-02.3 / D-14-02-G: strict User-Context via server_context: {cc_region: "NBV"}.
  # Vorher: shortname: "NBV" direkt + server_context: nil — wird in 14-02.4 entfernt.
  test "DB-first happy path NBV: returns data + meta with last_sync_age_hours" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV fixtures missing" unless nbv

    response = McpServer::Tools::ListOpenTournaments.call(
      server_context: {cc_region: "NBV"}
    )
    refute response.error?, "Expected non-error; got: #{response.content.first[:text]}"

    body = JSON.parse(response.content.first[:text])
    assert_kind_of Array, body["data"]
    assert_kind_of Hash, body["meta"]
    assert_equal "NBV", body["meta"]["region"]
    assert_equal body["data"].length, body["meta"]["count"]
    assert_kind_of Numeric, body["meta"]["last_sync_age_hours"] unless body["meta"]["last_sync_age_hours"].nil?
    assert_equal "upcoming", body["meta"]["mode"]
    # Plan 14-02.3 / F-1: Default-Mode `upcoming` filter ist Akkreditierung-agnostisch.
    assert_match(/date >=/, body["meta"]["filter_basis"])
  end

  # Plan 14-02.3 / F-4: Output enthält tournament_id (Carambus-id) + cc_id (TournamentCc.cc_id).
  test "Output struktur F-4: tournament_id + cc_id + branch + discipline_name + season" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV fixtures missing" unless nbv
    response = McpServer::Tools::ListOpenTournaments.call(
      server_context: {cc_region: "NBV"},
      open_after: "2000-01-01"
    )
    refute response.error?
    body = JSON.parse(response.content.first[:text])
    skip "No NBV data to verify schema" if body["data"].empty?
    sample = body["data"].first
    assert sample.key?("tournament_id"), "F-4: tournament_id muss im Output sein"
    assert sample.key?("cc_id"), "F-4: cc_id muss im Output sein"
    assert sample.key?("branch"), "F-4: branch muss im Output sein"
    assert sample.key?("discipline_name"), "F-4: discipline_name muss im Output sein"
    assert sample.key?("season"), "F-7: season muss im Output sein"
    refute sample.key?("id"), "F-4: 'id'-Key wurde durch tournament_id ersetzt"
  end

  # Plan 14-02.3 / F-1 mode='upcoming' (Default): laufende Turniere sichtbar (Akkreditierung egal).
  test "mode upcoming (Default): date >= today, Akkreditierung agnostisch" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV fixtures missing" unless nbv
    response = McpServer::Tools::ListOpenTournaments.call(
      server_context: {cc_region: "NBV"},
      mode: "upcoming"
    )
    refute response.error?
    body = JSON.parse(response.content.first[:text])
    assert_equal "upcoming", body["meta"]["mode"]
    refute_match(/accredation_end/, body["meta"]["filter_basis"], "mode=upcoming darf accredation_end-Filter NICHT enthalten")
  end

  # Plan 14-02.3 / F-1 mode='registration_open': strict accredation_end >= today.
  test "mode registration_open: accredation_end >= today AND date >= today" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV fixtures missing" unless nbv
    response = McpServer::Tools::ListOpenTournaments.call(
      server_context: {cc_region: "NBV"},
      mode: "registration_open"
    )
    refute response.error?
    body = JSON.parse(response.content.first[:text])
    assert_equal "registration_open", body["meta"]["mode"]
    assert_match(/accredation_end >=/, body["meta"]["filter_basis"])
  end

  # Plan 14-02.3 / F-1 mode='active': date in den nächsten 7 Tagen.
  test "mode active: date BETWEEN today AND today+7d" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV fixtures missing" unless nbv
    response = McpServer::Tools::ListOpenTournaments.call(
      server_context: {cc_region: "NBV"},
      mode: "active"
    )
    refute response.error?
    body = JSON.parse(response.content.first[:text])
    assert_equal "active", body["meta"]["mode"]
    assert_match(/date BETWEEN/, body["meta"]["filter_basis"])
  end

  # Plan 14-02.3 / F-1 mode='recent': vorletzte Woche bis nächste 2 Wochen.
  test "mode recent: date BETWEEN today-14d AND today+14d" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV fixtures missing" unless nbv
    response = McpServer::Tools::ListOpenTournaments.call(
      server_context: {cc_region: "NBV"},
      mode: "recent"
    )
    refute response.error?
    body = JSON.parse(response.content.first[:text])
    assert_equal "recent", body["meta"]["mode"]
    assert_match(/date BETWEEN/, body["meta"]["filter_basis"])
  end

  # Plan 14-02.3 / F-2: Branch-Filter matched alle Sub-Disciplines.
  test "discipline 'Pool' (Branch-Match): liefert alle Pool-Sub-Disciplines" do
    nbv = Region.find_by(shortname: "NBV")
    pool_branch = Branch.find_by("name ILIKE ?", "Pool")
    skip "NBV / Pool-Branch fixtures missing" unless nbv && pool_branch

    response = McpServer::Tools::ListOpenTournaments.call(
      server_context: {cc_region: "NBV"},
      discipline: "Pool",
      open_after: "2000-01-01"
    )
    refute response.error?
    body = JSON.parse(response.content.first[:text])
    assert_equal "Pool", body["meta"]["branch"]
    pool_discipline_ids = Discipline.where(super_discipline_id: pool_branch.id).pluck(:id)
    body["data"].each do |t|
      assert_includes pool_discipline_ids, t["discipline_id"], "Pool-Branch-Filter muss nur Pool-Sub-Disciplines liefern"
    end
  end

  # Plan 14-02.3 / F-2: konkrete Discipline matched (kein Branch-Treffer).
  test "discipline filter narrows results (Discipline-Match)" do
    nbv = Region.find_by(shortname: "NBV")
    discipline = Discipline.find_by(name: "Freie Partie klein")
    skip "Fixtures missing" unless nbv && discipline

    response_all = McpServer::Tools::ListOpenTournaments.call(
      server_context: {cc_region: "NBV"},
      open_after: "2000-01-01"
    )
    refute response_all.error?
    all_count = JSON.parse(response_all.content.first[:text])["data"].length

    response_filtered = McpServer::Tools::ListOpenTournaments.call(
      server_context: {cc_region: "NBV"},
      discipline: "Freie Partie klein",
      open_after: "2000-01-01"
    )
    refute response_filtered.error?
    filtered_body = JSON.parse(response_filtered.content.first[:text])
    assert_operator filtered_body["data"].length, :<=, all_count
    assert_equal "Freie Partie klein", filtered_body["meta"]["discipline"]
    filtered_body["data"].each do |t|
      assert_equal discipline.id, t["discipline_id"]
    end
  end

  # Plan 14-02.3 / F-7: Season-Default-Filter filtert Cross-Season-Records raus.
  test "Season-Default-Filter: nur current_season-Records by default" do
    nbv = Region.find_by(shortname: "NBV")
    current = Season.current_season
    skip "NBV / current_season missing" unless nbv && current

    response = McpServer::Tools::ListOpenTournaments.call(
      server_context: {cc_region: "NBV"},
      open_after: "2000-01-01"
    )
    refute response.error?
    body = JSON.parse(response.content.first[:text])
    assert_equal current.name, body["meta"]["season"], "Default-Season muss current_season sein"
    body["data"].each do |t|
      next if t["season"].nil?  # data-quality-bug: TournamentCc.season=null tolerieren
      assert_equal current.name, t["season"], "Default-Filter muss Cross-Season-Records ausschließen"
    end
  end

  # Plan 14-G.7 / AC-1: Scenario-Config-strict — ohne Carambus.config.context → Diagnostic-Error.
  test "missing Scenario-Config: returns error with Scenario-Config-Fehler-Hinweis" do
    response = McpServer::Tools::ListOpenTournaments.call(server_context: nil)
    assert response.error?
    assert_match(/Scenario-Config-Fehler.*Carambus\.config\.context/i, response.content.first[:text])
  end

  # Plan 14-02.2 / B-3 + D-14-02-G: shortname-Override ungleich User-Region wird ignoriert + warning.
  test "shortname-Override ungleich User-Region: ignoriert, Warning, nutzt User-Region" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV fixtures missing" unless nbv
    response = McpServer::Tools::ListOpenTournaments.call(
      shortname: "BVBW",  # Override-Versuch
      server_context: {cc_region: "NBV"}
    )
    refute response.error?, "Override soll NICHT zum Error führen — nur warning + ignore"
    body = JSON.parse(response.content.first[:text])
    assert_equal "NBV", body["meta"]["region"], "User-Region muss gewinnen"
  end

  test "unknown discipline returns error mit Sportwart-Vokabular" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV fixtures missing" unless nbv

    response = McpServer::Tools::ListOpenTournaments.call(
      server_context: {cc_region: "NBV"},
      discipline: "Nonexistent-#{SecureRandom.hex(4)}"
    )
    assert response.error?
    assert_match(/Discipline.*nicht gefunden|Branch/i, response.content.first[:text])
  end

  test "invalid open_after returns error" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV fixtures missing" unless nbv

    response = McpServer::Tools::ListOpenTournaments.call(
      server_context: {cc_region: "NBV"},
      open_after: "not-a-date"
    )
    assert response.error?
    assert_match(/Ungültig.*open_after/i, response.content.first[:text])
  end

  test "name filter: case-insensitive ILIKE narrows by Tournament.title substring" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV fixtures missing" unless nbv

    far_past = "2000-01-01"
    sample = Tournament.where(region_id: nbv.id)
      .where("date >= ?", far_past)
      .where.not(title: [nil, ""])
      .first
    skip "No NBV tournaments with non-empty title" unless sample
    skip "Sample title too short" if sample.title.to_s.length < 4

    needle = sample.title[1, 3].downcase

    response = McpServer::Tools::ListOpenTournaments.call(
      server_context: {cc_region: "NBV"},
      name: needle,
      open_after: far_past,
      include_no_date: true,
      mode: "registration_open"  # include_no_date relevant nur für diesen Mode
    )
    refute response.error?
    body = JSON.parse(response.content.first[:text])

    body["data"].each do |t|
      assert_match(/#{Regexp.escape(needle)}/i, t["title"], "Each result must contain needle (case-insensitive)")
    end
    assert_match(/title ILIKE '%#{Regexp.escape(needle)}%'/, body["meta"]["filter_basis"])
    assert_equal needle, body["meta"]["name"]
  end

  test "no name filter: backwards-compatible (kein Regression)" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV fixtures missing" unless nbv

    response = McpServer::Tools::ListOpenTournaments.call(server_context: {cc_region: "NBV"})
    refute response.error?
    body = JSON.parse(response.content.first[:text])

    refute_match(/title ILIKE/, body["meta"]["filter_basis"])
    assert_nil body["meta"]["name"]
  end

  test "name filter: non-matching substring returns empty data" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV fixtures missing" unless nbv

    needle = "ZzzNonexistent#{SecureRandom.hex(4)}"
    response = McpServer::Tools::ListOpenTournaments.call(
      server_context: {cc_region: "NBV"},
      name: needle
    )
    refute response.error?
    body = JSON.parse(response.content.first[:text])

    assert_equal [], body["data"]
    assert_equal 0, body["meta"]["count"]
    assert_equal needle, body["meta"]["name"]
  end

  test "name filter: SQL-LIKE special characters are escaped" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV fixtures missing" unless nbv

    response = McpServer::Tools::ListOpenTournaments.call(
      server_context: {cc_region: "NBV"},
      name: "100%"
    )
    refute response.error?
    body = JSON.parse(response.content.first[:text])

    body["data"].each do |t|
      assert_match(/100%/, t["title"], "Each result must contain literal '100%' substring")
    end
  end

  test "force_refresh: true with sync raising stays defensive (no crash)" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV fixtures missing" unless nbv
    region_cc = nbv.region_cc
    skip "RegionCc missing for NBV" unless region_cc

    region_cc.stub(:sync_tournaments, ->(_) { raise StandardError, "stubbed sync failure" }) do
      response = McpServer::Tools::ListOpenTournaments.call(
        server_context: {cc_region: "NBV"},
        force_refresh: true
      )
      refute response.error?, "Tool should be defensive against sync failure"
    end
  end

  # Plan 10-05 Task 2 (Befund #4 D-10-01-3): nach erfolgreichem force_refresh
  # muss last_sync_age_hours ~0 sein (Resync-Marker, nicht stale Tournament.sync_date).
  test "force_refresh: erfolgreicher sync ergibt frisches last_sync_age_hours (~0.0h)" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV fixtures missing" unless nbv
    region_cc = nbv.region_cc
    skip "RegionCc missing for NBV" unless region_cc

    region_cc.stub(:sync_tournaments, ->(_) { [[], nil] }) do
      response = McpServer::Tools::ListOpenTournaments.call(
        server_context: {cc_region: "NBV"},
        force_refresh: true
      )
      refute response.error?
      body = JSON.parse(response.content.first[:text])
      assert_kind_of Numeric, body["meta"]["last_sync_age_hours"]
      assert_in_delta 0.0, body["meta"]["last_sync_age_hours"], 0.1,
        "force_refresh:true mit erfolgreichem Sync muss last_sync_age_hours auf ~0.0 setzen"
    end
  end

  test "force_refresh: false — last_sync_age_hours fällt auf Tournament.sync_date zurück" do
    nbv = Region.find_by(shortname: "NBV")
    skip "NBV fixtures missing" unless nbv

    response = McpServer::Tools::ListOpenTournaments.call(
      server_context: {cc_region: "NBV"},
      force_refresh: false
    )
    refute response.error?
    body = JSON.parse(response.content.first[:text])
    assert body["meta"].key?("last_sync_age_hours"), "last_sync_age_hours muss präsent sein"
  end

  # Plan 14-G.10 / Hot-Fix-Regression: Map-Block muss mit echter Tournament+TournamentCc
  # durchlaufen. Pre-14-G.10-Code rief `t.tournament_ccs` (Plural) auf eine
  # has_one :tournament_cc Association — wirft NoMethodError im Map-Block, MCP SDK
  # returned -32603 Internal Error im Body (HTTP 200 in Rails-Log; deshalb
  # production.log clean). Existing Tests skipped bei body["data"].empty? — Bug schlüpft
  # durch. NEUER Test FORCE-IT: inline-build Tournament + TournamentCc → Map-Block läuft
  # → Bug reproduziert ohne Fix, PASS mit Fix.
  #
  # Inline-build statt Fixtures damit andere Tests (lookup_tournament_test.rb, die
  # `TournamentCc.first` für Sample wählen) nicht auf diesen test-spezifischen Datensatz
  # treffen — fixture-shared-state hatte 4 unbeabsichtigte Failures verursacht weil die
  # anderen Tests andere TournamentCc-Eigenschaften (registration_list_cc_id present,
  # Wording-Patterns) erwarten als unser Test-Sample bietet.
  test "F-4 regression (14-G.10): map block executes with real Tournament+TournamentCc inline-build" do
    nbv = regions(:nbv)

    # Inline-build: Tournament im NBV-Region-Scope + TournamentCc(context: "nbv") 1:1.
    # Cleanup nach Test via ensure-block (kein DatabaseCleaner-Konflikt).
    tournament = Tournament.create!(
      id: 50_000_310,
      title: "Plan 14-G.10 Regression Test Tournament",
      season_id: 50_000_001,        # seasons(:current)
      organizer_id: nbv.id,
      organizer_type: "Region",
      region_id: nbv.id,             # REQUIRED for cc_list_open_tournaments scope
      discipline_id: 50_000_001,     # disciplines(:carom_3band)
      tournament_plan_id: 50_000_100,
      state: "tournament_mode_defined",
      date: 2.weeks.from_now,
      accredation_end: 1.week.from_now
    )

    tournament_cc = TournamentCc.create!(
      cc_id: 99_999,
      context: "nbv",                # DB-Convention: lowercase
      tournament_id: tournament.id,
      name: "Plan 14-G.10 Regression Test Tournament",
      status: "registration_open",
      season: "2025/2026"
    )

    begin
      response = McpServer::Tools::ListOpenTournaments.call(
        server_context: {cc_region: "NBV"},
        open_after: (Date.today - 1.day).iso8601
      )
      refute response.error?, "Expected non-error; got: #{response.content.first[:text]}"

      body = JSON.parse(response.content.first[:text])
      assert body["data"].is_a?(Array) && body["data"].length >= 1,
        "Map-Block muss mind. 1 Eintrag liefern (Bug-Repro: leer war Plural-Fail)"

      sample = body["data"].find { |t| t["tournament_id"] == tournament.id }
      assert sample, "Inline-Tournament (id=#{tournament.id}) muss im Output gefunden werden"
      assert_equal tournament_cc.cc_id, sample["cc_id"],
        "F-4: cc_id aus TournamentCc (context-match) muss korrekt zurückgegeben werden"
      assert_equal tournament.title, sample["title"]
      assert sample.key?("branch")
      assert sample.key?("discipline_name")
      assert sample.key?("season")
    ensure
      tournament_cc&.destroy
      tournament&.destroy
    end
  end
end
