# frozen_string_literal: true

require "test_helper"

class GamePlansControllerTest < ActionDispatch::IntegrationTest
  # Plan 19-01: Probe fuer Codeausfuehrung. Wird das data-Feld als Ruby-Code ausgewertet,
  # setzt es diesen Thread-Wert — der Test erkennt die Ausfuehrung, ohne etwas anzurichten.
  CODE_PROBE = "Thread.current[:carambus_game_plan_probe] = 42; {}"

  setup do
    @game_plan = game_plans(:one)
    @admin = users(:admin)
    Thread.current[:carambus_game_plan_probe] = nil
  end

  teardown do
    Thread.current[:carambus_game_plan_probe] = nil
  end

  # `User.scoreboard` liefert in der Testumgebung bewusst nil — das Scoreboard-Konto wird
  # ueber die E-Mail erkannt (wie in calendar_scoreboard_single_month_test.rb).
  def scoreboard_user!
    User.find_by(email: "scoreboard@carambus.de") ||
      User.create!(email: "scoreboard@carambus.de", password: "sb-test-passwort",
        first_name: "Score", last_name: "Board",
        accepted_terms_at: Time.current, accepted_privacy_at: Time.current,
        confirmed_at: Time.current)
  end

  # --- Lesen bleibt oeffentlich -------------------------------------------------------

  test "should get index" do
    get game_plans_url
    assert_response :success
  end

  test "should show game_plan" do
    get game_plan_url(@game_plan)
    assert_response :success
  end

  # --- Admin darf schreiben ----------------------------------------------------------

  test "admin: should get new" do
    sign_in @admin
    get new_game_plan_url
    assert_response :success
  end

  test "admin: should create game_plan" do
    sign_in @admin
    assert_difference("GamePlan.count") do
      post game_plans_url,
        params: {game_plan: {data: {"a" => 1}.to_json, footprint: @game_plan.footprint, name: "neu"}}
    end

    assert_redirected_to game_plan_url(GamePlan.last)
    assert_equal({"a" => 1}, GamePlan.last.data)
  end

  test "admin: should get edit" do
    sign_in @admin
    get edit_game_plan_url(@game_plan)
    assert_response :success
  end

  test "admin: should update game_plan" do
    sign_in @admin
    patch game_plan_url(@game_plan),
      params: {game_plan: {data: @game_plan.data.to_json, footprint: @game_plan.footprint, name: "geaendert"}}
    assert_redirected_to game_plan_url(@game_plan)
    assert_equal "geaendert", @game_plan.reload.name
  end

  test "admin: should destroy game_plan" do
    sign_in @admin
    assert_difference("GamePlan.count", -1) do
      delete game_plan_url(@game_plan)
    end

    assert_redirected_to game_plans_url
  end

  # --- AC-1: Schreibaktionen ohne Recht werden abgewiesen ------------------------------

  {
    "anonym" => -> {},
    "Spieler" => -> { sign_in users(:player) },
    "Scoreboard-Konto" => -> { sign_in scoreboard_user! }
  }.each do |actor, login|
    test "#{actor}: GET new und edit werden abgewiesen" do
      instance_exec(&login)
      get new_game_plan_url
      assert_redirected_to game_plans_url
      assert_equal I18n.t("game_plans.errors.admin_required"), flash[:alert]
      get edit_game_plan_url(@game_plan)
      assert_redirected_to game_plans_url
    end

    test "#{actor}: POST legt keinen GamePlan an und fuehrt keinen Code aus" do
      instance_exec(&login)
      assert_no_difference("GamePlan.count") do
        # club_id/season_id: sonst griffe die Ausnahme guest_player_creation? aus admin_only_check
        # gar nicht erst — das Gate muss auch mit ihnen halten.
        post game_plans_url, params: {club_id: 1, season_id: 1,
                                      game_plan: {data: CODE_PROBE, name: "fremd"}}
      end
      assert_redirected_to game_plans_url
      assert_nil Thread.current[:carambus_game_plan_probe]
    end

    test "#{actor}: PATCH aendert nichts und fuehrt keinen Code aus" do
      instance_exec(&login)
      patch game_plan_url(@game_plan), params: {club_id: 1, season_id: 1,
                                                game_plan: {data: CODE_PROBE, name: "fremd"}}
      assert_redirected_to game_plans_url
      assert_nil Thread.current[:carambus_game_plan_probe], "data wurde als Ruby-Code ausgefuehrt"
      assert_equal "MyString", @game_plan.reload.name
    end

    test "#{actor}: DELETE loescht nichts" do
      instance_exec(&login)
      assert_no_difference("GamePlan.count") do
        delete game_plan_url(@game_plan), params: {club_id: 1, season_id: 1}
      end
      assert_redirected_to game_plans_url
    end
  end

  # --- AC-2: auch ein Admin kann ueber data keinen Code ausfuehren ----------------------

  test "admin: PATCH mit Ruby-Code in data wird nicht ausgefuehrt und abgewiesen" do
    sign_in @admin
    patch game_plan_url(@game_plan), params: {game_plan: {data: CODE_PROBE, name: "geaendert"}}
    assert_nil Thread.current[:carambus_game_plan_probe], "data wurde als Ruby-Code ausgefuehrt"
    assert_response :unprocessable_entity
    assert_equal "MyString", @game_plan.reload.name
  end

  test "admin: POST mit Ruby-Code in data wird nicht ausgefuehrt und abgewiesen" do
    sign_in @admin
    assert_no_difference("GamePlan.count") do
      post game_plans_url, params: {game_plan: {data: CODE_PROBE, name: "neu"}}
    end
    assert_nil Thread.current[:carambus_game_plan_probe], "data wurde als Ruby-Code ausgefuehrt"
    assert_response :unprocessable_entity
  end

  # --- AC-3: gueltiges JSON wird uebernommen (auch null, das eval nicht verstand) -------

  test "admin: PATCH uebernimmt gueltiges JSON mit null, true und Verschachtelung" do
    sign_in @admin
    json = '{"a": null, "b": true, "c": {"win": 2, "lost": 0}, "d": [1, 2]}'
    patch game_plan_url(@game_plan), params: {game_plan: {data: json, name: "geaendert"}}
    assert_redirected_to game_plan_url(@game_plan)
    assert_equal({"a" => nil, "b" => true, "c" => {"win" => 2, "lost" => 0}, "d" => [1, 2]},
      @game_plan.reload.data)
  end

  # --- AC-4: Knoepfe folgen dem Recht ---------------------------------------------------

  test "Nicht-Admin sieht weder New noch Edit" do
    sign_in users(:player)
    get game_plans_url
    assert_select "a[href=?]", new_game_plan_path, count: 0
    get game_plan_url(@game_plan)
    assert_select "a[href=?]", edit_game_plan_path(@game_plan), count: 0
  end

  test "Admin sieht New und Edit" do
    sign_in @admin
    get game_plans_url
    assert_select "a[href=?]", new_game_plan_path
    get game_plan_url(@game_plan)
    assert_select "a[href=?]", edit_game_plan_path(@game_plan)
  end
end
