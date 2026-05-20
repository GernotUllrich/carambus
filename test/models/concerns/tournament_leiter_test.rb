# frozen_string_literal: true

require "test_helper"

# D-14-G4: Tests für TournamentLeiter-Concern (Tournament-Side).
class TournamentLeiterTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "tl_user@test.de", password: "password123")
    @other_user = User.create!(email: "tl_other@test.de", password: "password123")
    @tournament = Tournament.new
  end

  test "leiter?(nil) gibt false zurück" do
    @tournament.turnier_leiter_user_id = @user.id
    assert_not @tournament.leiter?(nil)
  end

  test "kein TL zugewiesen → leiter? false + has_active_leiter? false" do
    @tournament.turnier_leiter_user_id = nil
    assert_not @tournament.leiter?(@user)
    assert_not @tournament.has_active_leiter?
  end

  test "TL zugewiesen, passender User → leiter? true + has_active_leiter? true" do
    @tournament.turnier_leiter_user_id = @user.id
    assert @tournament.leiter?(@user)
    assert @tournament.has_active_leiter?
  end

  test "TL zugewiesen, anderer User → leiter? false aber has_active_leiter? true" do
    @tournament.turnier_leiter_user_id = @user.id
    assert_not @tournament.leiter?(@other_user)
    assert @tournament.has_active_leiter?
  end
end
