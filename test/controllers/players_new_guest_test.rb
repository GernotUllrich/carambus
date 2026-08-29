# frozen_string_literal: true

require "test_helper"

# Milestone v0.3 Plan 02-04 — Spieleranlage am Tisch, Unterscheidung passiv/Gast
# (PlayersController#create mit params[:from] == "new_guest").
#
# ⚠️ Fuer diesen Controller-Pfad gab es bis 02-04 KEINEN Test. Das ist der erste.
#
# Der fachliche Kern: `Player.remove_inactive_guests` (player.rb:763) loescht
# SeasonParticipations im Status "guest" nach zwei Wochen ohne Spiel — und mit dem
# Player verschwindet der Spielerbezug seiner Trainingsspiele
# (`has_many :game_participations, dependent: :nullify`). Ein passives Vereinsmitglied,
# das faelschlich als Gast angelegt wurde, ist damit nach zwei Wochen weg. Genau das
# verhindert die Wahl im Dialog.
#
# ⚠️ `status` ist ein FREIES String-Feld ohne Modell-Validierung. Die Whitelist im
# Controller ist die einzige Schranke — deshalb pruefen C1/C2 sie ausdruecklich.
class PlayersNewGuestTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin)
    @club = clubs(:bcw)
    @location = locations(:one)
    @season = Season.current_season
    @created_ids = []
  end

  teardown do
    SeasonParticipation.where(player_id: @created_ids).destroy_all
    Player.where(id: @created_ids).destroy_all
  end

  # Legt einen Spieler ueber den Tisch-Dialog an und gibt seine SeasonParticipation zurueck.
  def create_at_table(status: nil, lastname: "Neuling")
    params = {
      player: {firstname: "Test", lastname: lastname},
      club_id: @club.id, location_id: @location.id, season_id: @season.id,
      from: "new_guest"
    }
    params[:participation_status] = status unless status.nil?

    assert_difference "Player.count", 1 do
      post players_path, params: params
    end
    player = Player.order(:id).last
    @created_ids << player.id
    SeasonParticipation.find_by(player_id: player.id, season_id: @season.id)
  end

  # ---------------------------------------------------------------------------
  # A. Die beiden erlaubten Wege (AC-2, AC-3)
  # ---------------------------------------------------------------------------

  test "A1: Wahl 'guest' erzeugt eine Gast-Teilnahme" do
    sp = create_at_table(status: "guest")

    assert_not_nil sp, "es muss eine SeasonParticipation entstehen"
    assert_equal "guest", sp.status
    assert_equal @club.id, sp.club_id
  end

  test "A2: Wahl 'passive' erzeugt eine passive Teilnahme" do
    sp = create_at_table(status: "passive", lastname: "Passivo")

    assert_not_nil sp
    assert_equal "passive", sp.status,
      "genau das ist der Zweck dieses Plans — vorher war der Status hart 'guest'"
  end

  # ---------------------------------------------------------------------------
  # B. Die fachliche Folge: wer ueberlebt den Cron? (AC-2, AC-3)
  # ---------------------------------------------------------------------------

  test "B1: ein passives Mitglied ueberlebt remove_inactive_guests" do
    sp = create_at_table(status: "passive", lastname: "Bleibend")
    player_id = sp.player_id
    ClubLocation.find_or_create_by!(club_id: @club.id, location_id: @location.id) do |cl|
      cl.status = "active"
    end
    @location.reload

    Player.remove_inactive_guests(@location)

    assert Player.exists?(player_id),
      "ein passives Vereinsmitglied darf der Gast-Cron nie abraeumen"
  end

  test "B2: ein Gast ohne Spiel wird von remove_inactive_guests entfernt" do
    sp = create_at_table(status: "guest", lastname: "Fluechtig")
    player_id = sp.player_id
    ClubLocation.find_or_create_by!(club_id: @club.id, location_id: @location.id) do |cl|
      cl.status = "active"
    end
    @location.reload

    Player.remove_inactive_guests(@location)

    assert_not Player.exists?(player_id),
      "Gaeste ohne Spiel raeumt der Cron ab — genau der Unterschied, um den es geht"
    @created_ids.delete(player_id)
  end

  # ---------------------------------------------------------------------------
  # C. Die Whitelist (AC-4)
  # ---------------------------------------------------------------------------

  test "C1: ein unbekannter Statuswert faellt auf guest zurueck" do
    sp = create_at_table(status: "voellig_ausgedacht", lastname: "Unbekannt")

    assert_equal "guest", sp.status
  end

  test "C2: 'active' ist ueber das Formular NICHT erreichbar" do
    sp = create_at_table(status: "active", lastname: "Moechtegern")

    assert_equal "guest", sp.status,
      "active ist Turnier-Spielberechtigung und darf am Tisch nicht setzbar sein"
    assert_not_equal "active", sp.status
  end

  test "C3: ohne Statusparameter bleibt es bei guest" do
    sp = create_at_table(lastname: "Ohneangabe")

    assert_equal "guest", sp.status,
      "Rueckwaertskompatibel: vor 02-04 gab es den Parameter nicht"
  end

  test "C4: die Whitelist enthaelt genau zwei Werte" do
    assert_equal %w[guest passive], PlayersController::ALLOWED_PARTICIPATION_STATUS
    assert_equal "guest", PlayersController::DEFAULT_PARTICIPATION_STATUS
  end

  # ---------------------------------------------------------------------------
  # D. Bestandsverhalten (AC-6)
  # ---------------------------------------------------------------------------

  test "D1: nach dem Anlegen am Tisch fuehrt der Redirect zurueck" do
    create_at_table(status: "passive", lastname: "Rueckkehr")
    assert_response :redirect
  end

  test "D2: ohne from-Parameter entsteht keine SeasonParticipation" do
    assert_difference "Player.count", 1 do
      assert_no_difference "SeasonParticipation.count" do
        post players_path, params: {
          player: {firstname: "Test", lastname: "Regulaer"},
          club_id: @club.id, season_id: @season.id
        }
      end
    end
    @created_ids << Player.order(:id).last.id
  end
end
