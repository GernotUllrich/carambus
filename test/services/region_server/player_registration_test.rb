# frozen_string_literal: true

require "test_helper"

# Plan 35-01: Characterization der geteilten Melde-Datenschicht.
#
# Diese Tests halten das VERHALTEN fest, das vor der Extraktion in
# TournamentsController#players_by_club und #add_player_by_dbu lag — inklusive der beiden
# Fallstricke, die im Ursprungscode auskommentiert waren: die Turniersaison (nicht
# Season.current_season) und die fortlaufende Position innerhalb einer Mehrfach-Eingabe.
class RegionServer::PlayerRegistrationTest < ActiveSupport::TestCase
  # Plan 36-02: fuer assert_enqueued_with/-jobs (der Anstoss an die Authority).
  include ActiveJob::TestHelper

  setup do
    @tournament = tournaments(:local)
    @season = @tournament.season
    @club = Club.create!(name: "Testverein 35", shortname: "TV35", region_id: 50_000_001)
    @alpha = Player.create!(lastname: "ALPHA", firstname: "Anna", fl_name: "A. Alpha", dbu_nr: "111111")
    @beta = Player.create!(lastname: "BETA", firstname: "Bert", fl_name: "B. Beta", dbu_nr: "222222")
    [@alpha, @beta].each { |pl| SeasonParticipation.create!(player: pl, club: @club, season: @season) }
  end

  # --- selectable_players -----------------------------------------------------

  test "selectable_players liefert die Vereinsspieler der Turniersaison" do
    rows = RegionServer::PlayerRegistration.selectable_players(tournament: @tournament, club_id: @club.id)

    assert_equal 2, rows.size
    assert_equal [@alpha.id, @beta.id].sort, rows.map { |r| r[:id] }.sort
    assert_equal [111_111, 222_222], rows.map { |r| r[:dbu_nr] }.sort
    assert rows.all? { |r| r[:label].present? }, "label muss gesetzt sein"
  end

  test "selectable_players ohne club_id liefert eine leere Liste" do
    assert_equal [], RegionServer::PlayerRegistration.selectable_players(tournament: @tournament, club_id: nil)
    assert_equal [], RegionServer::PlayerRegistration.selectable_players(tournament: @tournament, club_id: "")
  end

  test "selectable_players laesst bereits gemeldete Spieler weg" do
    @tournament.seedings.create!(player_id: @alpha.id, position: 1)

    rows = RegionServer::PlayerRegistration.selectable_players(tournament: @tournament, club_id: @club.id)

    refute_includes rows.map { |r| r[:id] }, @alpha.id
    assert_equal 1, rows.size
  end

  test "selectable_players sortiert nach label" do
    rows = RegionServer::PlayerRegistration.selectable_players(tournament: @tournament, club_id: @club.id)

    assert_equal rows.map { |r| r[:label] }.sort, rows.map { |r| r[:label] }
  end

  test "selectable_players filtert auf die Turniersaison, nicht auf die laufende" do
    other_season = Season.where.not(id: @season.id).first
    skip "keine zweite Saison im Fixture-Satz" if other_season.nil?

    gamma = Player.create!(lastname: "GAMMA", firstname: "Gerd", fl_name: "G. Gamma", dbu_nr: "333333")
    SeasonParticipation.create!(player: gamma, club: @club, season: other_season)

    rows = RegionServer::PlayerRegistration.selectable_players(tournament: @tournament, club_id: @club.id)

    refute_includes rows.map { |r| r[:id] }, gamma.id,
      "Spieler einer anderen Saison darf nicht angeboten werden"
  end

  # --- register_by_dbu --------------------------------------------------------

  test "register_by_dbu meldet einen Spieler mit state registered" do
    result = register("111111")

    assert_equal 1, result.added.size
    assert_equal @alpha, result.added.first[:player]
    assert_equal 1, result.added.first[:position]

    seeding = @tournament.seedings.find_by(player_id: @alpha.id)
    assert_not_nil seeding
    assert_equal "registered", seeding.state,
      "eine Meldung ist registered — nicht seeded (das waere Teilnehmerlisten-Semantik)"
  end

  test "register_by_dbu vergibt fortlaufende Positionen innerhalb einer Mehrfach-Eingabe" do
    result = register("111111, 222222")

    assert_equal 2, result.added.size
    assert_equal [1, 2], result.added.map { |e| e[:position] }
  end

  test "register_by_dbu meldet Dubletten getrennt zurueck und legt nichts an" do
    @tournament.seedings.create!(player_id: @alpha.id, position: 7)

    assert_no_difference -> { @tournament.seedings.count } do
      result = register("111111")

      assert_empty result.added
      assert_equal 1, result.already_exists.size
      assert_equal 7, result.already_exists.first[:position]
    end
  end

  test "register_by_dbu sammelt unaufloesbare Nummern" do
    result = register("111111, 999999")

    assert_equal 1, result.added.size
    assert_equal ["999999"], result.not_found
  end

  test "register_by_dbu bei leerer Eingabe ist ein no-op" do
    assert_no_difference -> { @tournament.seedings.count } do
      result = register("")

      assert_empty result.added
      assert_empty result.already_exists
      assert_empty result.not_found
    end
  end

  test "register_by_dbu ignoriert Leerraum und leere Segmente" do
    result = register(" 111111 ,, 222222 ,")

    assert_equal 2, result.added.size
    assert_empty result.not_found
  end

  # --- withdraw ---------------------------------------------------------------

  test "withdraw entfernt eine lokale Meldung" do
    seeding = @tournament.seedings.create!(player_id: @alpha.id, position: 1)

    assert_difference -> { @tournament.seedings.count }, -1 do
      assert_equal @alpha, RegionServer::PlayerRegistration.withdraw(tournament: @tournament, seeding_id: seeding.id)
    end
  end

  test "withdraw ruehrt globale Seedings nicht an" do
    global = @tournament.seedings.create!(player_id: @alpha.id, position: 1)
    global.update_column(:id, 4_711) # < MIN_ID = Hoheit der Authority

    assert_no_difference -> { @tournament.seedings.count } do
      assert_nil RegionServer::PlayerRegistration.withdraw(tournament: @tournament, seeding_id: 4_711)
    end
  end

  test "withdraw auf eine fremde seeding_id ist ein no-op" do
    assert_nil RegionServer::PlayerRegistration.withdraw(tournament: @tournament, seeding_id: 999_999_999)
  end

  # --- Plan 36-02: Anstoß an die Authority ------------------------------------
  #
  # LIVE-BEFUND, der diese Tests ausgeloest hat (2026-07-29, read-only auf Prod): auf dem Region
  # Server tbv lagen drei Meldungen, die nie oben ankamen. Der Ingest-Dry-Run auf der Authority
  # meldete `seedings_created=3, players_unresolved=[]` — die Strecke trug vollstaendig, es fehlte
  # nur der Ausloeser. `enqueue_for` wurde ausschliesslich beim FREIGEBEN gerufen.

  test "eine Meldung stoesst den Authority-Ingest an" do
    as_region_server do
      assert_enqueued_with(job: EntryListSyncJob,
        args: [{region_id: regions(:nbv).id, season_id: @tournament.season_id}]) do
        register("111111")
      end
    end
  end

  test "eine Mehrfach-Eingabe stoesst genau einmal an" do
    # Je Nummer anzustossen hiesse, die ganze Region/Saison mehrfach einzulesen.
    as_region_server do
      assert_enqueued_jobs 1, only: EntryListSyncJob do
        register("111111,222222")
      end
    end
  end

  test "eine Eingabe ohne neue Meldung stoesst nichts an" do
    as_region_server do
      register("111111")

      assert_no_enqueued_jobs only: EntryListSyncJob do
        register("111111")      # Dublette
        register("999999")      # unaufloesbar
        register("")            # leer
      end
    end
  end

  test "ein Rueckzug stoesst an" do
    seeding = @tournament.seedings.create!(player_id: @alpha.id, position: 1)

    as_region_server do
      assert_enqueued_with(job: EntryListSyncJob) do
        RegionServer::PlayerRegistration.withdraw(tournament: @tournament, seeding_id: seeding.id)
      end
    end
  end

  test "ein folgenloser Rueckzug stoesst nichts an" do
    global = @tournament.seedings.create!(player_id: @alpha.id, position: 1)
    global.update_column(:id, 4_711) # < MIN_ID = Hoheit der Authority

    as_region_server do
      assert_no_enqueued_jobs only: EntryListSyncJob do
        RegionServer::PlayerRegistration.withdraw(tournament: @tournament, seeding_id: 4_711)
        RegionServer::PlayerRegistration.withdraw(tournament: @tournament, seeding_id: 999_999_999)
      end
    end
  end

  test "auf der Authority wird nichts eingereiht" do
    # carambus_api_url leer => Authority. Sie stoesst sich nicht selbst an.
    @tournament.update_columns(region_id: regions(:nbv).id)

    assert_no_enqueued_jobs only: EntryListSyncJob do
      register("111111")
    end
  end

  test "ein Entwurf stoesst nichts an" do
    as_region_server do
      @tournament.update_column(:data, (@tournament.data || {}).merge("draft" => true))

      assert_no_enqueued_jobs only: EntryListSyncJob do
        register("111111")
      end
    end
  end

  # --- Plan 36-05: Materialisierung vor der ersten Aenderung -------------------
  #
  # WARUM DIESE TESTS EXISTIEREN: `effective_seedings` ist ein Entweder-oder (tournament.rb:609).
  # Solange die Meldeliste global ist (ClubCloud ODER Authority-Sync) und noch kein lokales Seeding
  # existiert, machte die erste Aenderung die gesamte bisherige Liste unsichtbar — der neue Spieler
  # stand allein da. Live gesehen 2026-08-05 an einem CC-losen UND einem CC-Turnier.

  test "Anhaengen an eine globale Meldeliste uebernimmt sie zuerst lokal" do
    global_list_of_three

    register("111111", tournament: @global)

    effective = @global.reload.effective_seedings.order(:position)
    assert_equal 4, effective.count, "die drei Gemeldeten duerfen nicht verschwinden"
    assert effective.all? { |s| s.id >= Seeding::MIN_ID }, "die effektive Liste muss lokal sein"
    assert_equal [1, 2, 3, 4], effective.map(&:position), "die Reihenfolge bleibt, der Neue haengt an"
    assert_equal @alpha.id, effective.last.player_id
  end

  # Betreiber-Entscheidung 2026-08-05 (nach dem Test auf bcw): ein gestrichener Spieler bleibt
  # SICHTBAR, aber gestrichen. Ganz wegzulassen hiesse, dass er nur ueber die Spielereingabe
  # zurueckzuholen waere; als regulaerer Teilnehmer zurueckzukehren waere schlicht falsch.
  test "Uebernahme haelt gestrichene Spieler als no_show fest" do
    global_list_of_three
    @global.seedings.find_by(player_id: @delta.id).update_column(:state, "no_show")

    register("111111", tournament: @global)

    effective = @global.reload.effective_seedings
    assert_includes effective.map(&:player_id), @delta.id, "der gestrichene Spieler bleibt sichtbar"
    assert_equal "no_show", effective.find_by(player_id: @delta.id).state,
      "aber er kehrt nicht als Teilnehmer zurueck"
    assert_equal 3, effective.where.not(state: "no_show").count, "zwei uebernommene plus der neue"
  end

  test "eine bereits lokale Liste wird nicht ein zweites Mal uebernommen" do
    local = @tournament
    local.seedings.create!(player_id: @beta.id, position: 1)

    register("111111")

    assert_equal 2, local.reload.effective_seedings.count, "keine Verdopplung"
  end

  # --- Plan 36-05: set_participation (Teilnehmer-Haken) ------------------------

  test "Anhaken setzt einen gestrichenen Spieler zurueck" do
    seeding = @tournament.seedings.create!(player_id: @alpha.id, position: 1)
    seeding.update_column(:state, "no_show")

    RegionServer::PlayerRegistration.set_participation(
      tournament: @tournament, player: @alpha, participating: true
    )

    assert_equal "registered", seeding.reload.state
  end

  test "Anhaken holt einen gestrichenen Spieler aus der globalen Liste zurueck" do
    global_list_of_three
    @global.seedings.find_by(player_id: @delta.id).update_column(:state, "no_show")

    RegionServer::PlayerRegistration.set_participation(
      tournament: @global, player: @delta, participating: true
    )

    seeding = @global.reload.effective_seedings.find_by(player_id: @delta.id)
    assert_not_nil seeding, "der Spieler muss wieder in der Liste stehen"
    assert seeding.id >= Seeding::MIN_ID, "und zwar als lokales, schreibbares Seeding"
    assert_equal "registered", seeding.state
  end

  # VERHALTENSERHALT (Betreiber 2026-08-05): im all-lokalen Wizard-Fluss funktionieren Loeschen
  # und Wiederhinzufuegen — daran darf sich nichts aendern.
  test "Haken entfernen loescht das lokale Seeding wie bisher" do
    @tournament.seedings.create!(player_id: @alpha.id, position: 1)

    assert_difference("Seeding.count", -1) do
      RegionServer::PlayerRegistration.set_participation(
        tournament: @tournament, player: @alpha, participating: false
      )
    end
  end

  test "Anhaken eines Spielers ohne Seeding legt eines an wie bisher" do
    assert_difference("Seeding.count", 1) do
      RegionServer::PlayerRegistration.set_participation(
        tournament: @tournament, player: @alpha, participating: true
      )
    end
  end

  private

  # Ein GLOBALES Turnier mit GLOBALER Meldeliste — die Ausgangslage auf einem Location Server,
  # gleich ob die Meldung aus der ClubCloud oder per Sync von der Authority kam.
  def global_list_of_three
    @gamma = Player.create!(lastname: "GAMMA", firstname: "Gerd", fl_name: "G. Gamma", dbu_nr: "444444")
    @delta = Player.create!(lastname: "DELTA", firstname: "Dirk", fl_name: "D. Delta", dbu_nr: "555555")
    @global = Tournament.create!(
      id: 23_460, title: "Globales Turnier 36-05", shortname: "GLOB3605",
      season: @season, organizer: regions(:nbv), region_id: regions(:nbv).id,
      date: Time.zone.local(2026, 10, 10, 10, 0)
    )
    [@beta, @gamma, @delta].each_with_index do |player, ix|
      Seeding.create!(id: 23_461 + ix, tournament: @global, player: player, position: ix + 1)
    end
    @global
  end

  # enqueue_for reiht nur auf einem LOKALEN Server ein und nur fuer ein freigegebenes Turnier mit
  # Region und Saison — beides hier herstellen.
  def as_region_server
    original = Carambus.config.carambus_api_url
    Carambus.config.carambus_api_url = "http://local.test"
    @tournament.update_columns(region_id: regions(:nbv).id)
    yield
  ensure
    Carambus.config.carambus_api_url = original
  end

  def register(input, tournament: @tournament)
    RegionServer::PlayerRegistration.register_by_dbu(
      tournament: tournament, dbu_input: input, acting_user: nil
    )
  end
end
