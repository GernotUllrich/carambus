# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

# Plan 20-03: Kandidatenliste aus 19-01 — Rechte an den schreibenden Aktionen der Controller,
# die keine erkennbare Pruefung hatten.
#
# Diese Datei ist zuerst als CHARAKTERISIERUNG entstanden: sie lief am unveraenderten Code und
# belegte, dass anonyme Besucher und Konten mit der Rolle "player" die Schreibaktionen von
# club_locations, discipline_phases, slots und table_monitors ausfuehren und fremde Uploads
# aendern/loeschen konnten. Erst danach kam das Gate.
#
# Gemessen wird am ZUSTAND (count, geaendertes Attribut, aufgerufene Methode), nicht am
# HTTP-Status: ein Redirect beweist kein Gate (Falle aus 17-05). Besonders beim TableMonitor:
# `set_table_monitor` leitet ohne zugeordneten Tisch selbst um — deshalb arbeiten die Tests mit
# table_monitors(:one), dem tables(:one) zugeordnet ist.
#
# Regeln (Betreiber-Freigabe 2026-09-19):
#   R1 Stammdaten (club_locations, discipline_phases, slots) → admin?
#   R2 Uploads aendern/loeschen → Eigentuemer oder admin?
#   R3 TableMonitor CRUD + HTTP set_balls/next_step/evaluate_result → admin?;
#      die Scoreboard-Bedienung (index, show, start_game, print_protocol, toggle_dark_mode) bleibt offen
class CandidateListAuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    @player = users(:player)
    @club_admin = users(:club_admin)
    @system_admin = users(:system_admin)
    @club_location = club_locations(:one)
    @discipline_phase = discipline_phases(:one)
    @slot = slots(:one)
    @table_monitor = table_monitors(:one)
  end

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

  # ---------------------------------------------------------------------------
  # R1: club_locations
  # ---------------------------------------------------------------------------

  test "club_locations — anonym und als Spieler: kein Anlegen, Ändern, Löschen, kein Formular" do
    each_unprivileged do |label|
      assert_no_difference "ClubLocation.count", "create als #{label}" do
        # club_bochum + location one gibt es noch nicht — sonst schlägt die Eindeutigkeit an (422)
        post club_locations_path, params: {club_location: {club_id: clubs(:club_bochum).id,
                                                           location_id: @club_location.location_id, status: "x"}}
      end
      assert_denied(label, "POST create")

      patch club_location_path(@club_location), params: {club_location: {status: "geändert #{label}"}}
      assert_equal "active", @club_location.reload.status, "update als #{label} hat geändert"
      assert_denied(label, "PATCH update")

      assert_no_difference "ClubLocation.count", "destroy als #{label}" do
        delete club_location_path(@club_location)
      end
      assert_denied(label, "DELETE destroy")

      get new_club_location_path
      assert_denied(label, "GET new")
      get edit_club_location_path(@club_location)
      assert_denied(label, "GET edit")
    end
  end

  test "club_locations — ein club_admin ändert wie bisher" do
    sign_in @club_admin
    patch club_location_path(@club_location), params: {club_location: {status: "vom Admin"}}
    assert_equal "vom Admin", @club_location.reload.status
  end

  # ---------------------------------------------------------------------------
  # R1: discipline_phases
  # ---------------------------------------------------------------------------

  test "discipline_phases — anonym und als Spieler: kein Anlegen, Ändern, Löschen, kein Formular" do
    each_unprivileged do |label|
      assert_no_difference "DisciplinePhase.count", "create als #{label}" do
        post discipline_phases_path, params: {discipline_phase: {name: "Eingeschmuggelt #{label}", discipline_id: 1}}
      end
      assert_denied(label, "POST create")

      patch discipline_phase_path(@discipline_phase), params: {discipline_phase: {name: "geändert #{label}"}}
      assert_equal "MyString", @discipline_phase.reload.name, "update als #{label} hat geändert"
      assert_denied(label, "PATCH update")

      assert_no_difference "DisciplinePhase.count", "destroy als #{label}" do
        delete discipline_phase_path(@discipline_phase)
      end
      assert_denied(label, "DELETE destroy")

      get new_discipline_phase_path
      assert_denied(label, "GET new")
      get edit_discipline_phase_path(@discipline_phase)
      assert_denied(label, "GET edit")
    end
  end

  test "discipline_phases — ein club_admin ändert wie bisher" do
    sign_in @club_admin
    patch discipline_phase_path(@discipline_phase), params: {discipline_phase: {name: "vom Admin"}}
    assert_equal "vom Admin", @discipline_phase.reload.name
  end

  # ---------------------------------------------------------------------------
  # R1: slots
  # ---------------------------------------------------------------------------

  test "slots — anonym und als Spieler: kein Anlegen, Ändern, Löschen, kein Formular" do
    before = @slot.dayofweek
    each_unprivileged do |label|
      assert_no_difference "Slot.count", "create als #{label}" do
        post slots_path, params: {slot: {dayofweek: 3, table_id: @slot.table_id}}
      end
      assert_denied(label, "POST create")

      patch slot_path(@slot), params: {slot: {dayofweek: before.to_i + 1}}
      assert_equal before, @slot.reload.dayofweek, "update als #{label} hat geändert"
      assert_denied(label, "PATCH update")

      assert_no_difference "Slot.count", "destroy als #{label}" do
        delete slot_path(@slot)
      end
      assert_denied(label, "DELETE destroy")

      get new_slot_path
      assert_denied(label, "GET new")
      get edit_slot_path(@slot)
      assert_denied(label, "GET edit")
    end
  end

  test "slots — ein club_admin ändert wie bisher" do
    sign_in @club_admin
    patch slot_path(@slot), params: {slot: {dayofweek: @slot.dayofweek.to_i + 1}}
    assert_equal @slot.dayofweek.to_i + 1, @slot.reload.dayofweek
  end

  # ---------------------------------------------------------------------------
  # R2: uploads — Eigentuemer oder Admin
  # ---------------------------------------------------------------------------

  test "uploads — ein fremdes Konto ändert und löscht keinen fremden Upload" do
    upload = Upload.create!(filename: "vom_admin.pdf", user_id: @club_admin.id, position: 1)
    sign_in @player

    patch upload_path(upload), params: {upload: {position: 9}}
    assert_equal 1, upload.reload.position, "update eines fremden Uploads hat geändert"
    assert_denied("player (fremd)", "PATCH update")

    assert_no_difference "Upload.count", "destroy eines fremden Uploads" do
      delete upload_path(upload)
    end
    assert_denied("player (fremd)", "DELETE destroy")

    get edit_upload_path(upload)
    assert_denied("player (fremd)", "GET edit")
  end

  test "uploads — anonym: kein Ändern und Löschen" do
    upload = Upload.create!(filename: "vom_admin.pdf", user_id: @club_admin.id, position: 1)
    patch upload_path(upload), params: {upload: {position: 9}}
    assert_equal 1, upload.reload.position
    assert_no_difference("Upload.count") { delete upload_path(upload) }
  end

  test "uploads — der Eigentümer ändert seinen eigenen Upload" do
    upload = Upload.create!(filename: "meins.pdf", user_id: @player.id, position: 1)
    sign_in @player
    patch upload_path(upload), params: {upload: {position: 9}}
    assert_equal 9, upload.reload.position
  end

  test "uploads — ein Admin ändert einen fremden Upload" do
    upload = Upload.create!(filename: "vom_spieler.pdf", user_id: @player.id, position: 1)
    sign_in @club_admin
    patch upload_path(upload), params: {upload: {position: 9}}
    assert_equal 9, upload.reload.position
  end

  # ---------------------------------------------------------------------------
  # R3: table_monitors — Datensatz-Verwaltung und HTTP-Steueraktionen
  # ---------------------------------------------------------------------------

  test "table_monitors — anonym und als Spieler: kein Ändern, Löschen, kein Formular" do
    assert @table_monitor.table.present?, "Voraussetzung: TableMonitor mit Tisch (sonst leitet set_table_monitor selbst um)"
    each_unprivileged do |label|
      # Gemessen an ip_address: `name` ueberschreibt ein Callback beim Speichern mit dem Tischnamen
      patch table_monitor_path(@table_monitor), params: {ip_address: "10.0.0.#{label.size}"}
      assert_equal "192.168.1.1", @table_monitor.reload.ip_address, "update als #{label} hat geändert"
      assert_denied(label, "PATCH update")

      assert_no_difference "TableMonitor.count", "destroy als #{label}" do
        delete table_monitor_path(@table_monitor)
      end
      assert_denied(label, "DELETE destroy")

      get edit_table_monitor_path(@table_monitor)
      assert_denied(label, "GET edit")
    end
  end

  test "table_monitors — ein club_admin ändert wie bisher" do
    sign_in @club_admin
    patch table_monitor_path(@table_monitor), params: {ip_address: "10.0.0.99"}
    assert_equal "10.0.0.99", @table_monitor.reload.ip_address
  end

  # Spion: die Steueraktionen greifen tief in den Spielzustand; gemessen wird, ob der Rumpf die
  # Modellmethode erreicht — nicht, ob der Spielablauf danach stimmt.
  def with_spy(method)
    calls = []
    spy = TableMonitor.find(@table_monitor.id)
    spy.define_singleton_method(method) { |*args| calls << args }
    TableMonitor.stub(:find_by, spy) { yield calls }
  end

  {set_n_balls: [:set_balls_table_monitor_path, {add_balls: 3}],
   force_next_state: [:next_step_table_monitor_path, {}],
   evaluate_result: [:evaluate_result_table_monitor_path, {}]}.each do |method, (path_helper, params)|
    test "table_monitors — #{path_helper}: anonym und als Spieler erreicht der Aufruf #{method} nicht" do
      each_unprivileged do |label|
        with_spy(method) do |calls|
          post send(path_helper, @table_monitor), params: params
          assert_empty calls, "#{path_helper} als #{label} hat #{method} erreicht"
        end
      end
    end

    test "table_monitors — #{path_helper}: ein club_admin erreicht #{method}" do
      sign_in @club_admin
      with_spy(method) do |calls|
        begin
          post send(path_helper, @table_monitor), params: params
        rescue
          nil # Weiterleitung danach braucht Turnier/Location — hier nicht Gegenstand
        end
        assert_equal 1, calls.size, "#{path_helper} als Admin hat #{method} nicht erreicht"
      end
    end
  end

  test "table_monitors — Scoreboard-Aktionen bleiben anonym offen" do
    denied = I18n.t("errors.admin_required", default: "__kein_key__")
    get table_monitors_path
    assert_not_equal denied, flash[:alert], "index abgewiesen"
    get table_monitor_path(@table_monitor)
    assert_not_equal denied, flash[:alert], "show abgewiesen"
    get toggle_dark_mode_table_monitor_path(@table_monitor)
    assert_not_equal denied, flash[:alert], "toggle_dark_mode abgewiesen"
    get print_protocol_table_monitor_path(@table_monitor)
    assert_not_equal denied, flash[:alert], "print_protocol abgewiesen"
  end

  # ---------------------------------------------------------------------------
  # AC-5: Knoepfe folgen dem Recht. `custom_link_to` reicht `disabled:` nur als Attribut an ein
  # <a> weiter — ein Link bleibt damit klickbar. Deshalb werden die Knoepfe ohne Recht
  # ausgeblendet, und geprueft wird, dass der Link fehlt.
  # ---------------------------------------------------------------------------

  test "Knöpfe — ohne Recht keine New-/Edit-Links, als Admin vorhanden" do
    pages = {
      club_locations_path => new_club_location_path, club_location_path(@club_location) => edit_club_location_path(@club_location),
      discipline_phases_path => new_discipline_phase_path, discipline_phase_path(@discipline_phase) => edit_discipline_phase_path(@discipline_phase),
      slots_path => new_slot_path, slot_path(@slot) => edit_slot_path(@slot)
    }
    each_unprivileged do |label|
      pages.each do |page, link|
        get page
        assert_response :success
        assert_select "a[href='#{link}']", {count: 0}, "#{page} als #{label} zeigt #{link}"
      end
    end
    reset!
    sign_in @club_admin
    pages.each do |page, link|
      get page
      assert_select "a[href='#{link}']", {minimum: 1}, "#{page} als Admin ohne #{link}"
    end
  end

  test "Knöpfe — Upload-Edit nur für Eigentümer und Admin" do
    upload = Upload.create!(filename: "meins.pdf", user_id: @player.id, position: 1)
    [[users(:one), 0], [@player, 1], [@club_admin, 1]].each do |user, expected|
      reset!
      sign_in user
      get upload_path(upload)
      assert_select "a[href='#{edit_upload_path(upload)}']", {count: expected}, "Upload-Edit-Link für #{user.email}"
    end
  end

  # ---------------------------------------------------------------------------
  # Geschuetzte Kandidaten: admin/* ueber Admin::ApplicationController#authenticate_admin
  # ---------------------------------------------------------------------------

  %w[settings shots stream_configurations tags training_concepts training_examples training_sources].each do |res|
    test "admin/#{res} — ein club_admin (kein system_admin) wird abgewiesen" do
      sign_in @club_admin
      patch "/admin/#{res}/1"
      assert_redirected_to root_path
      assert_match(/System-Admin/, flash[:alert].to_s)
    end
  end
end
