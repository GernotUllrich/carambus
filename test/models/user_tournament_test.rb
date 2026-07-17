# frozen_string_literal: true

require "test_helper"

# v1.0 Phase 34-03: Tests für UserTournament (lokale ApiProtector-Relation mit role).
class UserTournamentTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "ut_model@test.de", password: "password123")
    @tournament = tournaments(:local)
  end

  test "Create mit user+tournament speichert; role-Default turnier_leiter" do
    ut = UserTournament.create!(user: @user, tournament: @tournament)
    assert ut.persisted?
    assert_equal "turnier_leiter", ut.role
  end

  test "role-Inklusion: fremde role unzulässig" do
    ut = UserTournament.new(user: @user, tournament: @tournament, role: "schiedsrichter")
    assert_not ut.valid?
    assert ut.errors[:role].any?
  end

  test "Uniqueness (user, tournament, role)" do
    UserTournament.create!(user: @user, tournament: @tournament, role: "turnier_leiter")
    dup = UserTournament.new(user: @user, tournament: @tournament, role: "turnier_leiter")
    assert_not dup.valid?
    assert dup.errors[:user_id].any?
  end

  test "belongs_to user + tournament" do
    ut = UserTournament.create!(user: @user, tournament: @tournament)
    assert_equal @user, ut.user
    assert_equal @tournament, ut.tournament
  end

  # D-39-3 (v1.1): granted_by = einsetzender Sportwart, optional (Legacy + globaler-TL-Pfad ohne granter).
  test "granted_by belongs_to (optional): liefert User; ohne granter valide" do
    sw = User.create!(email: "ut_granter@test.de", password: "password123")
    ut = UserTournament.create!(user: @user, tournament: @tournament, granted_by: sw)
    assert_equal sw, ut.granted_by
    assert_equal sw.id, ut.granted_by_user_id

    other = User.create!(email: "ut_nogranter@test.de", password: "password123")
    no_granter = UserTournament.new(user: other, tournament: @tournament)
    assert no_granter.valid?, "UserTournament ohne granter muss valide sein"
  end
end
