# frozen_string_literal: true

require "test_helper"
require "rake"

# clubs:split — zwei Vereine, die in einem Datensatz stecken, wieder trennen.
class ClubsSplitTest < ActiveSupport::TestCase
  BASE_ID = 53_950_000
  PHOENIX = "Billard Club Phoenix Übach-Palenberg 1996 e.V."

  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    @n = 0
    @blmr = Region.create!(name: "Mittelrhein e.V.", shortname: "TBLM", cc_id: 13, public_cc_url_base: "https://blmr-cc.example/")
    @a = Club.create!(name: "Pool Billard Club Würselen 81 e.V.", shortname: "PBC Würselen 81", region: @blmr,
      cc_id: 6306, synonyms: "Pool Billard Club Würselen 81 e.V.\nBC Phoenix Übach-Palenberg\n#{PHOENIX}\nPBC Würselen 81")
    ClubCcEntry.record!(@a, @blmr, 6335)
    @league = League.create!(id: nid, name: "Bezirksliga", shortname: "BZL#{@n}", organizer: @blmr, organizer_type: "Region",
      season: seasons(:current), discipline: disciplines(:pool_8ball), cc_id: 900)
    @wuerselen_team = LeagueTeam.create!(id: nid, name: "PBC Würselen 81 1", league: @league, club: @a)
    @phoenix_team = LeagueTeam.create!(id: nid, name: "BC Phoenix Übach-Palenberg 2", league: @league, club: @a)
    @w = player_in(@wuerselen_team)
    @p = player_in(@phoenix_team)
    @both = player_in(@wuerselen_team)
    Seeding.create!(id: nid, player: @both, league_team: @phoenix_team)
    @loose = Player.create!(id: nid, firstname: "Ohne", lastname: "Team")
    SeasonParticipation.create!(id: nid, player: @loose, season: seasons(:current), club: @a)
  end

  teardown { %w[CLUB NAME SHORTNAME REGION CC_ID DBU_NR TEAMS_NAME ARMED].each { |k| ENV.delete(k) } }

  def nid = BASE_ID + (@n += 1)

  def player_in(team)
    player = Player.create!(id: nid, firstname: "Spieler#{@n}", lastname: "X")
    Seeding.create!(id: nid, player: player, league_team: team)
    SeasonParticipation.create!(id: nid, player: player, season: seasons(:current), club: @a)
    player
  end

  def split(armed: false)
    ENV.update("CLUB" => @a.id.to_s, "NAME" => PHOENIX, "SHORTNAME" => "BC Phoenix Übach-Palenberg", "REGION" => "TBLM",
      "CC_ID" => "6306", "DBU_NR" => "1628", "TEAMS_NAME" => "%phoenix%")
    ENV["ARMED"] = "true" if armed
    Rake::Task["clubs:split"].reenable
    capture_io { Rake::Task["clubs:split"].invoke }.first
  end

  test "Probelauf schreibt nichts" do
    out = split

    assert_match "LeagueTeams → BC Phoenix Übach-Palenberg: 1", out
    assert_nil Club.find_by(shortname: "BC Phoenix Übach-Palenberg")
    assert_includes @a.reload.synonyms, PHOENIX
    assert_equal @a.id, @phoenix_team.reload.club_id
  end

  test "ARMED trennt Synonyme, Teams, eindeutige Teilnahmen und cc_ids" do
    split(armed: true)

    b = Club.find_by!(shortname: "BC Phoenix Übach-Palenberg")
    assert_equal [@blmr.id, 6306, 1628], [b.region_id, b.cc_id, b.dbu_nr]
    assert_includes b.synonyms.split("\n"), PHOENIX
    @a.reload
    assert_equal %w[Pool\ Billard\ Club\ Würselen\ 81\ e.V. PBC\ Würselen\ 81], @a.synonyms.split("\n")
    assert_equal 6335, @a.cc_id, "A bekommt seine Heimat-cc_id zurück"

    assert_equal b.id, @phoenix_team.reload.club_id
    assert_equal @a.id, @wuerselen_team.reload.club_id
    club_of = ->(player) { SeasonParticipation.find_by!(player: player).club_id }
    assert_equal b.id, club_of.call(@p), "nur in Phoenix-Team gemeldet → B"
    assert_equal @a.id, club_of.call(@w)
    assert_equal @a.id, club_of.call(@both), "in beiden Teams gemeldet → bleibt bei A"
    assert_equal @a.id, club_of.call(@loose), "ohne Team → bleibt bei A"

    assert_equal b, ClubCcEntry.club_for(@blmr.id, 6306)
    assert_equal @a, ClubCcEntry.club_for(@blmr.id, 6335)
  end

  def move_locations(moves, armed: false)
    ENV["MOVES"] = moves
    ENV["ARMED"] = "true" if armed
    Rake::Task["clubs:move_locations"].reenable
    capture_io { Rake::Task["clubs:move_locations"].invoke }.first
  ensure
    ENV.delete("MOVES")
    ENV.delete("ARMED")
  end

  test "move_locations hängt den Spielort um, andere Vereine am Ort bleiben" do
    b = Club.create!(name: PHOENIX, shortname: "BC Phoenix Übach-Palenberg", region: @blmr, cc_id: 6306)
    venue = Location.create!(id: nid, name: "Vereinsheim BC Phoenix 1996", organizer: @blmr)
    ClubLocation.create!(club: @a, location: venue)
    neighbour = Club.create!(name: "Cinema-Billard-Club", shortname: "Cinema", region: @blmr, cc_id: 77)
    ClubLocation.create!(club: neighbour, location: venue)

    assert_match "→ BC Phoenix Übach-Palenberg", move_locations("#{venue.id}:#{@a.id}:#{b.id}")
    assert ClubLocation.exists?(club: @a, location: venue), "Probelauf schreibt nicht"

    move_locations("#{venue.id}:#{@a.id}:#{b.id}", armed: true)

    assert_equal [b.id, neighbour.id].sort, ClubLocation.where(location: venue).pluck(:club_id).sort
    assert_match "übersprungen", move_locations("#{venue.id}:#{@a.id}:#{b.id}", armed: true), "zweiter Lauf: nichts mehr da"
  end

  test "move_locations: hat B den Ort schon, entfällt nur A's Zuordnung" do
    b = Club.create!(name: PHOENIX, shortname: "BC Phoenix Übach-Palenberg", region: @blmr, cc_id: 6306)
    venue = Location.create!(id: nid, name: "Gemeinsam", organizer: @blmr)
    ClubLocation.create!(club: @a, location: venue)
    ClubLocation.create!(club: b, location: venue)

    move_locations("#{venue.id}:#{@a.id}:#{b.id}", armed: true)

    assert_equal [b.id], ClubLocation.where(location: venue).pluck(:club_id)
  end

  test "bricht ab, wenn A selbst den Namen von B trägt" do
    @a.update_columns(name: PHOENIX)

    assert_raises(SystemExit) { capture_io { split(armed: true) } }
    assert_nil Club.find_by(shortname: "BC Phoenix Übach-Palenberg")
  end
end
