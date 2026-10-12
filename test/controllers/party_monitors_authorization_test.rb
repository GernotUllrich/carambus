# frozen_string_literal: true

require "test_helper"

# Plan 20-02: Rechte an den schreibenden Aktionen des PartyMonitorsController.
#
# Entstanden als CHARAKTERISIERUNG am unveraenderten Code: jede `authorize`-Zeile stand dort nur
# als auskommentierter Scaffold-Hinweis, und die HTTP-Seite kennt keine globale authenticate_user!.
# Am alten Stand liefen alle 7 Aktionen anonym und als player durch. Erst danach kam das Gate:
#   new/create/edit/update/destroy  -> Admin (Datensatz mit freiem data-Feld)
#   assign_player/remove_player     -> PartyPolicy#operate? (Leiter, Sportwart, Admin)
#
# Gemessen wird am ZUSTAND (PartyMonitor.count, Seeding.count, geaendertes Attribut), nicht am
# HTTP-Status — ein Redirect beweist kein Gate (Lehre aus 17-05/20-01). Nur new/edit schreiben
# nichts; dort ist die ausgelieferte Form (200) der Beleg, dass der Rumpf erreicht wurde.
class PartyMonitorsAuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    @original_api_url = Carambus.config.carambus_api_url
    Carambus.config.carambus_api_url = "http://local.test" # local_server? — sonst greift set_party_monitor
    @party_monitor = party_monitors(:one)
    @party = @party_monitor.party
    @player = users(:one)             # role: player
    @club_admin = users(:club_admin)  # admin? == true
    @spieler = players(:jaspers)
  end

  teardown do
    Carambus.config.carambus_api_url = @original_api_url
  end

  # Einmal anonym, einmal als Konto mit Rolle "player". Flash vor jedem Durchgang leeren (17-05).
  def each_unprivileged
    [["anonym", nil], ["player", @player]].each do |label, user|
      reset!
      sign_in user if user
      yield label
    end
  end

  def assert_denied(label, action)
    assert_response :redirect, "#{action} als #{label}: erwartete Absage (Redirect), bekam #{response.status}"
    assert_not_nil flash[:alert], "#{action} als #{label}: Absage ohne Meldung"
  end

  def team_a_seedings
    Seeding.where(tournament: @party, role: "team_a", player_id: @spieler.id)
  end

  # ---------------------------------------------------------------------------
  # Formulare
  # ---------------------------------------------------------------------------

  test "GET new — anonym und als Spieler kein Anlege-Formular" do
    each_unprivileged do |label|
      get new_party_monitor_path
      assert_denied(label, "GET new")
    end
  end

  test "GET edit — anonym und als Spieler kein Bearbeiten-Formular" do
    each_unprivileged do |label|
      get edit_party_monitor_path(@party_monitor)
      assert_denied(label, "GET edit")
    end
  end

  # ---------------------------------------------------------------------------
  # Anlegen, Aendern, Loeschen
  # ---------------------------------------------------------------------------

  test "POST create — anonym und als Spieler wird kein PartyMonitor angelegt" do
    each_unprivileged do |label|
      assert_no_difference "PartyMonitor.count", "create als #{label} hat einen PartyMonitor angelegt" do
        post party_monitors_path, params: {party_monitor: {party_id: @party.id, state: "seeding_mode"}}
      end
      assert_denied(label, "POST create")
    end
  end

  test "PATCH update — anonym und als Spieler bleibt der Zustand unveraendert" do
    each_unprivileged do |label|
      patch party_monitor_path(@party_monitor), params: {party_monitor: {state: "party_result_checking_mode"}}
      assert_equal "seeding_mode", @party_monitor.reload.state, "update als #{label} hat den Zustand geaendert"
      assert_denied(label, "PATCH update")
    end
  end

  test "DELETE destroy — anonym und als Spieler wird nichts geloescht" do
    each_unprivileged do |label|
      assert_no_difference "PartyMonitor.count", "destroy als #{label} hat geloescht" do
        delete party_monitor_path(@party_monitor)
      end
      assert_denied(label, "DELETE destroy")
    end
  end

  # ---------------------------------------------------------------------------
  # Aufstellung
  # ---------------------------------------------------------------------------

  test "POST assign_player — anonym und als Spieler wird niemand gemeldet" do
    each_unprivileged do |label|
      assert_no_difference -> { team_a_seedings.count }, "assign_player als #{label} hat gemeldet" do
        post assign_player_party_monitor_path(@party_monitor), params: {team: "a", availablePlayerAId: [@spieler.id]}
      end
      assert_denied(label, "POST assign_player")
    end
  end

  test "POST remove_player — anonym und als Spieler wird niemand abgemeldet" do
    Seeding.create!(player_id: @spieler.id, tournament: @party, role: "team_a", position: 1)
    each_unprivileged do |label|
      assert_no_difference -> { team_a_seedings.count }, "remove_player als #{label} hat abgemeldet" do
        post remove_player_party_monitor_path(@party_monitor), params: {team: "a", assignedPlayerAId: [@spieler.id]}
      end
      assert_denied(label, "POST remove_player")
    end
  end

  # ---------------------------------------------------------------------------
  # Mit Recht wie bisher
  # ---------------------------------------------------------------------------

  test "der eingesetzte Begegnungsleiter meldet und meldet ab — verwalten darf er nicht" do
    leiter = users(:two)
    UserParty.create!(user: leiter, party: @party, granted_by: @club_admin)
    sign_in leiter
    assert_difference -> { team_a_seedings.count }, 1 do
      post assign_player_party_monitor_path(@party_monitor), params: {team: "a", availablePlayerAId: [@spieler.id]}
    end
    assert_difference -> { team_a_seedings.count }, -1 do
      post remove_player_party_monitor_path(@party_monitor), params: {team: "a", assignedPlayerAId: [@spieler.id]}
    end
    assert_no_difference "PartyMonitor.count" do
      delete party_monitor_path(@party_monitor)
    end
    assert_denied("Leiter", "DELETE destroy")
  end

  test "ein club_admin meldet und loescht wie bisher" do
    sign_in @club_admin
    assert_difference -> { team_a_seedings.count }, 1 do
      post assign_player_party_monitor_path(@party_monitor), params: {team: "a", availablePlayerAId: [@spieler.id]}
    end
    assert_difference "PartyMonitor.count", -1 do
      delete party_monitor_path(@party_monitor)
    end
  end

  # ---------------------------------------------------------------------------
  # Anzeige bleibt offen
  # ---------------------------------------------------------------------------

  # upload_form ist hier nicht geprueft: die View liest @party, das die Aktion nie setzt — sie
  # liefert auf dem alten Stand fuer jeden 500 (vorbestehend, nicht Gegenstand von 20-02).
  test "Anzeige — index und show bleiben anonym erreichbar" do
    get party_monitors_path
    assert_response :success
    get party_monitor_path(@party_monitor)
    assert_response :success
  end

  # AC-7: die Bedien-Knoepfe folgen PartyPolicy#operate? (sonst disabled, wie der Reset-Knopf).
  test "Knoepfe — anonym deaktiviert, fuer den Leiter bedienbar" do
    get party_monitor_path(@party_monitor)
    assert_select "button[name=assign_a][disabled]"
    assert_select "button[name=prepare_next_round][disabled]"

    UserParty.create!(user: users(:two), party: @party)
    sign_in users(:two)
    get party_monitor_path(@party_monitor)
    assert_select "button[name=assign_a]:not([disabled])"
    assert_select "button[name=prepare_next_round]:not([disabled])"
  end
end
