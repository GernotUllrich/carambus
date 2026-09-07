# frozen_string_literal: true

require "test_helper"

# Version-Tagging beim Schreiben (Phase 47-01)
#
# Ungetaggte Versionen passieren `Version.for_region` fuer JEDE Region
# (version.rb:48) — ein Local Server kann dadurch nie "Datenstand aktuell"
# erreichen. Die Messung auf der Produktion vom 2026-09-07 fand 106 092 von
# 181 019 Versionen (58,6 %) ohne `region_id`, obwohl die Ableitung
# `find_associated_region_id` fuer die Mehrzahl einen Wert liefern koennte.
#
# IST-ZUSTAND vor dem Fix (dieser Test, gegen `master` @ 059da626 gelaufen):
#   AC-1 create  ROT — Version.region_id ist nil statt der Region des organizers
#   AC-2 update  ROT — dito
#   AC-3 destroy ROT — dito (hier scheitert der after_destroy-Callback daran,
#                      dass `latest_version.item` zu diesem Zeitpunkt nil ist)
#   AC-4/5/5b    GRUEN — die bereits korrekten Faelle, als Regressionsschutz
#
# Ursache (Phase 47-01, inzwischen behoben): der entfernte Callback `update_version_region_data` rief
# `find_associated_region_id` NIE auf, sondern liest `latest_item.region_id`,
# also die gleichnamige SPALTE — und die ist bei den betroffenen Records leer.
class RegionTaggableVersionStampingTest < ActiveSupport::TestCase
  setup do
    skip_unless_api_server
    @pt_was_enabled = PaperTrail.request.enabled?
    PaperTrail.request.enabled = true

    @region = regions(:nbv)
    @dbu = regions(:dbu)
    @season = seasons(:current)
    @club = clubs(:bcw)
  end

  teardown do
    PaperTrail.request.enabled = @pt_was_enabled
  end

  # --- AC-1: create stempelt aus der Ableitung ----------------------------

  test "AC-1 create: Tournament mit Region-organizer stempelt region_id" do
    tournament = create_region_tournament

    assert_nil tournament.read_attribute(:region_id),
      "Testvoraussetzung: die Record-SPALTE region_id ist leer — genau der Fall, " \
      "den die Messung als Haupttreiber ausweist"
    assert_equal @region.id, tournament.find_associated_region_id,
      "Testvoraussetzung: die Ableitung kann die Region sehr wohl bestimmen"

    version = tournament.versions.last
    assert_equal "create", version.event
    assert_equal @region.id, version.region_id,
      "AC-1: die create-Version muss die abgeleitete Region tragen"
  end

  # --- AC-2: update stempelt aus der Ableitung ---------------------------

  test "AC-2 update: Game stempelt die Region seines Tournaments" do
    tournament = create_region_tournament
    game = Game.create!(tournament: tournament, seqno: 1, gname: "ZZ47 G1")

    game.update!(gname: "ZZ47 G1b")

    version = game.versions.last
    assert_equal "update", version.event
    assert_equal @region.id, version.region_id,
      "AC-2: die update-Version muss die ueber das Tournament abgeleitete Region tragen"
  end

  # --- AC-3: destroy stempelt ebenfalls -----------------------------------

  test "AC-3 destroy: SeasonParticipation stempelt die Region ihres Clubs" do
    participation = SeasonParticipation.create!(
      season: @season, player: create_player, club: @club
    )
    assert_equal @club.region_id, participation.find_associated_region_id,
      "Testvoraussetzung: die Ableitung fuehrt ueber den Club zur Region"

    participation.destroy!

    version = PaperTrail::Version.where(
      item_type: "SeasonParticipation", item_id: participation.id, event: "destroy"
    ).last
    assert_not_nil version, "es muss eine destroy-Version geben"
    assert_equal @club.region_id, version.region_id,
      "AC-3: auch die destroy-Version muss die Region tragen — das Meta wird " \
      "ausgewertet, waehrend der Record noch steht"
  end

  # --- 47-02 AC-1/AC-2: der Liga-Pfad ------------------------------------

  test "47-02 AC-1 Liga-Spiel leitet seine Region ueber die Party ab" do
    party = create_league_party
    game = party.games.create!(seqno: 1, gname: "ZZ47 Liga-G1")

    assert_equal "Party", game.tournament_type,
      "Testvoraussetzung: Party has_many :games, as: :tournament"
    assert_equal @region.id, game.find_associated_region_id,
      "AC-2: die Ableitung muss ueber party.league zur Region finden"

    assert_equal @region.id, game.versions.last.region_id,
      "AC-1: die Version des Liga-Spiels traegt die Region der Liga"
  end

  test "47-02 AC-2 Liga-Pfad wirft nicht mehr" do
    party = create_league_party
    game = party.games.create!(seqno: 2, gname: "ZZ47 Liga-G2")

    assert_nothing_raised do
      game.find_associated_region_id
      GameParticipation.new(game: game).find_associated_region_id
    end
  end

  test "47-02 GameParticipation folgt ihrem Game auch auf dem Liga-Pfad" do
    party = create_league_party
    game = party.games.create!(seqno: 3, gname: "ZZ47 Liga-G3")
    gp = GameParticipation.create!(game: game, player: create_player, role: "player_a")

    assert_equal @region.id, gp.versions.last.region_id
  end

  test "47-02 Seeding an einem Turnier wird getaggt (tournament_type Tournament)" do
    tournament = create_region_tournament
    seeding = Seeding.create!(tournament: tournament, player: create_player)

    assert_equal "Tournament", seeding.tournament_type,
      "Testvoraussetzung: Tournament has_many :seedings, as: :tournament"
    assert_equal @region.id, seeding.versions.last.region_id,
      "der Zweig prueft frueher auf \"Region\" und lief damit ins Leere"
  end

  # --- 47-02 AC-3/AC-4: bisher nicht angeschlossene Modelle ---------------

  test "47-02 AC-3 PlayerRanking wird ueber sein belongs_to :region getaggt" do
    ranking = PlayerRanking.create!(
      player: create_player, region: @region, season: @season,
      discipline: disciplines(:carom_3band)
    )
    assert_equal @region.id, ranking.versions.last.region_id

    ranking.update!(rank: 3)
    assert_equal @region.id, ranking.versions.last.region_id

    ranking.destroy!
    destroy_version = PaperTrail::Version.where(
      item_type: "PlayerRanking", item_id: ranking.id, event: "destroy"
    ).last
    assert_equal @region.id, destroy_version.region_id, "auch beim Loeschen"
  end

  test "47-02 AC-4 TournamentCc wird ueber branch_cc -> region_cc -> region getaggt" do
    region_cc = RegionCc.create!(region: @region, name: "ZZ47 RegionCc", cc_id: 947_001)
    branch_cc = BranchCc.create!(region_cc: region_cc, name: "ZZ47 BranchCc", cc_id: 947_002,
      discipline: disciplines(:carom_3band))
    tcc = TournamentCc.create!(branch_cc: branch_cc, name: "ZZ47 TurnierCc", cc_id: 947_003)

    assert_equal @region.id, tcc.find_associated_region_id
    assert_equal @region.id, tcc.versions.last.region_id
  end

  test "47-02 AC-4 TournamentCc ohne Kette bleibt ungetaggt, ohne Fehler" do
    tcc = nil
    assert_nothing_raised do
      tcc = TournamentCc.create!(name: "ZZ47 TurnierCc ohne Branch", cc_id: 947_004)
    end
    assert_nil tcc.find_associated_region_id
    assert_nil tcc.versions.last.region_id
  end

  # --- AC-4: nicht-taggbare Modelle brechen nicht -------------------------

  test "AC-4 Modell ohne RegionTaggable schreibt fehlerfrei mit region_id nil" do
    assert_not Video.include?(RegionTaggable),
      "Testvoraussetzung: Video ist (noch) nicht RegionTaggable — Ursache 3, Plan 47-02"

    video = nil
    assert_nothing_raised do
      video = Video.create!(
        external_id: "ZZ47-#{SecureRandom.hex(4)}",
        title: "ZZ47 Testvideo",
        international_source: international_sources(:umb_source)
      )
      video.update!(title: "ZZ47 Testvideo b")
      video.destroy!
    end

    versions = PaperTrail::Version.where(item_type: "Video", item_id: video.id)
    assert_equal 3, versions.count, "create, update und destroy muessen versioniert sein"
    assert versions.all? { |v| v.region_id.nil? },
      "AC-4: ohne RegionTaggable bleibt region_id nil — ohne NoMethodError"
  end

  # --- 47-02 AC-5: echt globale Modelle sind erkennbar --------------------

  test "47-02 AC-5 Video und InternationalSource tragen global_context true" do
    video = Video.create!(
      external_id: "ZZ47g-#{SecureRandom.hex(4)}",
      title: "ZZ47 Globales Video",
      international_source: international_sources(:umb_source)
    )
    version = video.versions.last
    assert_equal true, version.global_context,
      "AC-5: als global gekennzeichnet statt nichtssagender NULL"
    assert_nil version.region_id, "AC-5: global heisst keine Region"

    source = InternationalSource.create!(name: "ZZ47 Quelle", source_type: "umb")
    assert_equal true, source.versions.last.global_context
  end

  test "47-02 AC-5 die Kennzeichnung aendert die Sync-Menge nicht" do
    video = Video.create!(
      external_id: "ZZ47f-#{SecureRandom.hex(4)}",
      title: "ZZ47 Filtertest",
      international_source: international_sources(:umb_source)
    )
    # for_region laesst NULL und global_context TRUE gleichermassen passieren —
    # die Kennzeichnung ist diagnostisch, nicht filterwirksam.
    assert_includes Version.for_region(@region.id).where(item_type: "Video").pluck(:id),
      video.versions.last.id,
      "AC-5: das Video passiert den Regionsfilter weiterhin"
  end

  # --- AC-5: global_context bleibt unveraendert ---------------------------

  test "AC-5 global_context kommt aus der Spalte, nicht aus global_context?" do
    tournament = create_region_tournament(organizer: @dbu)
    tournament.update_columns(global_context: true)

    tournament.update!(title: "ZZ47 DBU-Turnier b")

    version = tournament.versions.last
    assert_equal true, version.global_context,
      "AC-5: der Wert der SPALTE wird uebernommen"
  end

  test "AC-5 global_context? wird zur Schreibzeit nicht aufgerufen" do
    tournament = create_region_tournament(organizer: @dbu)

    called = false
    tournament.define_singleton_method(:global_context?) do
      called = true
      super()
    end
    tournament.update!(title: "ZZ47 DBU-Turnier c")

    assert_not called,
      "AC-5: global_context? ist international-blind (Phase-2-Research 2026-07-12, " \
      "Guard f9bdc53d) und darf nicht zur Schreibzeit-Quelle werden"
  end

  # --- AC-5b: die Ableitung verschlechtert nichts -------------------------

  test "AC-5b gesetzte Spalte gewinnt, wenn die Ableitung nil liefert" do
    tournament = create_region_tournament(organizer: @club, organizer_type: "Club")
    assert_nil tournament.find_associated_region_id,
      "Testvoraussetzung: fuer organizer_type != 'Region' liefert die Ableitung nil"
    tournament.update_columns(region_id: @region.id)
    tournament.reload

    tournament.update!(title: "ZZ47 Club-Turnier b")

    version = tournament.versions.last
    assert_equal @region.id, version.region_id,
      "AC-5b: der Spaltenwert bleibt erhalten — die Ableitung ergaenzt, sie ersetzt nicht"
  end

  private

  def create_region_tournament(organizer: @region, organizer_type: nil, title: nil)
    Tournament.create!(
      title: title || "ZZ47 Testturnier #{SecureRandom.hex(3)}",
      season: @season,
      organizer: organizer,
      date: Date.current
    ).tap do |t|
      t.update_columns(organizer_type: organizer_type) if organizer_type
      t.reload if organizer_type
    end
  end

  def create_league_party
    league = League.create!(
      name: "ZZ47 Liga #{SecureRandom.hex(3)}", shortname: "ZZ47L#{SecureRandom.hex(2)}",
      organizer: @region, season: @season, discipline: disciplines(:carom_3band)
    )
    Party.create!(league: league, day_seqno: 1)
  end

  def create_player
    Player.create!(lastname: "ZZ47", firstname: "Tester #{SecureRandom.hex(3)}")
  end
end
