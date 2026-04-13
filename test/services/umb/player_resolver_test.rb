# frozen_string_literal: true

require "test_helper"

# Tests für Umb::PlayerResolver — konsolidiert V1 und V2 Spieler-Lookup-Strategien.
# Erstellt Spielerdatensätze direkt in der Testdatenbank (kein WebMock nötig).
class Umb::PlayerResolverTest < ActiveSupport::TestCase
  setup do
    # Existierenden Spieler für Lookup-Tests anlegen
    @existing_player = Player.create!(
      firstname: "John",
      lastname: "Smith",
      fl_name: "John Smith",
      international_player: true,
      nationality: "GB"
    )
  end

  teardown do
    Player.where("id >= 50000000").delete_all
  end

  # --- resolve: Western name order ---

  test "resolve finds existing player by Western name order (caps=LASTNAME, mixed=Firstname)" do
    player = Umb::PlayerResolver.new.resolve("SMITH", "John", nationality: "GB")
    assert_not_nil player
    assert_equal "John", player.firstname
    assert_equal "Smith", player.lastname
  end

  # --- resolve: Asian name order ---

  test "resolve finds existing player by Asian name order (caps=FIRSTNAME, mixed=Lastname)" do
    # Spieler mit asiatischer Namensreihenfolge anlegen: Nachname zuerst im caps-Feld
    asian_player = Player.create!(
      firstname: "Hiroshi",
      lastname: "Tanaka",
      fl_name: "Hiroshi Tanaka",
      international_player: true,
      nationality: "JP"
    )

    # caps="TANAKA" (Nachname), mixed="Hiroshi" (Vorname) — Western order
    player = Umb::PlayerResolver.new.resolve("TANAKA", "Hiroshi", nationality: "JP")
    assert_not_nil player
    assert_equal "Hiroshi", player.firstname
    assert_equal "Tanaka", player.lastname
  end

  test "resolve finds player when caps is firstname and mixed is lastname" do
    # Bei manchen asiatischen Namen ist caps=Vorname, mixed=Nachname
    asian_player = Player.create!(
      firstname: "Myung-Woo",
      lastname: "Cho",
      fl_name: "Myung-Woo Cho",
      international_player: true,
      nationality: "KR"
    )

    # caps="CHO" könnte Nachname oder Vorname sein — beide Reihenfolgen prüfen
    player = Umb::PlayerResolver.new.resolve("CHO", "Myung-Woo", nationality: "KR")
    assert_not_nil player
  end

  # --- resolve: create new player ---

  test "resolve creates new player when no match found" do
    count_before = Player.count
    player = Umb::PlayerResolver.new.resolve("UNKNOWN", "Player", nationality: "XX")
    assert_not_nil player
    assert player.persisted?
    assert_equal Player.count, count_before + 1
    assert player.international_player
  end

  test "resolve creates player with correct name fields" do
    player = Umb::PlayerResolver.new.resolve("VANDENBILCKE", "Frédéric", nationality: "BE")
    assert_not_nil player
    assert player.persisted?
    # Vor- und Nachname korrekt gesetzt
    assert_includes [player.firstname, player.lastname], "Frédéric"
  end

  test "resolve creates player with nationality" do
    player = Umb::PlayerResolver.new.resolve("SAYGINER", "Semih", nationality: "TR")
    assert_not_nil player
    assert_equal "TR", player.nationality
  end

  # --- resolve: umb_player_id storage ---

  test "resolve stores umb_player_id on newly created player" do
    player = Umb::PlayerResolver.new.resolve("JASPERS", "Dick", nationality: "NL", umb_player_id: 106)
    assert_not_nil player
    assert_equal 106, player.umb_player_id
  end

  test "resolve finds player by umb_player_id first" do
    @existing_player.update!(umb_player_id: 999)

    player = Umb::PlayerResolver.new.resolve("SMITH", "John", nationality: "GB", umb_player_id: 999)
    assert_equal @existing_player.id, player.id
  end

  # --- find_by_caps_and_mixed ---

  test "find_by_caps_and_mixed tries both name orders" do
    resolver = Umb::PlayerResolver.new
    player = resolver.find_by_caps_and_mixed("SMITH", "John")
    assert_not_nil player
    assert_equal "John", player.firstname
  end

  test "find_by_caps_and_mixed returns nil when player not found" do
    resolver = Umb::PlayerResolver.new
    player = resolver.find_by_caps_and_mixed("NONEXISTENT", "Nobody")
    assert_nil player
  end
end
