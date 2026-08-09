# frozen_string_literal: true

require "test_helper"

class Umb::PdfParser::PlayerListParserTest < ActiveSupport::TestCase
  # ACHTUNG: umb_player_list.txt ist SYNTHETISCH — passend zum urspruenglichen
  # Pattern gebaut, nicht aus einem echten PDF gezogen. Genau deshalb blieben die
  # Tests gruen, waehrend der Parser an echten UMB-PDFs durchgaengig 0 Spieler
  # lieferte. Die beiden Fixtures darunter sind echte Auszuege; neue Faelle
  # bitte dort ergaenzen.
  FIXTURE_PATH = Rails.root.join("test/fixtures/files/umb_player_list.txt")
  # Echter Auszug, UMB-Seite Stand 2026 (WM Artistique Ankara, ID 400):
  # Spalten "Country | Confed. | Registered as".
  FIXTURE_2026 = Rails.root.join("test/fixtures/files/umb_player_list_2026.txt")
  # Echter Auszug aus dem Archiv (Medellin World Cup 2013, ID 50):
  # Spalten "Nat | Ranking Pos | Ranking Pts | Status".
  FIXTURE_LEGACY = Rails.root.join("test/fixtures/files/umb_player_list_legacy.txt")
  # Echter Auszug einer Junioren-WM (Gradignan 2026, ID 370): ausgeschriebenes
  # Land statt Laendercode, dafuer Geburtsdatum als Spalte.
  FIXTURE_JUNIORS = Rails.root.join("test/fixtures/files/umb_player_list_juniors.txt")

  setup do
    @pdf_text = File.read(FIXTURE_PATH)
  end

  # --- parse: basic structure ---

  test "parse returns an array" do
    result = Umb::PdfParser::PlayerListParser.new(@pdf_text).parse
    assert_instance_of Array, result
  end

  test "parse returns one hash per player line" do
    result = Umb::PdfParser::PlayerListParser.new(@pdf_text).parse
    assert_equal 5, result.size
  end

  test "parse returns hashes with required keys" do
    result = Umb::PdfParser::PlayerListParser.new(@pdf_text).parse
    first = result.first
    assert first.key?(:caps_name), "Expected :caps_name key"
    assert first.key?(:mixed_name), "Expected :mixed_name key"
    assert first.key?(:nationality), "Expected :nationality key"
    assert first.key?(:position), "Expected :position key"
  end

  # --- parse: data values ---

  test "parse extracts position as integer" do
    result = Umb::PdfParser::PlayerListParser.new(@pdf_text).parse
    assert_equal 1, result[0][:position]
    assert_equal 3, result[2][:position]
  end

  test "parse extracts caps_name (all-caps lastname)" do
    result = Umb::PdfParser::PlayerListParser.new(@pdf_text).parse
    assert_equal "JASPERS", result[0][:caps_name]
    assert_equal "CAUDRON", result[1][:caps_name]
  end

  test "parse extracts mixed_name (mixed-case firstname)" do
    result = Umb::PdfParser::PlayerListParser.new(@pdf_text).parse
    assert_equal "Dick", result[0][:mixed_name]
    assert_equal "Frederic", result[1][:mixed_name]
  end

  test "parse extracts nationality as string" do
    result = Umb::PdfParser::PlayerListParser.new(@pdf_text).parse
    assert_equal "NL", result[0][:nationality]
    assert_equal "BE", result[1][:nationality]
    assert_equal "KR", result[3][:nationality]
  end

  # --- parse: edge cases ---

  test "parse returns empty array for nil input" do
    result = Umb::PdfParser::PlayerListParser.new(nil).parse
    assert_equal [], result
  end

  test "parse returns empty array for empty string" do
    result = Umb::PdfParser::PlayerListParser.new("").parse
    assert_equal [], result
  end

  test "parse skips header lines" do
    result = Umb::PdfParser::PlayerListParser.new(@pdf_text).parse
    # No result should have nil position (header lines have no position number)
    result.each do |entry|
      assert_not_nil entry[:position], "Header lines must be skipped"
    end
  end

  test "parse skips malformed lines without crashing" do
    malformed = "1   JASPERS Dick   NL   1   480   0106   Confirmed\nNot a player line\n2   CAUDRON Frederic   BE   2   456   0215   Confirmed\n"
    result = Umb::PdfParser::PlayerListParser.new(malformed).parse
    assert_operator result.size, :>=, 2
  end

  # --- echte UMB-Formate ------------------------------------------------------
  #
  # Hinter dem Laendercode hat die UMB die Spalten mehrfach umgestellt. Das
  # fruehere Pattern verlangte dort drei Zahlen (RankPos/RankPts/PlayerID) und
  # traf damit KEINES der beiden real vorkommenden Formate.

  test "parse liest das aktuelle Format (Country/Confed./Registered as)" do
    result = Umb::PdfParser::PlayerListParser.new(File.read(FIXTURE_2026)).parse
    assert_operator result.size, :>=, 15, "Auszug enthaelt ~20 Spieler"
    assert_equal({position: 1, caps_name: "DERICKS", mixed_name: "Rene", nationality: "NL"}, result.first)
    assert_equal (1..result.size).to_a, result.map { |p| p[:position] }, "Positionen muessen lueckenlos sein"
  end

  test "parse liest das Archiv-Format (Nat/Ranking Pos/Ranking Pts)" do
    result = Umb::PdfParser::PlayerListParser.new(File.read(FIXTURE_LEGACY)).parse
    assert_operator result.size, :>=, 15
    assert_equal({position: 1, caps_name: "BLOMDAHL", mixed_name: "Torbjorn", nationality: "SE"}, result.first)
  end

  test "parse erkennt Akzente und Umlaute in Namen" do
    result = Umb::PdfParser::PlayerListParser.new(File.read(FIXTURE_LEGACY)).parse
    caudron = result.find { |p| p[:caps_name] == "CAUDRON" }
    assert caudron, "CAUDRON muss gefunden werden — ASCII-Zeichenklassen verlieren 'Frédéric'"
    assert_equal "Frédéric", caudron[:mixed_name]
  end

  test "parse erkennt mehrteilige Nachnamen" do
    result = Umb::PdfParser::PlayerListParser.new(File.read(FIXTURE_2026)).parse
    assert result.any? { |p| p[:caps_name] == "VAN DEN ZEGEL" },
      "mehrteilige Nachnamen wie 'VAN DEN ZEGEL' muessen zusammenbleiben"
  end

  test "parse liest das Junioren-Format (ausgeschriebenes Land + Geburtsdatum)" do
    result = Umb::PdfParser::PlayerListParser.new(File.read(FIXTURE_JUNIORS)).parse
    assert_operator result.size, :>=, 8
    assert_equal({position: 1, caps_name: "SANCHEZ", mixed_name: "Ubaldo", nationality: "Mexico"}, result.first)
  end

  test "parse ignoriert Platzhalter-Zeilen ohne echten Spieler" do
    text = "101      Reserved Local PPPQ-1                CO\n102      Reserved Local PPPQ-2                CO\n"
    assert_equal [], Umb::PdfParser::PlayerListParser.new(text).parse
  end
end
