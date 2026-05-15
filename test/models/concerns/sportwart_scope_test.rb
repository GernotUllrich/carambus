# frozen_string_literal: true

require "test_helper"

# D-14-G5: Tests für SportwartScope-Concern (User-Side).
class SportwartScopeTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "sportwart_scope@test.de", password: "password123")
    @location_one = locations(:one)
    @disc_3band = disciplines(:carom_3band)
    @disc_pool = disciplines(:pool_8ball)
  end

  test "in_sportwart_scope?(nil) gibt false zurück" do
    assert_not @user.in_sportwart_scope?(nil)
  end

  test "leere Wirkbereichs-Listen → false (kein Sportwart)" do
    t = Tournament.new(location_id: @location_one.id, discipline_id: @disc_3band.id)
    assert_not @user.in_sportwart_scope?(t)
  end

  test "passende Location + passende Disziplin → true" do
    @user.sportwart_locations << @location_one
    @user.sportwart_disciplines << @disc_3band
    t = Tournament.new(location_id: @location_one.id, discipline_id: @disc_3band.id)
    assert @user.in_sportwart_scope?(t)
  end

  test "passende Location aber falsche Disziplin → false" do
    @user.sportwart_locations << @location_one
    @user.sportwart_disciplines << @disc_3band
    t = Tournament.new(location_id: @location_one.id, discipline_id: @disc_pool.id)
    assert_not @user.in_sportwart_scope?(t)
  end

  test "nur Locations gepflegt (keine Disziplinen) → alle Disziplinen erlaubt für die Locations" do
    @user.sportwart_locations << @location_one
    t = Tournament.new(location_id: @location_one.id, discipline_id: @disc_pool.id)
    assert @user.in_sportwart_scope?(t)
  end

  test "nur Disziplinen gepflegt (keine Locations) → alle Locations erlaubt für die Disziplinen" do
    @user.sportwart_disciplines << @disc_3band
    t = Tournament.new(location_id: @location_one.id, discipline_id: @disc_3band.id)
    assert @user.in_sportwart_scope?(t)
  end

  test "Tournament außerhalb der Location-Liste → false" do
    @user.sportwart_locations << @location_one
    t = Tournament.new(location_id: 99_999_999, discipline_id: @disc_3band.id)
    assert_not @user.in_sportwart_scope?(t)
  end
end
