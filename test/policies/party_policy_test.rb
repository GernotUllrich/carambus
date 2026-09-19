# frozen_string_literal: true

require "test_helper"

# Plan 20-02: PartyPolicy — Liga-Begegnungen wie Einzelturniere (Betreiber-Vorgabe 2026-09-18).
#   assign_leiter? = Admin ODER Sportwart im Wirkbereich
#   operate?       = dazu der eingesetzte Begegnungsleiter (UserParty)
# Wirkbereich: allein die Disziplin der Liga, das Spiellokal zaehlt nicht (Betreiber-Vorgabe
# 2026-09-19 — erste Fassung band an Spiellokal/Heimverein; Fall Foster, Spieltag 362488).
class PartyPolicyTest < ActiveSupport::TestCase
  setup do
    @location = locations(:one)
    @discipline = disciplines(:carom_3band)
    @league = League.new(discipline: @discipline)

    @sportwart = User.create!(email: "party_sw@test.de", password: "password123", persona_grants: ["sportwart"])
    @sportwart.sportwart_locations << @location
    @sportwart.sportwart_disciplines << @discipline

    @leiter = User.create!(email: "party_leiter@test.de", password: "password123")
    @random = User.create!(email: "party_random@test.de", password: "password123")

    @party = parties(:party_one)
    @party.update_columns(location_id: @location.id)
    @party.league.update_columns(discipline_id: @discipline.id)
  end

  def policy(user, party = @party)
    PartyPolicy.new(user, party)
  end

  test "anonym und fremdes Konto: kein Recht" do
    [nil, @random].each do |user|
      assert_not policy(user).assign_leiter?
      assert_not policy(user).operate?
    end
  end

  test "Admin: beide Rechte" do
    assert policy(users(:club_admin)).assign_leiter?
    assert policy(users(:club_admin)).operate?
  end

  test "Sportwart der Disziplin: beide Rechte" do
    assert policy(@sportwart).assign_leiter?
    assert policy(@sportwart).operate?
  end

  test "Sportwart der Disziplin: auch an fremdem Spiellokal und ohne Spiellokal" do
    @party.update_columns(location_id: 99_999_999)
    assert policy(@sportwart, @party.reload).operate?, "fremdes Spiellokal"
    @party.update_columns(location_id: nil)
    @sportwart.sportwart_locations.destroy_all
    assert policy(@sportwart.reload, @party.reload).operate?, "ohne Spiellokal, Sportwart ohne Spiellokale"
  end

  test "Sportwart einer anderen Disziplin: kein Recht" do
    @sportwart.sportwart_disciplines.destroy_all
    @sportwart.sportwart_disciplines << Discipline.where.not(id: @discipline.root_chain.map(&:id)).first
    assert_not policy(@sportwart.reload).operate?
  end

  test "Sportwart ohne eingetragene Disziplin: alle Disziplinen" do
    @sportwart.sportwart_disciplines.destroy_all
    assert policy(@sportwart.reload).operate?
  end

  test "Landessportwart: wie Sportwart, Disziplin entscheidet" do
    @sportwart.update!(persona_grants: ["landessportwart"])
    assert policy(@sportwart).assign_leiter?
  end

  test "persona_grants leer: trotz gepflegter Disziplinen kein Sportwart" do
    @sportwart.update!(persona_grants: [])
    assert_not policy(@sportwart).operate?
  end

  test "eingesetzter Leiter: bedienen ja, Leiter einsetzen nein" do
    UserParty.create!(user: @leiter, party: @party, granted_by: @sportwart)
    assert @party.leiter?(@leiter)
    assert policy(@leiter).operate?
    assert_not policy(@leiter).assign_leiter?
    assert_not @party.leiter?(@random)
  end
end
