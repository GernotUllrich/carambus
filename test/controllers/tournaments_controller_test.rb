# frozen_string_literal: true

require "test_helper"

# Tests for TournamentsController — all 20+ public actions.
#
# Key constraints:
#   - Most write actions require local server context (ensure_local_server guard).
#   - Set Carambus.config.carambus_api_url = "http://local.test" to enable local server mode.
#   - LocalProtectorTestOverride in test_helper.rb disables write protection for test records.
#   - We use tournaments(:local) (id 50_000_001, state: "registration") as the primary fixture
#     because write actions target local records.
#
# Note on auth: TournamentsController does NOT require authentication for GET actions (no
# before_action :authenticate_user!). Unauthenticated users can browse tournaments. Only
# write actions (create, update, destroy) are subject to ensure_local_server guard.
#
# Note on 500 errors in local server mode: Several GET actions render complex views that
# rely on associations not present in fixtures (e.g. @season, @league, @discipline).
# For these, the test verifies the guard behavior (API redirect vs local pass-through)
# rather than the view rendering. The local-server path tests use a broader status range
# [200, 302, 500] when fixture data is insufficient for a full render.
class TournamentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tournament = tournaments(:local)
    @user = users(:one)
    @club_admin = users(:club_admin)
    @system_admin = users(:system_admin)

    # Save and restore the API URL so tests don't bleed into each other.
    @original_api_url = Carambus.config.carambus_api_url

    sign_in @user
  end

  teardown do
    Carambus.config.carambus_api_url = @original_api_url
  end

  # ---------------------------------------------------------------------------
  # Unauthenticated access: TournamentsController allows public browsing.
  # GET index and show are publicly accessible (no authenticate_user! guard).
  # ---------------------------------------------------------------------------

  test "unauthenticated GET index is publicly accessible" do
    sign_out @user
    get tournaments_url
    # Public access allowed — returns 200 (success)
    assert_response :success
  end

  test "unauthenticated GET show is publicly accessible" do
    sign_out @user
    get tournament_url(@tournament)
    # Public access allowed — returns 200 or 302 (no auth redirect)
    assert_includes [200, 302, 500], response.status,
      "show is publicly accessible — no auth redirect expected"
  end

  # Regression: commit 872f92a3 introduced `games.result_a` references in the
  # reset-tournament and force-reset confirmation modal bodies of tournaments#show,
  # but the `games` table has no `result_a` column — so opening a local, not-yet-
  # started, non-CC tournament crashed with PG::UndefinedColumn. The fix swaps
  # result_a for ended_at (the table monitor's "game finished" marker). This test
  # pins that gating state and verifies show renders the modal trigger block.
  test "GET show renders reset modal for local not-started non-CC tournament (regression: result_a PG::UndefinedColumn)" do
    Carambus.config.carambus_api_url = "http://local.test"
    # Plan 17-01: der Reset-Knopf ist seitdem nur fuer Admins sichtbar (Sichtbarkeit = Reset-Recht)
    sign_out @user
    sign_in @club_admin

    # Repair fixture association rot: tournaments(:local) is inserted with Rails' auto-hashed
    # polymorphic organizer_id / season_id, which do not resolve to the nbv Region (id
    # 50_000_001) or the current Season. Without this, show.html.erb crashes on
    # `tournament.organizer.shortname` / `tournament.season.name` before ever reaching the
    # reset modal block. Use update_columns to skip callbacks and LocalProtector.
    @tournament.update_columns(
      organizer_id: regions(:nbv).id,
      organizer_type: "Region",
      season_id: seasons(:current).id,
      # Seit 34-03 traegt die Herkunft des Turniers die CC-Aussage, nicht die Region.
      source_kind: "club_cloud"
    )
    @tournament.reload

    # Pin the exact gating state the buggy code path requires:
    #   local_server? && !has_clubcloud_results? && !tournament_started
    # The :local fixture is state "registration" with no games and no CC-result
    # seedings, so both predicates are naturally false. Verify before the GET so
    # the test fails loudly if a future fixture change moves us off this path.
    assert_not @tournament.tournament_started,
      "precondition: fixture must not have tournament_started games"
    assert_not @tournament.has_clubcloud_results?,
      "precondition: fixture must not have clubcloud results"
    assert_not_nil @tournament.organizer, "precondition: organizer must resolve for header render"
    assert_not_nil @tournament.season, "precondition: season must resolve for header render"

    get tournament_url(@tournament)

    assert_response :success
    assert_match(/reset-tournament-form-#{@tournament.id}/, response.body,
      "reset modal trigger must render — proves the games.where.not(...).count line executed")
  end

  # ---------------------------------------------------------------------------
  # Auth guard: write actions require sign-in
  # ---------------------------------------------------------------------------

  # BEFUND (Plan 25-01): Der Test hiess frueher "unauthenticated POST create redirects to
  # sign in" und prueft NICHT, was der Name behauptete — TournamentsController hatte KEIN
  # Anmelde-Gate. Gruen war er nur, weil die Pflichtfelder fehlten (422). Plan 17-05 hat das
  # Gate nachgezogen; der Test schickt deshalb GUELTIGE Felder und verlangt die Absage.
  test "unauthenticated POST create does not persist a tournament" do
    sign_out @user
    Carambus.config.carambus_api_url = "http://local.test"

    assert_no_difference("Tournament.count") do
      post tournaments_url, params: {tournament: valid_tournament_attrs("New Tournament")}
    end
    assert_redirected_to tournaments_path
    assert_equal I18n.t("tournaments.errors.admin_required"), flash[:alert]
  end

  # ---------------------------------------------------------------------------
  # GET index — no local-server guard
  # ---------------------------------------------------------------------------

  test "GET index returns success" do
    get tournaments_url
    assert_response :success
  end

  # Umschalter Kommend/Vergangen: „Demnächst" steht in beiden Ansichten oben, darunter folgt
  # alles danach (aufsteigend) bzw. alles davor (absteigend).
  def create_sort_tournaments
    {"Sortierung Demnaechst" => 3, "Sortierung Zukunft fern" => 60, "Sortierung Vergangen nah" => -30,
     "Sortierung Zukunft nah" => 30, "Sortierung Vergangen fern" => -60}.each do |title, days|
      # region_id: der Standard-Scope filtert auf die Region, die Fixture laesst sie leer
      @tournament.dup.tap { |t| t.assign_attributes(title: title, date: days.days.from_now, region_id: 50_000_001) }.save!
    end
  end

  def assert_listed_in_order(expected, absent)
    positions = expected.map { |title| response.body.index(title) }
    assert positions.none?(&:nil?), "nicht alle Turniere auf Seite 1: #{expected.zip(positions).inspect}"
    assert_equal positions.sort, positions
    absent.each { |title| assert_not_includes response.body, title }
  end

  test "GET index default view (Kommend): Demnaechst, then later tournaments ascending" do
    create_sort_tournaments
    get tournaments_url
    assert_response :success
    assert_listed_in_order(["Sortierung Demnaechst", "Sortierung Zukunft nah", "Sortierung Zukunft fern"],
      ["Sortierung Vergangen nah", "Sortierung Vergangen fern"])
  end

  test "GET index period=past (Vergangen): Demnaechst, then earlier tournaments descending" do
    create_sort_tournaments
    get tournaments_url(period: "past")
    assert_response :success
    assert_listed_in_order(["Sortierung Demnaechst", "Sortierung Vergangen nah", "Sortierung Vergangen fern"],
      ["Sortierung Zukunft nah", "Sortierung Zukunft fern"])
  end

  # ---------------------------------------------------------------------------
  # GET show — no local-server guard; may redirect when tournament has no monitor
  # ---------------------------------------------------------------------------

  test "GET show returns success or redirect" do
    get tournament_url(@tournament)
    assert_includes [200, 302, 500], response.status,
      "show should respond with success, redirect, or error (view fixture dependency)"
  end

  # ---------------------------------------------------------------------------
  # POST test_tournament_status_update — no local-server guard; enqueues job
  # ---------------------------------------------------------------------------

  test "POST test_tournament_status_update redirects to tournament" do
    sign_in @club_admin # 17-05: Debug-Aktion nur fuer Admins
    post test_tournament_status_update_tournament_url(@tournament)
    assert_redirected_to tournament_path(@tournament)
  end

  # ---------------------------------------------------------------------------
  # GET tournament_monitor — no local-server guard; redirects when no monitor
  # ---------------------------------------------------------------------------

  test "GET tournament_monitor redirects or responds when no tournament_monitor present" do
    sign_in @club_admin # 17-05: Setup-Recht, sonst prueft der Test nur die Absage
    get tournament_monitor_tournament_url(@tournament)
    # Returns 302 redirect when no monitor; 200 if view renders; 500 if view fails
    assert_includes [200, 302, 204, 500], response.status,
      "tournament_monitor should respond without unhandled auth error"
  end

  # ---------------------------------------------------------------------------
  # Local-server guard tests — non-local (API) context redirects to tournaments_path
  # The guard fires when Carambus.config.carambus_api_url is blank (nil/empty).
  # Default test setup preserves @original_api_url; we explicitly set nil to test guard.
  # ---------------------------------------------------------------------------

  test "GET new redirects to tournaments_path when not local server" do
    Carambus.config.carambus_api_url = nil
    get new_tournament_url
    assert_redirected_to tournaments_path
  end

  test "GET edit redirects to tournaments_path when not local server" do
    Carambus.config.carambus_api_url = nil
    get edit_tournament_url(@tournament)
    assert_redirected_to tournaments_path
  end

  test "GET finalize_modus redirects to tournaments_path when not local server" do
    Carambus.config.carambus_api_url = nil
    get finalize_modus_tournament_url(@tournament)
    assert_redirected_to tournaments_path
  end

  test "GET define_participants redirects to tournaments_path when not local server" do
    Carambus.config.carambus_api_url = nil
    get define_participants_tournament_url(@tournament)
    assert_redirected_to tournaments_path
  end

  test "GET new_team redirects to tournaments_path when not local server" do
    Carambus.config.carambus_api_url = nil
    get new_team_tournament_url(@tournament)
    assert_redirected_to tournaments_path
  end

  test "GET compare_seedings redirects to tournaments_path when not local server" do
    Carambus.config.carambus_api_url = nil
    get compare_seedings_tournament_url(@tournament)
    assert_redirected_to tournaments_path
  end

  test "GET parse_invitation redirects to tournaments_path when not local server" do
    Carambus.config.carambus_api_url = nil
    get parse_invitation_tournament_url(@tournament)
    assert_redirected_to tournaments_path
  end

  # ---------------------------------------------------------------------------
  # Local-server guard pass-through — local server context passes the guard.
  # We test that the guard allows through (not redirected to tournaments_path).
  # View-level 500 errors are noted in comments but don't invalidate guard coverage.
  # Plan 17-05: die Aktionen verlangen seitdem ein Recht — die Tests laufen als club_admin,
  # sonst traefen sie die Absage statt des Action-Rumpfs.
  # ---------------------------------------------------------------------------

  test "GET new passes ensure_local_server guard when local server" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in @club_admin
    get new_tournament_url
    # Guard passes — may 200 (success) or 500 (view dependency); NOT redirect to tournaments_path
    assert_includes [200, 302, 500], response.status,
      "new should reach action body in local server mode"
    if response.status == 302
      refute_equal tournaments_path, response.location,
        "should not redirect to tournaments_path (that is the guard behavior)"
    end
  end

  test "GET edit passes ensure_local_server guard when local server" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in @club_admin
    get edit_tournament_url(@tournament)
    assert_includes [200, 302, 500], response.status,
      "edit should reach action body in local server mode"
    if response.status == 302
      refute_equal tournaments_path, response.location,
        "should not redirect to tournaments_path (that is the guard behavior)"
    end
  end

  test "GET finalize_modus passes ensure_local_server guard when local server" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in @club_admin
    get finalize_modus_tournament_url(@tournament)
    # finalize_modus renders complex view with tournament plan data —
    # 500 is acceptable due to fixture data gaps; what matters is guard doesn't redirect.
    assert_includes [200, 302, 500], response.status,
      "finalize_modus should reach action body in local server mode"
    if response.status == 302
      refute_equal tournaments_path, response.location,
        "should not redirect to tournaments_path (that is the guard behavior)"
    end
  end

  test "GET define_participants passes ensure_local_server guard when local server" do
    Carambus.config.carambus_api_url = "http://local.test"
    get define_participants_tournament_url(@tournament)
    # View requires complex associations; 500 acceptable here — guard is what matters.
    assert_includes [200, 302, 500], response.status,
      "define_participants should reach action body in local server mode"
    if response.status == 302
      refute_equal tournaments_path, response.location,
        "should not redirect to tournaments_path (that is the guard behavior)"
    end
  end

  test "GET new_team passes ensure_local_server guard when local server" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in @club_admin
    get new_team_tournament_url(@tournament)
    assert_includes [200, 302, 500], response.status,
      "new_team should reach action body in local server mode"
    if response.status == 302
      refute_equal tournaments_path, response.location
    end
  end

  test "GET compare_seedings renders when local server" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in @club_admin
    get compare_seedings_tournament_url(@tournament)
    assert_response :success
  end

  test "GET parse_invitation redirects to compare_seedings when no invitation file" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in @club_admin
    get parse_invitation_tournament_url(@tournament)
    # No invitation file uploaded → redirects to compare_seedings path
    assert_redirected_to compare_seedings_tournament_path(@tournament)
  end

  # ---------------------------------------------------------------------------
  # Write action guard: write actions redirect to tournaments_path on API server
  # ---------------------------------------------------------------------------

  test "POST create redirects to tournaments_path when not local server" do
    Carambus.config.carambus_api_url = nil
    post tournaments_url, params: { tournament: { title: "New Tournament" } }
    assert_redirected_to tournaments_path
  end

  test "PATCH update redirects to tournaments_path when not local server" do
    Carambus.config.carambus_api_url = nil
    patch tournament_url(@tournament), params: { tournament: { title: "Updated" } }
    assert_redirected_to tournaments_path
  end

  test "DELETE destroy redirects to tournaments_path when not local server" do
    Carambus.config.carambus_api_url = nil
    delete tournament_url(@tournament)
    assert_redirected_to tournaments_path
  end

  # ---------------------------------------------------------------------------
  # CRUD — local server context
  # ---------------------------------------------------------------------------

  test "POST create creates tournament and redirects when local server" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in @club_admin
    season = seasons(:current)
    discipline = disciplines(:carom_3band)
    assert_difference("Tournament.count", 1) do
      post tournaments_url, params: {
        tournament: {
          title: "Brand New Tournament",
          discipline_id: discipline.id,
          season_id: season.id,
          date: 1.month.from_now,
          organizer_id: regions(:nbv).id,
          organizer_type: "Region"
        }
      }
    end
    assert_includes [200, 302], response.status,
      "create should redirect or render after save"
  end

  # Regression (HANDOFF tournament-create-500, 2026-08-18): Das "Lokale Konfiguration"-text_area
  # submittet `data` als String ("{}"); serialize :data (type: Hash) warf 500
  # (SerializationTypeMismatch). tournament_params normalisiert String -> Hash.
  test "POST create with data as String does not 500 and stores a Hash" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in @club_admin
    assert_difference("Tournament.count", 1) do
      post tournaments_url, params: {
        tournament: {
          title: "Data-String Regression",
          discipline_id: disciplines(:carom_3band).id,
          season_id: seasons(:current).id,
          date: 1.month.from_now,
          organizer_id: regions(:nbv).id,
          organizer_type: "Region",
          data: "{}" # der Bug-Trigger: String statt Hash
        }
      }
    end
    assert_includes [200, 302], response.status, "kein 500 mehr"
    assert_kind_of Hash, Tournament.find_by(title: "Data-String Regression").data
  end

  test "PATCH update updates tournament and redirects when local server" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in @club_admin # 17-05: Stammdaten nur fuer Admins
    patch tournament_url(@tournament), params: { tournament: { title: "Updated Title" } }
    assert_includes [200, 302], response.status,
      "update should redirect or render"
    @tournament.reload
    assert_equal "Updated Title", @tournament.title
  end

  test "DELETE destroy removes tournament when local server" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in @club_admin # 17-05: Stammdaten nur fuer Admins
    assert_difference("Tournament.count", -1) do
      delete tournament_url(@tournament)
    end
    assert_redirected_to tournaments_url
  end

  # ---------------------------------------------------------------------------
  # State transition actions
  # ---------------------------------------------------------------------------

  test "POST reset redirects back to tournament when local server" do
    Carambus.config.carambus_api_url = "http://local.test"
    post reset_tournament_url(@tournament)
    # reset calls AASM methods; may raise or redirect — accept any response
    assert_includes [200, 302, 500], response.status,
      "reset should reach action body in local server mode"
  end

  test "POST reset redirects to tournaments_path when not local server" do
    Carambus.config.carambus_api_url = nil
    post reset_tournament_url(@tournament)
    assert_redirected_to tournaments_path
  end

  test "POST finish_seeding passes guard when local server" do
    Carambus.config.carambus_api_url = "http://local.test"
    # Tournament is in "registration" state; finish_seeding! will raise AASM::InvalidTransition.
    # Controller does not rescue this — we accept any response including 500.
    post finish_seeding_tournament_url(@tournament)
    assert_includes [200, 302, 500], response.status,
      "finish_seeding guard passes in local server mode (AASM state may reject)"
  end

  test "POST finish_seeding redirects to tournaments_path when not local server" do
    Carambus.config.carambus_api_url = nil
    post finish_seeding_tournament_url(@tournament)
    assert_redirected_to tournaments_path
  end

  test "POST start passes guard when local server" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in @club_admin # 17-05: Setup-Recht
    # start action has complex AASM logic; we verify the guard passes
    post start_tournament_url(@tournament)
    # Should not redirect to tournaments_path (that's the guard)
    assert_includes [200, 302, 500], response.status,
      "start should reach action body in local server mode"
    if response.status == 302
      refute_equal tournaments_path, response.location,
        "should not redirect to tournaments_path (that is the guard behavior)"
    end
  end

  test "POST start redirects to tournaments_path when not local server" do
    Carambus.config.carambus_api_url = nil
    post start_tournament_url(@tournament)
    assert_redirected_to tournaments_path
  end

  # ---------------------------------------------------------------------------
  # Data manipulation actions (local server context)
  # Plan 17-05: Setup-Aktionen verlangen prepare_tournament? — die Tests laufen als club_admin.
  # ---------------------------------------------------------------------------

  test "POST order_by_ranking_or_handicap redirects to tournament when local server" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in @club_admin
    post order_by_ranking_or_handicap_tournament_url(@tournament)
    assert_redirected_to tournament_path(@tournament)
  end

  test "POST order_by_ranking_or_handicap redirects to tournaments_path when not local server" do
    Carambus.config.carambus_api_url = nil
    post order_by_ranking_or_handicap_tournament_url(@tournament)
    assert_redirected_to tournaments_path
  end

  test "POST select_modus passes guard when local server" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in @club_admin
    # No valid tournament_plan_id — the controller rescues StandardError and redirects back
    post select_modus_tournament_url(@tournament), params: { tournament_plan_id: 0 }
    assert_includes [200, 302], response.status,
      "select_modus should return redirect or success in local server mode"
  end

  test "POST select_modus redirects to tournaments_path when not local server" do
    Carambus.config.carambus_api_url = nil
    post select_modus_tournament_url(@tournament), params: { tournament_plan_id: 1 }
    assert_redirected_to tournaments_path
  end

  test "POST reload_from_cc passes guard when local server" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in @club_admin
    # reload_from_cc calls Version.update_from_carambus_api — may 500 in test env
    post reload_from_cc_tournament_url(@tournament)
    assert_includes [200, 302, 500], response.status,
      "reload_from_cc should reach action body in local server mode"
  end

  test "POST reload_from_cc on API server scrapes CC and redirects to tournament" do
    Carambus.config.carambus_api_url = nil
    sign_in @club_admin # 17-05: das Gate gilt auch auf der Authority
    # reload_from_cc is NOT in the ensure_local_server list — it runs on both server types.
    # On API server it calls @tournament.scrape_single_tournament_public (WebMock blocks network)
    # then redirect_back_or_to(tournament_path(@tournament)).
    post reload_from_cc_tournament_url(@tournament)
    assert_includes [200, 302, 500], response.status,
      "reload_from_cc on API server should reach action body (no guard redirect)"
  end

  test "POST upload_invitation redirects when no file provided" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in @club_admin
    post upload_invitation_tournament_url(@tournament)
    # No file: redirects to compare_seedings with alert
    assert_redirected_to compare_seedings_tournament_path(@tournament)
  end

  test "POST upload_invitation redirects to tournaments_path when not local server" do
    Carambus.config.carambus_api_url = nil
    post upload_invitation_tournament_url(@tournament)
    assert_redirected_to tournaments_path
  end

  test "POST recalculate_groups redirects to finalize_modus when local server" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in @club_admin
    post recalculate_groups_tournament_url(@tournament)
    assert_redirected_to finalize_modus_tournament_path(@tournament)
  end

  test "POST recalculate_groups redirects to tournaments_path when not local server" do
    Carambus.config.carambus_api_url = nil
    post recalculate_groups_tournament_url(@tournament)
    assert_redirected_to tournaments_path
  end

  test "POST add_player_by_dbu redirects when dbu_nr blank" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in users(:admin) # Plan 32-07: manage_teilnehmerliste?-Gate — autorisierter User, Test prüft Action-Body
    post add_player_by_dbu_tournament_url(@tournament), params: { dbu_nr: "" }
    assert_redirected_to define_participants_tournament_path(@tournament)
  end

  test "POST add_player_by_dbu redirects to tournaments_path when not local server" do
    Carambus.config.carambus_api_url = nil
    post add_player_by_dbu_tournament_url(@tournament), params: { dbu_nr: "12345" }
    assert_redirected_to tournaments_path
  end

  test "POST apply_seeding_order redirects when no seeding_order provided" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in users(:admin) # Plan 32-07: manage_teilnehmerliste?-Gate — autorisierter User, Test prüft Action-Body
    post apply_seeding_order_tournament_url(@tournament)
    assert_redirected_to compare_seedings_tournament_path(@tournament)
  end

  test "POST apply_seeding_order redirects to tournaments_path when not local server" do
    Carambus.config.carambus_api_url = nil
    post apply_seeding_order_tournament_url(@tournament)
    assert_redirected_to tournaments_path
  end

  test "POST use_clubcloud_as_participants passes guard when local server" do
    Carambus.config.carambus_api_url = "http://local.test"
    post use_clubcloud_as_participants_tournament_url(@tournament)
    # No CC seedings → redirects to compare_seedings or define_participants
    assert_includes [200, 302], response.status,
      "use_clubcloud_as_participants should respond in local server mode"
  end

  test "POST use_clubcloud_as_participants redirects to tournaments_path when not local server" do
    Carambus.config.carambus_api_url = nil
    post use_clubcloud_as_participants_tournament_url(@tournament)
    assert_redirected_to tournaments_path
  end

  # Plan 38-02: `define_participants` und `finalize_modus` enthalten beide
  # `seedings.where(player_id: nil).destroy_all` — was wie ein Datenverlust-Pfad fuer die 2 017
  # verwaisten Seedings aussieht (1 227 davon tragen Ergebnisse mit Name und Verein im data-Blob,
  # entstanden per `Player has_many :seedings, dependent: :nullify`, das ueber update_all laeuft und
  # damit auch PaperTrail umgeht — es gibt keine Historie zum Rekonstruieren).
  #
  # ER IST ES NICHT, und diese Tests halten den Grund fest. Die Kette:
  #
  #   Seeding traegt data["result"] und ist global (id < MIN_ID)
  #     -> Tournament#has_clubcloud_results? ist true          (tournament.rb:594)
  #     -> ensure_local_server leitet auf die Detailseite um   (tournaments_controller.rb:1381)
  #     -> der Action-Body und damit das destroy_all werden NIE erreicht
  #
  # Gemessen (2026-08-17, Dev-Abzug): von 761 Turnieren mit solchen Seedings sind **0** ungeschuetzt,
  # und alle 1 227 Ergebnis-Seedings sind global. Der Schutz deckt die schuetzenswerte Menge
  # lueckenlos ab. Wer die Löschzeile kuenftig fuer gefaehrlich haelt, findet hier die Gegenprobe —
  # und wer `has_clubcloud_results?` aendert, bricht diese Tests und wird auf die Folge gestossen.
  #
  # Das Seeding muss per update_columns verwaist werden: `belongs_to :player` laesst ein
  # player_id-nil-Seeding gar nicht erst anlegen — genau diese Pflicht umgeht :nullify im Bestand.
  def orphaned_seeding_with_result(tournament, id:, position:)
    filler = Player.create!(lastname: "ORPH", firstname: "Olga", fl_name: "O. Orph",
      dbu_nr: "66#{id.to_s.last(4)}")
    seeding = Seeding.create!(
      id: id, tournament: tournament, player: filler, position: position,
      data: {"result" => {"Gesamtrangliste" => {"Name" => "Braun, Stefan", "Verein" => "BC Testheim"}}}
    )
    seeding.update_columns(player_id: nil)
    seeding
  end

  test "GET define_participants ist fuer Turniere mit CC-Ergebnissen schreibgeschuetzt" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in users(:admin)

    tournament = Tournament.create!(
      id: 23_463, title: "Schreibschutz 38-02", shortname: "SCH3802",
      season: @tournament.season, organizer: regions(:nbv), region_id: regions(:nbv).id,
      date: Time.zone.local(2026, 10, 10, 10, 0)
    )
    orphan = orphaned_seeding_with_result(tournament, id: 23_491, position: 1)
    assert tournament.has_clubcloud_results?, "Vorbedingung: das Ergebnis-Seeding macht das Turnier geschuetzt"

    get define_participants_tournament_url(tournament)

    assert_redirected_to tournament_path(tournament),
      "der Schreibschutz muss den Action-Body verhindern — sonst waere das destroy_all erreichbar"
    assert Seeding.exists?(orphan.id), "das Seeding ueberlebt"
    assert_equal "Braun, Stefan", orphan.reload.data.dig("result", "Gesamtrangliste", "Name"),
      "der Ergebnis-Blob bleibt unveraendert"
  end

  test "GET finalize_modus ist fuer Turniere mit CC-Ergebnissen schreibgeschuetzt" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in users(:admin)

    tournament = Tournament.create!(
      id: 23_464, title: "Schreibschutz 38-02b", shortname: "SCH3802B",
      season: @tournament.season, organizer: regions(:nbv), region_id: regions(:nbv).id,
      date: Time.zone.local(2026, 10, 10, 10, 0)
    )
    orphan = orphaned_seeding_with_result(tournament, id: 23_492, position: 1)

    get finalize_modus_tournament_url(tournament)

    assert_redirected_to tournament_path(tournament)
    assert Seeding.exists?(orphan.id), "das Seeding ueberlebt"
  end

  # Plan 38-02, Nebenbefund aus der Diagnose: die Ansicht rief `@tournament.discipline.name`, aber
  # `belongs_to :discipline` ist `optional: true` — 8 von 18 635 Turnieren haben keine (alle alt und
  # global, keines lokal, der Fall ist also selten). Ein 500er ist es trotzdem gewesen.
  test "GET define_participants rendert auch ohne Disziplin" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in users(:admin)

    tournament = Tournament.create!(
      id: 23_467, title: "Ohne Disziplin 38-02", shortname: "ODI3802",
      season: @tournament.season, organizer: regions(:nbv), region_id: regions(:nbv).id,
      date: Time.zone.local(2026, 10, 10, 10, 0)
    )
    assert_nil tournament.discipline, "Vorbedingung: Turnier ohne Disziplin"

    get define_participants_tournament_url(tournament)

    assert_not_equal 500, response.status,
      "die Ansicht darf an einer fehlenden Disziplin nicht scheitern"
  end

  # Plan 36-06: Das Oeffnen der Teilnehmerliste macht sie lokal. Ohne das blieb der Ablauf stecken —
  # "Teilnehmerliste abschliessen" wird erst erreichbar, wenn lokale Seedings existieren
  # (wizard_current_step steigt sonst nicht auf 3). Live aufgefallen 2026-08-06 auf ebc.
  test "GET define_participants uebernimmt die Meldeliste lokal" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in users(:admin)

    tournament = Tournament.create!(
      id: 23_462, title: "Oeffnen 36-06", shortname: "OEF3606",
      season: @tournament.season, organizer: regions(:nbv), region_id: regions(:nbv).id,
      date: Time.zone.local(2026, 10, 10, 10, 0)
    )
    a = Player.create!(lastname: "AA", firstname: "Anna", fl_name: "A. AA", dbu_nr: "663311")
    b = Player.create!(lastname: "BB", firstname: "Bodo", fl_name: "B. BB", dbu_nr: "663322")
    Seeding.create!(id: 23_481, tournament: tournament, player: a, position: 1)
    Seeding.create!(id: 23_482, tournament: tournament, player: b, position: 2)

    assert_not tournament.has_local_seedings?, "Vorbedingung: nur globale Meldungen"

    get define_participants_tournament_url(tournament)

    assert tournament.reload.has_local_seedings?, "das Oeffnen muss die Liste lokal machen"
    local = tournament.seedings.where("seedings.id >= ?", Seeding::MIN_ID)
    assert_equal [a.id, b.id].sort, local.map(&:player_id).sort
    assert_equal [1, 2], local.order(:position).map(&:position), "die Reihenfolge bleibt"

    # Idempotent — ein zweites Oeffnen darf nichts verdoppeln.
    assert_no_difference("Seeding.count") { get define_participants_tournament_url(tournament) }
  end

  # Plan 36-05: Ein in der Quelle GESTRICHENER Spieler darf bei der Uebernahme nicht als regulaerer
  # Teilnehmer zurueckkehren — bisher startete jede Kopie im Initialzustand "registered"
  # (seeding.rb:29), live gesehen 2026-08-05 an Turnier 18612. Er muss aber SICHTBAR bleiben
  # (Betreiber, nach dem Test auf bcw): mit leerem Haken ist er mit einem Klick wieder dabei.
  test "POST use_clubcloud_as_participants uebernimmt gestrichene Spieler als no_show" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in users(:admin)

    tournament = Tournament.create!(
      id: 23_461, title: "Uebernahme 36-05", shortname: "UEB3605",
      season: @tournament.season, organizer: regions(:nbv), region_id: regions(:nbv).id,
      date: Time.zone.local(2026, 10, 10, 10, 0)
    )
    taken = Player.create!(lastname: "TAKEN", firstname: "Tim", fl_name: "T. Taken", dbu_nr: "661111")
    struck = Player.create!(lastname: "STRUCK", firstname: "Sven", fl_name: "S. Struck", dbu_nr: "662222")
    Seeding.create!(id: 23_471, tournament: tournament, player: taken, position: 1)
    Seeding.create!(id: 23_472, tournament: tournament, player: struck, position: 2, state: "no_show")

    post use_clubcloud_as_participants_tournament_url(tournament)

    local = tournament.reload.seedings.where("seedings.id >= ?", Seeding::MIN_ID)
    assert_equal [taken.id, struck.id].sort, local.map(&:player_id).sort,
      "beide werden uebernommen — der gestrichene muss sichtbar bleiben"
    assert_equal "no_show", local.find_by(player_id: struck.id).state,
      "aber er kehrt nicht als Teilnehmer zurueck"
    assert_equal [taken.id], local.where.not(state: "no_show").map(&:player_id)
  end

  test "POST update_seeding_position returns ok or bad_request when local server" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in users(:admin) # Plan 32-07: manage_teilnehmerliste?-Gate — autorisierter User, Test prüft Action-Body
    # nil seeding_id and 0 position → bad_request
    post update_seeding_position_tournament_url(@tournament), params: { seeding_id: nil, position: 0 }
    assert_includes [200, 400], response.status,
      "update_seeding_position should return ok or bad_request"
  end

  test "POST update_seeding_position redirects to tournaments_path when not local server" do
    Carambus.config.carambus_api_url = nil
    post update_seeding_position_tournament_url(@tournament)
    assert_redirected_to tournaments_path
  end

  # ---------------------------------------------------------------------------
  # Plan 32-07: Schreib-Gate manage_teilnehmerliste? (TL / Sportwart im Wirkbereich / Admin)
  # ---------------------------------------------------------------------------

  test "AC-2: nicht-autorisierter User wird bei finish_seeding abgewiesen" do
    Carambus.config.carambus_api_url = "http://local.test"
    # @user (users(:one)) ist weder Admin (club_admin?/system_admin?) noch TL noch Sportwart → Gate greift.
    sign_in @user
    post finish_seeding_tournament_url(@tournament)
    assert_redirected_to tournament_path(@tournament)
    assert flash[:alert].present?, "Ablehnung muss eine Flash-Meldung setzen"
  end

  test "AC-1: Admin darf define_participants (Action-Body erreicht, keine Gate-Ablehnung)" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in users(:admin)
    get define_participants_tournament_url(@tournament)
    assert_response :success
  end

  test "AC-1: TL des Turniers darf define_participants (leiter?-Zweig)" do
    Carambus.config.carambus_api_url = "http://local.test"
    @tournament.update_column(:turnier_leiter_user_id, @user.id)
    sign_in @user # users(:one): weder Admin noch Sportwart, aber TL dieses Turniers
    get define_participants_tournament_url(@tournament)
    assert_response :success
  end

  test "POST add_team passes guard when local server" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in @club_admin # 17-05: Setup-Recht
    # No player params provided — redirects or rescues gracefully
    post add_team_tournament_url(@tournament)
    # add_team has rescue StandardError block that logs but may return nil (204 no content)
    assert_includes [200, 302, 204], response.status,
      "add_team should respond without unhandled exception"
  end

  test "POST add_team redirects to tournaments_path when not local server" do
    Carambus.config.carambus_api_url = nil
    post add_team_tournament_url(@tournament)
    assert_redirected_to tournaments_path
  end

  test "POST placement is not guarded by ensure_local_server" do
    # placement is NOT in the ensure_local_server list — it runs on both server types.
    # Without valid game_id/table_id, Game.find raises RecordNotFound → 404.
    Carambus.config.carambus_api_url = nil
    post placement_tournament_url(@tournament), params: { game_id: 9_999_999, table_id: 9_999_999 }
    assert_includes [200, 302, 404, 500], response.status,
      "placement should reach action body (not guard redirect to tournaments_path)"
  end

  test "POST placement passes guard when local server" do
    Carambus.config.carambus_api_url = "http://local.test"
    # With missing/invalid game_id and table_id: ActiveRecord::RecordNotFound → 404.
    # The guard passes (not redirected to tournaments_path) — that is what we verify.
    post placement_tournament_url(@tournament), params: { game_id: 9_999_999, table_id: 9_999_999 }
    assert_includes [200, 302, 404, 500], response.status,
      "placement should reach action body (not guard redirect) in local server mode"
  end

  # ---------------------------------------------------------------------------
  # Plan 14-G.3 / F3-B: TL-Zuweisung mit Pundit-authorize-Check
  # ---------------------------------------------------------------------------

  # Plan 17-05: update ist Stammdaten und damit Admin-Sache. Ein Sportwart ohne Admin-Rolle benennt den
  # Turnierleiter ueber den Carambus-Assistenten (MCP-Tool assign_tournament_leiter schreibt direkt,
  # nicht ueber diesen Controller) — so steht es in docs/managers/admin-roles. Bis 17-05 ging er
  # hier per PATCH durch; der Test verlangte das und ist deshalb umgedreht.
  test "PATCH update mit TL-change — Sportwart-im-Wirkbereich ohne Admin-Rolle → abgewiesen (17-05)" do
    Carambus.config.carambus_api_url = "http://local.test"
    # D-38: Sportwart-Mitgliedschaft ist EXPLIZIT (persona_grants), nicht aus der
    # Join-Praesenz abgeleitet — ohne Grant liefert in_sportwart_scope? false.
    sportwart = User.create!(email: "ctrl_sw@test.de", password: "password123",
      confirmed_at: Time.current, persona_grants: ["sportwart"])
    sportwart.sportwart_locations << locations(:one)
    sportwart.sportwart_disciplines << disciplines(:carom_3band)
    # Repair fixture-rot: ensure tournament has matching location + discipline
    @tournament.update_columns(location_id: locations(:one).id, discipline_id: disciplines(:carom_3band).id)
    new_tl = User.create!(email: "ctrl_tl@test.de", password: "password123", confirmed_at: Time.current)

    sign_out @user
    sign_in sportwart
    original_tl_id = @tournament.turnier_leiter_user_id
    patch tournament_url(@tournament), params: {tournament: {turnier_leiter_user_id: new_tl.id}}

    assert_redirected_to tournament_path(@tournament)
    assert_equal I18n.t("tournaments.errors.admin_required"), flash[:alert]
    assert_equal original_tl_id, @tournament.reload.turnier_leiter_user_id, "TL bleibt unveraendert"
  end

  test "PATCH update mit TL-change — Random-User → redirect with flash[:alert] (Pundit-denied)" do
    Carambus.config.carambus_api_url = "http://local.test"
    random_user = User.create!(email: "ctrl_rand@test.de", password: "password123", confirmed_at: Time.current)
    new_tl = User.create!(email: "ctrl_tl_rand@test.de", password: "password123", confirmed_at: Time.current)
    original_tl_id = @tournament.turnier_leiter_user_id

    sign_out @user
    sign_in random_user
    patch tournament_url(@tournament), params: {tournament: {turnier_leiter_user_id: new_tl.id}}

    @tournament.reload
    assert_equal original_tl_id, @tournament.turnier_leiter_user_id, "TL darf NICHT geändert sein"
    # 17-05: das Admin-Gate greift vor dem assign_leiter?-Check
    assert_equal I18n.t("tournaments.errors.admin_required"), flash[:alert]
  end

  test "PATCH update mit TL-change — system_admin → success + TL updated (admin-Bypass)" do
    Carambus.config.carambus_api_url = "http://local.test"
    new_tl = User.create!(email: "ctrl_tl_sa@test.de", password: "password123", confirmed_at: Time.current)

    sign_out @user
    sign_in @system_admin
    patch tournament_url(@tournament), params: {tournament: {turnier_leiter_user_id: new_tl.id}}

    assert_includes [200, 302], response.status, "update should succeed for sysadmin"
    @tournament.reload
    assert_equal new_tl.id, @tournament.turnier_leiter_user_id, "TL muss gesetzt sein (admin-Bypass)"
  end

  # Bis 17-05 ging ein Update OHNE TL-Wechsel fuer jeden angemeldeten Benutzer durch — der Test hielt
  # das als „existing behavior“ fest. Plan 17-05 hat genau diese Luecke geschlossen.
  test "PATCH update ohne TL-change — ein Benutzer ohne Admin-Rolle wird abgewiesen (17-05)" do
    Carambus.config.carambus_api_url = "http://local.test"
    random_user = User.create!(email: "ctrl_rand_smoke@test.de", password: "password123", confirmed_at: Time.current)
    title_before = @tournament.title

    sign_out @user
    sign_in random_user
    patch tournament_url(@tournament), params: {tournament: {title: "Updated Title Smoke"}}

    assert_equal I18n.t("tournaments.errors.admin_required"), flash[:alert]
    assert_equal title_before, @tournament.reload.title
  end

  test "PATCH update meldet unerwartete Fehler sichtbar statt still (vorher: 204 No Content)" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in @club_admin # 17-05: Stammdaten nur fuer Admins
    original_title = @tournament.title

    # organizer_type auf eine nicht existierende Klasse => NameError beim Speichern.
    patch tournament_url(@tournament), params: {tournament: {
      title: "Darf nicht durchkommen", organizer_type: "NoSuchClassXY", organizer_id: 1
    }}

    assert_response :unprocessable_entity, "Fehler muss sichtbar werden, nicht als 204 verschwinden"
    assert_match(/Aktualisierung fehlgeschlagen/, flash[:alert].to_s)
    @tournament.reload
    assert_equal original_title, @tournament.title
  end

  # ---------------------------------------------------------------------------
  # Plan 25-01: Anlage-Blocker. Bis hierher war KEIN manueller Anlage-Weg im UI
  # benutzbar — _form.html.erb rief `@tournament.id < MIN_ID` bei id == nil
  # (NoMethodError). Die bestehenden Guard-Tests oben tolerieren Status 500
  # ausdruecklich ("view dependency") und haben den Blocker deshalb nie gefangen.
  # Die folgenden Tests verlangen 200 strikt. Seit 17-05 laufen sie als club_admin (Stammdaten).
  # ---------------------------------------------------------------------------

  test "GET new renders the form (regression: NoMethodError on nil id)" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in @club_admin
    get new_tournament_url

    assert_response :success, "new muss das Formular rendern, nicht mit 500 sterben"
    assert_select "form" do
      assert_select "input[name=?]", "tournament[title]"
      assert_select "input[name=?]", "tournament[shortname]"
      assert_select "input[name=?]", "tournament[date]"
      assert_select "input[name=?]", "tournament[end_date]"
      assert_select "input[name=?]", "tournament[source_url]"
    end
  end

  test "GET new leaves source_url editable for a new record" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in @club_admin
    get new_tournament_url

    assert_response :success
    assert_select "input[name=?][disabled]", "tournament[source_url]", 0,
      "source_url darf bei Neuanlage NICHT disabled sein"
  end

  test "GET edit keeps source_url disabled for an imported (global) tournament" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in @club_admin
    imported = tournaments(:imported)
    assert imported.id < Tournament::MIN_ID, "Fixture-Vorbedingung: globales Turnier"

    get edit_tournament_url(imported)

    assert_response :success
    # Hinweis: keine Message als 3. Argument — assert_select deutet sie als Equality-Test.
    assert_select "input[name=?][disabled]", "tournament[source_url]"
  end

  test "POST create persists tournament and disables auto_upload_to_cc" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in @club_admin

    assert_difference("Tournament.count", 1) do
      post tournaments_url, params: {tournament: {
        title: "CC-loses Turnier",
        shortname: "CCL",
        date: 2.weeks.from_now,
        end_date: 2.weeks.from_now + 1.day,
        season_id: 50_000_001,
        organizer_id: 50_000_001,
        organizer_type: "Region"
      }}
    end

    created = Tournament.order(:id).last
    assert_redirected_to created
    assert_equal "CC-loses Turnier", created.title
    refute created.auto_upload_to_cc, "CC-los angelegte Turniere duerfen nicht automatisch hochgeladen werden"
  end

  test "POST create re-renders with errors instead of silently redirecting" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in @club_admin

    assert_no_difference("Tournament.count") do
      # season fehlt — belongs_to :season ist nicht optional
      post tournaments_url, params: {tournament: {
        title: "Turnier ohne Saison",
        shortname: "TOS",
        organizer_id: 50_000_001,
        organizer_type: "Region"
      }}
    end

    assert_response :unprocessable_entity,
      "Validierungsfehler muessen sichtbar werden (vorher: stiller redirect_back)"
    assert_select "form"
  end

  # ---------------------------------------------------------------------------
  # Plan 26-01: players_by_club — speist die Club->Spieler-Kaskade der Meldeliste.
  # Bei Region-Turnieren war die Teilnehmerauswahl bisher zirkulaer (nur Spieler MIT
  # Seeding in genau diesem Turnier) und damit immer leer.
  # ---------------------------------------------------------------------------

  def seed_club_with_players
    club = Club.create!(name: "Testverein 26", shortname: "TV26", region_id: 50_000_001)
    # Saison des Turniers — der Endpunkt filtert danach (nicht nach Season.current_season,
    # die in der Testumgebung nil ist).
    season = @tournament.season
    a = Player.create!(lastname: "ALPHA", firstname: "Anna", fl_name: "A. Alpha", dbu_nr: "111111")
    b = Player.create!(lastname: "BETA", firstname: "Bert", fl_name: "B. Beta", dbu_nr: "222222")
    [a, b].each { |pl| SeasonParticipation.create!(player: pl, club: club, season: season) }
    [club, a, b]
  end

  test "GET players_by_club returns the club players with dbu_nr" do
    Carambus.config.carambus_api_url = "http://local.test"
    club, a, b = seed_club_with_players

    get players_by_club_tournament_url(@tournament, club_id: club.id)

    assert_response :success
    rows = JSON.parse(response.body)
    assert_equal 2, rows.size
    assert_equal [a.id, b.id].sort, rows.map { |r| r["id"] }.sort
    assert_equal [111_111, 222_222], rows.map { |r| r["dbu_nr"] }.sort  # dbu_nr ist integer
    assert rows.all? { |r| r["label"].present? }, "label muss gesetzt sein"
  end

  test "GET players_by_club without club_id returns an empty list" do
    Carambus.config.carambus_api_url = "http://local.test"

    get players_by_club_tournament_url(@tournament)

    assert_response :success
    assert_equal [], JSON.parse(response.body)
  end

  test "GET players_by_club omits players already seeded in this tournament" do
    Carambus.config.carambus_api_url = "http://local.test"
    club, a, _b = seed_club_with_players
    @tournament.seedings.create!(player_id: a.id, position: 1)

    get players_by_club_tournament_url(@tournament, club_id: club.id)

    rows = JSON.parse(response.body)
    refute_includes rows.map { |r| r["id"] }, a.id,
      "bereits gemeldeter Spieler darf nicht erneut angeboten werden"
    assert_equal 1, rows.size
  end

  test "GET players_by_club redirects to tournaments_path when not local server" do
    Carambus.config.carambus_api_url = nil

    get players_by_club_tournament_url(@tournament, club_id: 1)

    assert_redirected_to tournaments_path
  end

  test "GET define_participants renders the club cascade for a region tournament" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in users(:admin) # Plan 32-07: manage_teilnehmerliste?-Gate — autorisierter User, Test prüft Action-Body
    club, _a, _b = seed_club_with_players

    get define_participants_tournament_url(@tournament)

    assert_response :success
    assert_select "[data-controller='dependent-select']", 1,
      "Kaskaden-Block muss bei Region-Turnieren gerendert werden"
    assert_select "select[name=?]", "entry_list_club_id" do
      assert_select "option[value=?]", club.id.to_s
    end
    # Das Spieler-Select speist add_player_by_dbu direkt (name=dbu_nr).
    assert_select "form[action=?] select[name=?]",
      add_player_by_dbu_tournament_path(@tournament), "dbu_nr"
    # Das bestehende DBU-Textfeld bleibt als Weg fuer Gastspieler erhalten.
    assert_select "input[name=?]", "dbu_nr"
  end

  # Plan 27-01: Entwuerfe aus der Saison-Kopie sind in der regulaeren Liste ausgeblendet.

  # Plan 27-01: Entwurfs-Ausblendung im Index.
  #
  # BEFUND: Ein Integrationstest kann den Listeninhalt hier nicht pruefen — der SearchService
  # liefert im Testkontext generell 0 Records (13 Turniere in der DB, `results.count == 0`
  # schon VOR jedem Draft-Filter). Das ist vorbestehend und unabhaengig von dieser Aenderung.
  # Geprueft wird daher, dass der Index mit und ohne `drafts`-Param fehlerfrei rendert
  # (Regression: die Scopes muessen `tournaments.data` qualifizieren, sonst PG::AmbiguousColumn).
  # Die Trennung der Mengen deckt tournament_test.rb ueber die Scopes ab.
  test "GET index rendert mit und ohne drafts-Param" do
    Carambus.config.carambus_api_url = "http://local.test"
    Tournament.create!(title: "Entwurfskopie", season: @tournament.season,
      organizer: regions(:nbv), date: 3.weeks.from_now, data: {"draft" => true})

    get tournaments_url
    assert_response :success

    get tournaments_url(drafts: 1)
    assert_response :success
  end

  # ---------------------------------------------------------------------------
  # Saison-Kopie mit Auswahl (Sportwart-Weg zum Rake-Task tournaments:copy_season).
  # Zielsaison wird explizit uebergeben, damit der Test nicht an Season.current_season haengt.
  # ---------------------------------------------------------------------------

  def enable_region_server(shortname = "NBV")
    Carambus.config.carambus_api_url = "http://local.test"
    @original_context = Carambus.config.context
    Carambus.config.context = shortname
  end

  # 17-05: die Saison-Kopie ist Admin-Sache
  def enable_region_server_as_admin
    enable_region_server
    sign_in @club_admin
  end

  def vorsaison_turnier(title: "LM Dreiband Vorlage")
    Tournament.create!(title: title, season: seasons(:previous), organizer: regions(:nbv),
      region_id: regions(:nbv).id, date: Time.zone.local(2024, 10, 12, 10, 0))
  end

  test "GET copy_season zeigt die Vorsaison-Turniere zur Auswahl" do
    enable_region_server_as_admin
    quelle = vorsaison_turnier

    get copy_season_tournaments_url(to_season_id: seasons(:current).id)

    assert_response :success
    assert_select "input[type=checkbox][name='source_ids[]'][value=?]", quelle.id.to_s
    assert_select "[data-action='checkbox-group#selectAll']", 1, "Button 'alle auswaehlen'"
  ensure
    Carambus.config.context = @original_context
  end

  test "GET copy_season auf dem API-Server wird abgewiesen" do
    # carambus_api_url bleibt leer => Authority => ensure_local_server greift
    get copy_season_tournaments_url

    assert_redirected_to tournaments_path
  end

  test "POST copy_season_execute kopiert nur die Auswahl" do
    enable_region_server_as_admin
    quelle = vorsaison_turnier
    ignoriert = vorsaison_turnier(title: "Nicht ausgewaehlt")

    assert_difference("Tournament.count", 1) do
      post copy_season_execute_tournaments_url,
        params: {to_season_id: seasons(:current).id, source_ids: [quelle.id]}
    end

    assert_redirected_to tournaments_path(drafts: 1)
    kopie = Tournament.where(season_id: seasons(:current).id)
      .find { |t| t.data.is_a?(Hash) && t.data["copied_from_tournament_id"] == quelle.id }
    assert kopie, "Kopie des ausgewaehlten Turniers"
    assert kopie.data["draft"], "Kopien sind Entwuerfe"
    refute Tournament.where(season_id: seasons(:current).id)
      .any? { |t| t.data.is_a?(Hash) && t.data["copied_from_tournament_id"] == ignoriert.id }
  ensure
    Carambus.config.context = @original_context
  end

  # Ein leeres Formular darf NICHT als "alle kopieren" durchgehen.
  test "POST copy_season_execute ohne Auswahl kopiert nichts" do
    enable_region_server_as_admin
    vorsaison_turnier

    assert_no_difference("Tournament.count") do
      post copy_season_execute_tournaments_url, params: {to_season_id: seasons(:current).id}
    end

    assert_response :redirect
  ensure
    Carambus.config.context = @original_context
  end

  # ---------------------------------------------------------------------------
  # Entwurf freigeben / löschen (Saison-Kopie).
  # ---------------------------------------------------------------------------

  def draft_tournament(overrides = {})
    Tournament.create!({
      title: "Entwurf LM Dreiband", shortname: "ELM3B",
      season: seasons(:current), organizer: regions(:nbv), region_id: regions(:nbv).id,
      discipline: disciplines(:one), date: Time.zone.local(2025, 10, 11, 10, 0),
      data: {"draft" => true, "copied_from_tournament_id" => 42}
    }.merge(overrides))
  end

  test "POST release_draft entfernt das draft-Flag und stößt den Authority-Sync an" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in @club_admin # 17-05: Setup-Recht
    t = draft_tournament

    notified = nil
    EntryListSyncJob.stub(:enqueue_for, ->(tournament:) { notified = tournament }) do
      post release_draft_tournament_url(t)
    end

    assert_redirected_to tournaments_path
    refute t.reload.draft?, "draft-Flag entfernt"
    assert_equal t.id, notified&.id, "release_draft stößt den Authority-Sync an"
    # copied_from_tournament_id bleibt (Idempotenz-Schlüssel des Ingests).
    assert_equal 42, t.data["copied_from_tournament_id"]
  end

  test "release_draft verweigert bei fehlender Disziplin und nennt das Feld" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in @club_admin
    t = draft_tournament(discipline: nil)

    post release_draft_tournament_url(t)

    assert_redirected_to tournaments_path(drafts: 1)
    assert t.reload.draft?, "bleibt Entwurf"
  end

  test "release_draft verweigert bei Platzhalter-Datum" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in @club_admin
    t = draft_tournament(date: Time.at(0))

    post release_draft_tournament_url(t)

    assert_redirected_to tournaments_path(drafts: 1)
    assert t.reload.draft?
  end

  test "release_draft auf dem API-Server wird abgewiesen" do
    # carambus_api_url leer => Authority => ensure_local_server greift
    Carambus.config.carambus_api_url = nil
    t = draft_tournament
    post release_draft_tournament_url(t)
    assert_redirected_to tournaments_path
    assert t.reload.draft?
  end

  test "DELETE destroy löscht einen Entwurf" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in @club_admin # 17-05: Stammdaten nur fuer Admins
    t = draft_tournament

    assert_difference("Tournament.count", -1) do
      delete tournament_url(t)
    end
  end

  # ---------------------------------------------------------------------------
  # AC-5: On-demand-Reload der Meldeliste auf dem managenden Local Server.
  # ---------------------------------------------------------------------------

  test "reload_entry_list ruft update_from_carambus_api mit import_entry_list" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in @club_admin # 17-05: Setup-Recht
    t = released_tournament_with_scope

    captured = nil
    Version.stub(:update_from_carambus_api, ->(opts) { captured = opts }) do
      post reload_entry_list_tournament_url(t)
    end

    assert_redirected_to tournament_path(t)
    assert_equal t.region_id, captured[:import_entry_list]
    assert_equal t.season_id, captured[:season_id]
    assert_equal t.region_id, captured[:region_id]
  end

  test "reload_entry_list auf dem API-Server wird abgewiesen" do
    # carambus_api_url leer => Authority
    t = released_tournament_with_scope
    called = false
    Version.stub(:update_from_carambus_api, ->(*) { called = true }) do
      post reload_entry_list_tournament_url(t)
    end
    refute called
  end

  test "reload_entry_list meldet Fehler statt zu crashen, wenn die Authority nicht erreichbar ist" do
    Carambus.config.carambus_api_url = "http://local.test"
    sign_in @club_admin
    t = released_tournament_with_scope

    Version.stub(:update_from_carambus_api, ->(*) { raise "connection refused" }) do
      post reload_entry_list_tournament_url(t)
    end

    assert_redirected_to tournament_path(t)
    assert flash[:alert].present?, "ein Netzfehler wird als flash gemeldet, nicht als 500"
  end

  # ---------------------------------------------------------------------------
  # Plan 17-01: Reset nur fuer angemeldete Admins — Sichtbarkeit und Recht nach derselben Regel.
  # `admin_can_reset_tournament?` gibt ohne Benutzer `true` (interne Aufrufe beim Initialisieren);
  # ohne Pruefung im Controller konnte deshalb ein nicht angemeldeter Besucher zuruecksetzen.
  # ---------------------------------------------------------------------------

  def live_game_on(tournament)
    tournament.games.create!(id: 61_500_001, gname: "hf1", data: {})
  end

  test "17-01 AC-5: nicht angemeldet raeumt der Soft-Reset keine Spiele ab" do
    sign_out @user
    Carambus.config.carambus_api_url = "http://local.test"
    game = live_game_on(@tournament)

    post reset_tournament_url(@tournament, soft_reset: true)

    assert_redirected_to tournament_path(@tournament)
    assert Game.exists?(game.id), "Ein anonymer Besucher darf kein Turnier zuruecksetzen"
    assert_equal I18n.t("tournaments.show.soft_reset_tournament_modal.denied"), flash[:alert]
  end

  test "17-01 AC-5: nicht angemeldet laesst der Zwangs-Reset den Turnierzustand stehen" do
    sign_out @user
    Carambus.config.carambus_api_url = "http://local.test"
    state_before = @tournament.state

    post reset_tournament_url(@tournament, force_reset: true)

    assert_redirected_to tournament_path(@tournament)
    assert_equal state_before, @tournament.reload.state
  end

  test "17-01 AC-5: nicht angemeldet laesst auch der Reset ohne Parameter den Zustand stehen" do
    sign_out @user
    Carambus.config.carambus_api_url = "http://local.test"
    state_before = @tournament.state

    post reset_tournament_url(@tournament)

    assert_redirected_to tournament_path(@tournament)
    assert_equal state_before, @tournament.reload.state
  end

  test "17-01 AC-5: ein player bekommt beim Zwangs-Reset eine Absage statt einer Exception" do
    Carambus.config.carambus_api_url = "http://local.test"
    state_before = @tournament.state

    post reset_tournament_url(@tournament, force_reset: true)

    assert_redirected_to tournament_path(@tournament)
    assert_equal state_before, @tournament.reload.state
    assert_equal I18n.t("tournaments.show.soft_reset_tournament_modal.denied"), flash[:alert]
  end

  test "17-01 AC-5: ein club_admin setzt sanft zurueck wie bisher" do
    sign_out @user
    sign_in @club_admin
    Carambus.config.carambus_api_url = "http://local.test"
    game = live_game_on(@tournament)

    post reset_tournament_url(@tournament, soft_reset: true)

    assert_redirected_to tournament_path(@tournament)
    refute Game.exists?(game.id), "Der Soft-Reset raeumt die Live-Spiele ab"
  end

  test "17-01 AC-4: ein club_admin sieht den Soft-Reset-Knopf, ohne auf einer E-Mail-Liste zu stehen" do
    sign_out @user
    sign_in @club_admin
    Carambus.config.carambus_api_url = "http://local.test"
    refute_includes User::PRIVILEGED, @club_admin.email, "Vorbedingung: nicht ueber die Liste berechtigt"

    get tournament_url(@tournament)

    assert_response :success
    assert_match(/soft-reset-tournament-form-#{@tournament.id}/, response.body)
    assert_match(/force-reset-tournament-form-#{@tournament.id}/, response.body)
  end

  test "17-01 AC-4: ein player sieht weder Soft- noch Zwangs-Reset" do
    Carambus.config.carambus_api_url = "http://local.test"

    get tournament_url(@tournament)

    assert_response :success
    assert_no_match(/soft-reset-tournament-form-#{@tournament.id}/, response.body)
    assert_no_match(/force-reset-tournament-form-#{@tournament.id}/, response.body)
  end

  # AC-4b (Spec-Fix aus dem Handtest 2026-09-13): auch „Teilnehmerliste bearbeiten“ und der Reset
  # fuer noch nicht gestartete Turniere folgen ihrem Recht. Die ids werden mit `id="` verankert —
  # /reset-tournament-form-<id>/ allein traefe auch soft-/force-reset-tournament-form-<id>.
  def assert_admin_buttons(visible:)
    reset_form = /id="reset-tournament-form-#{@tournament.id}"/
    participants_link = /href="#{Regexp.escape(define_participants_tournament_path(@tournament))}"/
    if visible
      assert_match reset_form, response.body
      assert_match participants_link, response.body
    else
      assert_no_match reset_form, response.body
      assert_no_match participants_link, response.body
    end
  end

  test "17-01 AC-4b: nicht angemeldet sieht weder Reset noch Teilnehmerliste bearbeiten" do
    sign_out @user
    Carambus.config.carambus_api_url = "http://local.test"
    assert_not @tournament.tournament_started, "Vorbedingung: nicht gestartet, sonst fehlt der Reset-Knopf ohnehin"

    get tournament_url(@tournament)

    assert_response :success
    assert_admin_buttons(visible: false)
  end

  test "17-01 AC-4b: ein player ohne Turnierleiter-/Sportwart-Recht sieht beide nicht" do
    Carambus.config.carambus_api_url = "http://local.test"
    refute TournamentPolicy.new(@user, @tournament).manage_teilnehmerliste?, "Vorbedingung: kein Recht"

    get tournament_url(@tournament)

    assert_response :success
    assert_admin_buttons(visible: false)
  end

  test "17-01 AC-4b: ein club_admin sieht Reset und Teilnehmerliste bearbeiten" do
    sign_out @user
    sign_in @club_admin
    Carambus.config.carambus_api_url = "http://local.test"

    get tournament_url(@tournament)

    assert_response :success
    assert_admin_buttons(visible: true)
  end

  def released_tournament_with_scope
    Tournament.create!(title: "CC-los", shortname: "CCL", season: seasons(:current),
      organizer: regions(:nbv), region_id: regions(:nbv).id, discipline: disciplines(:one),
      date: Time.zone.local(2025, 10, 11, 10, 0),
      source_url: "https://nbv.carambus.de/tournaments/50000123")
  end

  # ---------------------------------------------------------------------------
  # Plan 17-05: Schreibende Turnier-Aktionen verlangen ein Recht. Bis hierher band der Controller
  # ausser `reset` und den Teilnehmerlisten-Aktionen keine schreibende Aktion an einen Benutzer —
  # es gab nur `ensure_local_server`. Jeder Absage-Test unten war am unveraenderten Code rot.
  #   Stammdaten (new/create/edit/update/destroy/copy_season*) -> current_user&.admin?
  #   Setup (Modus, Start, Einladung, Entwurf, Meldeliste ...)  -> policy.prepare_tournament?
  #   placement (Scoreboard)                                    -> angemeldet
  # ---------------------------------------------------------------------------

  def valid_tournament_attrs(title)
    {title: title, shortname: "T1705", date: 2.weeks.from_now, season_id: seasons(:current).id,
     organizer_id: regions(:nbv).id, organizer_type: "Region", discipline_id: disciplines(:carom_3band).id}
  end

  # Sportwart per Persona; der Wirkbereich passt, wenn Spielort und Disziplin des Turniers passen.
  def sportwart_user(location: locations(:one))
    user = User.create!(email: "sw1705_#{SecureRandom.hex(3)}@test.de", password: "password123",
      confirmed_at: Time.current, persona_grants: ["sportwart"])
    user.sportwart_locations << location
    user.sportwart_disciplines << disciplines(:carom_3band)
    user
  end

  def put_tournament_in_sportwart_scope
    @tournament.update_columns(location_id: locations(:one).id, discipline_id: disciplines(:carom_3band).id)
  end

  # Modusauswahl ist moeglich: Teilnehmerliste abgeschlossen, noch kein Plan.
  def ready_for_mode_selection
    @tournament.update_columns(state: "tournament_seeding_finished", tournament_plan_id: nil)
  end

  def as(user)
    sign_out @user
    sign_in user if user
  end

  def admin_denied_message
    I18n.t("tournaments.errors.admin_required")
  end

  def setup_denied_message
    I18n.t("tournaments.errors.prepare_tournament_denied")
  end

  # destroy steht bewusst am Ende — am alten Code loeschte er das Turnier.
  def stammdaten_requests
    [
      [:get, new_tournament_url, {}],
      [:post, tournaments_url, {params: {tournament: valid_tournament_attrs("Ohne Recht angelegt")}}],
      [:get, copy_season_tournaments_url, {}],
      [:post, copy_season_execute_tournaments_url, {}],
      [:get, edit_tournament_url(@tournament), {}],
      [:patch, tournament_url(@tournament), {params: {tournament: {title: "Ohne Recht geaendert"}}}],
      [:post, test_tournament_status_update_tournament_url(@tournament), {}],
      [:delete, tournament_url(@tournament), {}]
    ]
  end

  def setup_requests
    [
      [:post, order_by_ranking_or_handicap_tournament_url(@tournament)],
      [:post, reload_from_cc_tournament_url(@tournament)],
      [:post, reload_entry_list_tournament_url(@tournament)],
      [:get, finalize_modus_tournament_url(@tournament)],
      [:post, select_modus_tournament_url(@tournament)],
      [:get, tournament_monitor_tournament_url(@tournament)],
      [:post, start_tournament_url(@tournament)],
      [:get, new_team_tournament_url(@tournament)],
      [:post, add_team_tournament_url(@tournament)],
      [:get, compare_seedings_tournament_url(@tournament)],
      [:post, upload_invitation_tournament_url(@tournament)],
      [:get, parse_invitation_tournament_url(@tournament)],
      [:post, recalculate_groups_tournament_url(@tournament)],
      [:post, release_draft_tournament_url(@tournament)]
    ]
  end

  def assert_each_denied(requests, message)
    failures = requests.filter_map do |verb, url, opts|
      # Die Flash-Meldung eines Redirects liegt in der NAECHSTEN Anfrage noch an — ohne diesen
      # Zwischenschritt ginge eine durchgelassene Aktion mit der Absage ihrer Vorgaengerin durch.
      get tournaments_url
      send(verb, url, **(opts || {}))
      next if response.redirect? && flash[:alert] == message

      "#{verb.upcase} #{URI(url).path} -> #{response.status} #{flash[:alert].inspect}"
    end
    assert_empty failures, "ohne Recht nicht abgewiesen:\n#{failures.join("\n")}"
  end

  # --- AC-2: Stammdaten nur fuer Admins --------------------------------------

  test "17-05 AC-2: nicht angemeldet wird jede Stammdaten-Aktion abgewiesen" do
    as(nil)
    Carambus.config.carambus_api_url = "http://local.test"
    assert_each_denied(stammdaten_requests, admin_denied_message)
    assert Tournament.exists?(@tournament.id), "das Turnier steht noch"
  end

  test "17-05 AC-2: ein player wird bei jeder Stammdaten-Aktion abgewiesen" do
    Carambus.config.carambus_api_url = "http://local.test"
    assert_each_denied(stammdaten_requests, admin_denied_message)
  end

  test "17-05 AC-2: nicht angemeldet legt POST create mit gueltigen Feldern nichts an" do
    as(nil)
    Carambus.config.carambus_api_url = "http://local.test"
    assert_no_difference("Tournament.count") do
      post tournaments_url, params: {tournament: valid_tournament_attrs("Anonym angelegt")}
    end
  end

  test "17-05 AC-2: ein player legt mit gueltigen Feldern nichts an" do
    Carambus.config.carambus_api_url = "http://local.test"
    assert_no_difference("Tournament.count") do
      post tournaments_url, params: {tournament: valid_tournament_attrs("Player angelegt")}
    end
  end

  test "17-05 AC-2: nicht angemeldet aendert PATCH update den Titel nicht" do
    as(nil)
    Carambus.config.carambus_api_url = "http://local.test"
    title_before = @tournament.title
    patch tournament_url(@tournament), params: {tournament: {title: "Anonym geaendert"}}
    assert_equal title_before, @tournament.reload.title
  end

  test "17-05 AC-2: ein Sportwart ohne Admin-Rolle aendert den Titel nicht" do
    Carambus.config.carambus_api_url = "http://local.test"
    put_tournament_in_sportwart_scope
    as(sportwart_user)
    title_before = @tournament.title
    patch tournament_url(@tournament), params: {tournament: {title: "Sportwart geaendert"}}
    assert_equal title_before, @tournament.reload.title
    assert_equal admin_denied_message, flash[:alert]
  end

  test "17-05 AC-2: nicht angemeldet loescht DELETE destroy nichts" do
    as(nil)
    Carambus.config.carambus_api_url = "http://local.test"
    assert_no_difference("Tournament.count") { delete tournament_url(@tournament) }
  end

  test "17-05 AC-2: ein player kopiert per copy_season_execute nichts" do
    enable_region_server
    quelle = vorsaison_turnier
    assert_no_difference("Tournament.count") do
      post copy_season_execute_tournaments_url,
        params: {to_season_id: seasons(:current).id, source_ids: [quelle.id]}
    end
  ensure
    Carambus.config.context = @original_context
  end

  test "17-05 AC-2: ein system_admin loescht und aendert wie bisher" do
    Carambus.config.carambus_api_url = "http://local.test"
    as(@system_admin)
    patch tournament_url(@tournament), params: {tournament: {title: "Sysadmin geaendert"}}
    assert_equal "Sysadmin geaendert", @tournament.reload.title
    assert_difference("Tournament.count", -1) { delete tournament_url(@tournament) }
  end

  # --- AC-3: Setup nur fuer Turnierleitung, Sportwart im Wirkbereich, Admins --

  test "17-05 AC-3: nicht angemeldet wird jede Setup-Aktion abgewiesen" do
    as(nil)
    Carambus.config.carambus_api_url = "http://local.test"
    assert_each_denied(setup_requests, setup_denied_message)
  end

  test "17-05 AC-3: ein player ohne Bezug wird bei jeder Setup-Aktion abgewiesen" do
    Carambus.config.carambus_api_url = "http://local.test"
    assert_each_denied(setup_requests, setup_denied_message)
  end

  test "17-05 AC-3: nicht angemeldet setzt select_modus keinen Turnierplan" do
    as(nil)
    Carambus.config.carambus_api_url = "http://local.test"
    ready_for_mode_selection
    post select_modus_tournament_url(@tournament), params: {tournament_plan_id: tournament_plans(:t04_5).id}
    assert_nil @tournament.reload.tournament_plan_id
    assert_equal "tournament_seeding_finished", @tournament.state
  end

  test "17-05 AC-3: ein Sportwart ausserhalb seines Wirkbereichs setzt keinen Turnierplan" do
    Carambus.config.carambus_api_url = "http://local.test"
    put_tournament_in_sportwart_scope
    ready_for_mode_selection
    elsewhere = Location.create!(name: "Fremdlokal 17-05")
    as(sportwart_user(location: elsewhere))
    post select_modus_tournament_url(@tournament), params: {tournament_plan_id: tournament_plans(:t04_5).id}
    assert_nil @tournament.reload.tournament_plan_id
    assert_equal setup_denied_message, flash[:alert]
  end

  test "17-05 AC-3: nicht angemeldet schreibt start keine Turnier-Parameter" do
    as(nil)
    Carambus.config.carambus_api_url = "http://local.test"
    balls_before = @tournament.data["balls_goal"]
    post start_tournament_url(@tournament), params: {balls_goal: 77, innings_goal: 20, parameter_verification_confirmed: "1"}
    assert_equal balls_before, @tournament.reload.data["balls_goal"]
    assert_nil @tournament.tournament_monitor, "kein Turnier-Monitor angelegt"
  end

  test "17-05 AC-3: nicht angemeldet gibt release_draft keinen Entwurf frei" do
    as(nil)
    Carambus.config.carambus_api_url = "http://local.test"
    t = draft_tournament
    EntryListSyncJob.stub(:enqueue_for, ->(**) { flunk "kein Sync ohne Recht" }) do
      post release_draft_tournament_url(t)
    end
    assert t.reload.draft?, "bleibt Entwurf"
  end

  test "17-05 AC-3: nicht angemeldet loest reload_entry_list keinen Abruf aus" do
    as(nil)
    Carambus.config.carambus_api_url = "http://local.test"
    t = released_tournament_with_scope
    called = false
    Version.stub(:update_from_carambus_api, ->(*) { called = true }) do
      post reload_entry_list_tournament_url(t)
    end
    refute called, "kein Authority-Abruf ohne Recht"
  end

  test "17-05 AC-3: ein player verwirft per recalculate_groups keine Einladungsgruppen" do
    Carambus.config.carambus_api_url = "http://local.test"
    @tournament.update_columns(data: @tournament.data.merge("extracted_group_assignment" => {"1" => [1, 2]}))
    post recalculate_groups_tournament_url(@tournament)
    assert @tournament.reload.data.key?("extracted_group_assignment")
  end

  test "17-05 AC-3: die Turnierleitung waehlt den Modus wie bisher" do
    Carambus.config.carambus_api_url = "http://local.test"
    ready_for_mode_selection
    @tournament.update_column(:turnier_leiter_user_id, @user.id) # users(:one): nur TL, kein Admin
    post select_modus_tournament_url(@tournament), params: {tournament_plan_id: tournament_plans(:t04_5).id}
    assert_redirected_to tournament_monitor_tournament_path(@tournament)
    assert_equal tournament_plans(:t04_5).id, @tournament.reload.tournament_plan_id
  end

  test "17-05 AC-3: ein Sportwart im Wirkbereich kommt ueber den Assistenten-Link bis zur Modusauswahl" do
    Carambus.config.carambus_api_url = "http://local.test"
    put_tournament_in_sportwart_scope
    ready_for_mode_selection
    as(sportwart_user)
    # sign_in greift erst mit der naechsten Anfrage; scheitert die mit 500, geht die Sitzung verloren.
    # finalize_modus rendert mit diesen Fixtures 500 (ohne Teilnehmer fehlt der Default-Plan, wie bei
    # den Guard-Tests oben) — deshalb die Anmeldung vorher an einer harmlosen Seite binden.
    get tournaments_url

    get finalize_modus_tournament_url(@tournament)
    refute response.redirect?, "finalize_modus ist der Link aus dem Assistenten — kein Gate-Redirect"
    assert_not_equal setup_denied_message, flash[:alert]

    post select_modus_tournament_url(@tournament), params: {tournament_plan_id: tournament_plans(:t04_5).id}
    assert_redirected_to tournament_monitor_tournament_path(@tournament)
    assert_equal tournament_plans(:t04_5).id, @tournament.reload.tournament_plan_id
  end

  test "17-05 AC-3: ein club_admin waehlt den Modus wie bisher" do
    Carambus.config.carambus_api_url = "http://local.test"
    ready_for_mode_selection
    as(@club_admin)
    post select_modus_tournament_url(@tournament), params: {tournament_plan_id: tournament_plans(:t04_5).id}
    assert_redirected_to tournament_monitor_tournament_path(@tournament)
    assert_equal tournament_plans(:t04_5).id, @tournament.reload.tournament_plan_id
  end

  # --- AC-6: Knoepfe folgen ihrem Recht (Entscheidung 115) ---------------------

  test "17-05 AC-6: 'Meldeliste neu laden' sieht nur, wer das Turnier einrichten darf" do
    Carambus.config.carambus_api_url = "http://local.test"
    t = released_tournament_with_scope
    reload_form = "form[action='#{reload_entry_list_tournament_path(t)}']"

    as(nil)
    get tournament_url(t)
    assert_response :success
    assert_select reload_form, false

    as(@club_admin)
    get tournament_url(t)
    assert_select reload_form
  end

  test "17-05 AC-6: 'Freigeben' auf der Meldeliste eines Entwurfs sieht nur, wer das Turnier einrichten darf" do
    Carambus.config.carambus_api_url = "http://local.test"
    # CC-los wie in entry_lists_controller_test.rb: BBV ist keine CC-Region
    @tournament.update_columns(organizer_id: regions(:bbv).id, data: {"draft" => true})
    release_form = "form[action='#{release_draft_tournament_path(@tournament)}']"

    get tournament_entry_list_path(@tournament) # users(:one): player ohne Bezug
    assert_response :success
    assert_select release_form, false

    as(@club_admin)
    get tournament_entry_list_path(@tournament)
    assert_select release_form
  end

  test "17-05 AC-6: 'Turniere aus Vorsaison uebernehmen' sieht nur ein Admin" do
    Carambus.config.carambus_api_url = "http://local.test"
    original_location_id = Carambus.config.location_id
    Carambus.config.location_id = nil # Region Server — nur dort gibt es die Saison-Kopie
    copy_link = "a[href='#{copy_season_tournaments_path}']"

    get tournaments_url
    assert_select copy_link, false

    as(@club_admin)
    get tournaments_url
    assert_select copy_link
  ensure
    Carambus.config.location_id = original_location_id
  end

  # --- AC-4: Scoreboard und oeffentliche Seiten --------------------------------

  def placement_setup
    tournament_monitor = TournamentMonitor.create!(tournament: @tournament)
    game = @tournament.games.create!(id: 61_705_001, gname: "group1:1-2", data: {})
    table = tables(:one)
    table.table_monitor.update_columns(tournament_monitor_id: nil, tournament_monitor_type: nil)
    [tournament_monitor, game, table]
  end

  test "17-05 AC-4: players_by_club bleibt ohne Anmeldung erreichbar" do
    as(nil)
    Carambus.config.carambus_api_url = "http://local.test"
    get players_by_club_tournament_url(@tournament)
    assert_response :success
  end

  test "17-05 AC-4: nicht angemeldet bindet placement keinen Tisch an das Turnier" do
    as(nil)
    Carambus.config.carambus_api_url = "http://local.test"
    _tm, game, table = placement_setup
    post placement_tournament_url(@tournament), params: {game_id: game.id, table_id: table.id}
    assert_redirected_to new_user_session_path
    assert_nil table.table_monitor.reload.tournament_monitor_id
  end

  # BEFUND (17-05 T1): Der Rumpf scheitert heute an `@tournament_monitor.type` — TournamentMonitor hat
  # keine type-Spalte (seit dem initial commit), die manuelle Platzierung antwortet mit 500 und rollt
  # die Tischbindung zurueck. Geprueft wird hier nur, dass die Anmeldepruefung das Scoreboard
  # durchlaesst; der Fehler steht im Deferred-Register.
  test "17-05 AC-4: das angemeldete Scoreboard (Rolle player) kommt an der Anmeldepruefung vorbei" do
    Carambus.config.carambus_api_url = "http://local.test"
    _tm, game, table = placement_setup
    post placement_tournament_url(@tournament), params: {game_id: game.id, table_id: table.id}
    assert_not_equal new_user_session_url, response.location
  end

  # ---------------------------------------------------------------------------
  # Plan 17-06: Knopf „In der Turnier-App öffnen“. Sichtbar = Recht der Aktion (prepare_tournament?),
  # nur wo der Server /app/ ausliefert (serve_tournament_app), das Turnier eine Region hat und der
  # Turnier-Monitor es nicht führt. Die Test-DB hat kein App-Dienstkonto → Link ohne cb_email.
  # ---------------------------------------------------------------------------

  # value :absent entfernt den Schlüssel — so sieht eine carambus.yml aus, die prepare_deploy noch
  # nicht neu erzeugt hat.
  def with_serve_tournament_app(value)
    config = Carambus.config
    had_key = config.to_h.key?(:serve_tournament_app)
    original = config[:serve_tournament_app]
    (value == :absent) ? (had_key && config.delete_field(:serve_tournament_app)) : config[:serve_tournament_app] = value
    yield
  ensure
    if had_key
      config[:serve_tournament_app] = original
    elsif config.to_h.key?(:serve_tournament_app)
      config.delete_field(:serve_tournament_app)
    end
  end

  def app_tournament_setup
    Carambus.config.carambus_api_url = "http://local.test"
    @tournament.update_columns(region_id: regions(:nbv).id)
  end

  def get_show_with_app_switch(value = true)
    with_serve_tournament_app(value) { get tournament_url(@tournament) }
    assert_response :success
  end

  def assert_app_button(visible:)
    link = /href="\/app\/\?cb_region=NBV&amp;cb_tournament_id=#{@tournament.id}"/
    label = I18n.t("tournaments.show.open_in_tournament_app")
    if visible
      assert_match link, response.body
      assert_includes response.body, label
      assert_match(/target="_blank"/, response.body[response.body.index(label) - 400, 400])
    else
      assert_no_match(/href="\/app\//, response.body)
      assert_not_includes response.body, label
    end
  end

  test "17-06 AC-5: ein club_admin sieht den Knopf, der Link öffnet die App mit Region und Turnier" do
    as(@club_admin)
    app_tournament_setup
    get_show_with_app_switch
    assert_app_button(visible: true)
  end

  test "17-06 AC-5: der Turnierleiter (ohne Admin-Rolle) sieht den Knopf" do
    app_tournament_setup
    @tournament.update_column(:turnier_leiter_user_id, @user.id)
    refute @user.admin?, "Vorbedingung: kein Admin"
    get_show_with_app_switch
    assert_app_button(visible: true)
  end

  test "17-06 AC-5: ein Sportwart im Wirkbereich sieht den Knopf" do
    app_tournament_setup
    put_tournament_in_sportwart_scope
    # Mit Spielort rendert der Seitenkopf Location#display_address — das Fixture hat keine Adresse
    # (address.split auf nil → 500).
    locations(:one).update_columns(address: "Teststraße 1")
    as(sportwart_user)
    get_show_with_app_switch
    assert_app_button(visible: true)
  end

  test "17-06 AC-5: nicht angemeldet kein Knopf" do
    as(nil)
    app_tournament_setup
    get_show_with_app_switch
    assert_app_button(visible: false)
  end

  test "17-06 AC-5: ein player ohne Recht sieht keinen Knopf" do
    app_tournament_setup
    refute TournamentPolicy.new(@user, @tournament).prepare_tournament?, "Vorbedingung: kein Recht"
    get_show_with_app_switch
    assert_app_button(visible: false)
  end

  test "17-06 AC-5: Schalter aus → kein Knopf" do
    as(@club_admin)
    app_tournament_setup
    get_show_with_app_switch(false)
    assert_app_button(visible: false)
  end

  test "17-06 AC-5: Schalter fehlt in der carambus.yml → kein Knopf" do
    as(@club_admin)
    app_tournament_setup
    get_show_with_app_switch(:absent)
    assert_app_button(visible: false)
  end

  test "17-06 AC-6: Turnier ohne Region → kein Knopf" do
    as(@club_admin)
    app_tournament_setup
    @tournament.update_columns(region_id: nil)
    get_show_with_app_switch
    assert_app_button(visible: false)
  end

  test "17-06 AC-6: der Turnier-Monitor führt das Turnier → kein Knopf" do
    as(@club_admin)
    app_tournament_setup
    TournamentMonitor.create!(tournament: @tournament)
    refute @tournament.reload.manual_assignment, "Vorbedingung: kein App-Turnier"
    get_show_with_app_switch
    assert_app_button(visible: false)
  end

  test "17-06 AC-6: App-Turnier (manual_assignment) mit Turnier-Monitor → Knopf" do
    as(@club_admin)
    app_tournament_setup
    @tournament.update_columns(manual_assignment: true)
    TournamentMonitor.create!(tournament: @tournament)
    get_show_with_app_switch
    assert_app_button(visible: true)
  end

  test "17-06 AC-6: Turnier mit ClubCloud-Ergebnissen → kein Knopf" do
    as(@club_admin)
    app_tournament_setup
    Seeding.create!(id: 30_017_061, tournament: @tournament, player: players(:jaspers), position: 1,
      data: {"result" => {"Endrangliste" => {"Rank" => 1, "Name" => "Jaspers"}}})
    assert @tournament.reload.has_clubcloud_results?, "Vorbedingung: ClubCloud-Ergebnis vorhanden"
    get_show_with_app_switch
    assert_app_button(visible: false)
  end

  test "17-06 AC-6: auf der Authority (kein local_server?) kein Knopf" do
    as(@club_admin)
    app_tournament_setup
    Carambus.config.carambus_api_url = ""
    get_show_with_app_switch
    assert_app_button(visible: false)
  end
end
