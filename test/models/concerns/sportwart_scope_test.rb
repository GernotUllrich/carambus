# frozen_string_literal: true

require "test_helper"

# D-14-G5 + D-38: Tests für SportwartScope-Concern.
# D-38: Mitgliedschaft EXPLIZIT via persona_grants; landessportwart = ALLE Locations;
# plain sportwart = explizite Locations (leer ⇒ kein Scope); Disziplin hierarchie-bewusst (root_chain).
class SportwartScopeTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "sportwart_scope@test.de", password: "password123")
    @location_one = locations(:one)
    @disc_3band = disciplines(:carom_3band)
    @disc_pool = disciplines(:pool_8ball)
  end

  test "in_sportwart_scope?(nil) → false" do
    assert_not @user.in_sportwart_scope?(nil)
  end

  test "D-38: ohne persona_grants → false (kein Sportwart), auch mit Joins" do
    @user.sportwart_locations << @location_one
    @user.sportwart_disciplines << @disc_3band
    t = Tournament.new(location_id: @location_one.id, discipline_id: @disc_3band.id)
    assert_not @user.in_sportwart_scope?(t)
  end

  test "plain sportwart + passende Location + passende Disziplin → true" do
    @user.persona_grants = ["sportwart"]
    @user.sportwart_locations << @location_one
    @user.sportwart_disciplines << @disc_3band
    t = Tournament.new(location_id: @location_one.id, discipline_id: @disc_3band.id)
    assert @user.in_sportwart_scope?(t)
  end

  test "plain sportwart + passende Location + falsche Disziplin → false" do
    @user.persona_grants = ["sportwart"]
    @user.sportwart_locations << @location_one
    @user.sportwart_disciplines << @disc_3band
    t = Tournament.new(location_id: @location_one.id, discipline_id: @disc_pool.id)
    assert_not @user.in_sportwart_scope?(t)
  end

  test "plain sportwart + Location, KEINE Disziplinen → alle Disziplinen an dieser Location" do
    @user.persona_grants = ["sportwart"]
    @user.sportwart_locations << @location_one
    t = Tournament.new(location_id: @location_one.id, discipline_id: @disc_pool.id)
    assert @user.in_sportwart_scope?(t)
  end

  test "D-38 SICHERHEIT: plain sportwart + LEERE Locations → false (kein versehentliches alle)" do
    @user.persona_grants = ["sportwart"]
    @user.sportwart_disciplines << @disc_3band
    t = Tournament.new(location_id: @location_one.id, discipline_id: @disc_3band.id)
    assert_not @user.in_sportwart_scope?(t)
  end

  test "plain sportwart: Tournament außerhalb der Location-Liste → false" do
    @user.persona_grants = ["sportwart"]
    @user.sportwart_locations << @location_one
    t = Tournament.new(location_id: 99_999_999, discipline_id: @disc_3band.id)
    assert_not @user.in_sportwart_scope?(t)
  end

  test "landessportwart: ALLE Locations (Location-Liste irrelevant) → true" do
    @user.persona_grants = ["landessportwart"]
    t = Tournament.new(location_id: 99_999_999, discipline_id: @disc_3band.id)
    assert @user.in_sportwart_scope?(t)
  end

  # D-38 / verschoben aus discipline_permission_test: HIERARCHIE — Wurzel-Disziplin deckt Subs via root_chain.
  test "landessportwart + Wurzel-Disziplin → deckt Sub-Disziplin (root_chain) ab" do
    root = Discipline.create!(name: "SS-Karambol")
    mid = Discipline.create!(name: "SS-Dreiband", super_discipline: root)
    leaf = Discipline.create!(name: "SS-Dreiband-groß", super_discipline: mid)
    @user.persona_grants = ["landessportwart"]
    @user.sportwart_disciplines << root
    t = Tournament.new(location_id: @location_one.id, discipline_id: leaf.id)
    assert @user.in_sportwart_scope?(t), "Wurzel-Disziplin muss Sub-Disziplin via root_chain abdecken"
  ensure
    [leaf, mid, root].compact.each(&:destroy)
  end

  test "landessportwart + Disziplin aus anderer Hierarchie → false" do
    @user.persona_grants = ["landessportwart"]
    @user.sportwart_disciplines << @disc_3band
    t = Tournament.new(location_id: @location_one.id, discipline_id: @disc_pool.id)
    assert_not @user.in_sportwart_scope?(t)
  end
end
