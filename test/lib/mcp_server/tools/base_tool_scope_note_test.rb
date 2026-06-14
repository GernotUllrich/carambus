# frozen_string_literal: true

require "test_helper"

# Strang 2 (LSW-Kegel-Befund 2026-06-14): Tests für BaseTool.discipline_scope_note.
# Soft-Hinweis, wenn ein scoped Sportwart ein Turnier außerhalb seines Disziplin-Wirkbereichs
# aufruft (z.B. HaJo/Kegel öffnet ein Karambol-Turnier). Liefert führenden Hinweistext ODER nil.
# Spiegelt die discipline_match-Logik aus SportwartScope#in_sportwart_scope? (root_chain).
class BaseToolScopeNoteTest < ActiveSupport::TestCase
  setup do
    @location = locations(:one)
    # Zwei getrennte Disziplin-Hierarchien (Karambol-artig vs. Kegel-artig).
    @karambol = Discipline.create!(name: "SN-Karambol")
    @cadre = Discipline.create!(name: "SN-Cadre 35/2", super_discipline: @karambol)
    @kegel = Discipline.create!(name: "SN-Kegel")

    @user = User.create!(email: "scope_note@test.de", password: "password123")
  end

  teardown do
    [@cadre, @karambol, @kegel].compact.each { |d| d.destroy if d.persisted? }
  end

  def note_for(tournament, user_id:)
    McpServer::Tools::BaseTool.discipline_scope_note(
      tournament: tournament,
      server_context: {user_id: user_id}
    )
  end

  test "nil-Tournament → nil" do
    @user.update!(persona_grants: ["sportwart"])
    @user.sportwart_disciplines << @kegel
    assert_nil note_for(nil, user_id: @user.id)
  end

  test "unbekannte user_id → nil (kein Crash)" do
    t = Tournament.new(location_id: @location.id, discipline_id: @cadre.id)
    assert_nil note_for(t, user_id: 999_999_999)
  end

  test "User ist kein Sportwart (kein persona_grant) → nil" do
    t = Tournament.new(location_id: @location.id, discipline_id: @cadre.id)
    assert_nil note_for(t, user_id: @user.id)
  end

  test "Sportwart ohne Disziplin-Scope (leer = alle) → nil" do
    @user.update!(persona_grants: ["landessportwart"])
    t = Tournament.new(location_id: @location.id, discipline_id: @cadre.id)
    assert_nil note_for(t, user_id: @user.id), "leerer Disziplin-Scope = alle Disziplinen → kein Hinweis"
  end

  test "Turnier-Disziplin IM Wirkbereich (direkt) → nil" do
    @user.update!(persona_grants: ["sportwart"])
    @user.sportwart_disciplines << @kegel
    t = Tournament.new(location_id: @location.id, discipline_id: @kegel.id)
    assert_nil note_for(t, user_id: @user.id)
  end

  test "Turnier-Sub-Disziplin IM Wirkbereich (root_chain deckt ab) → nil" do
    @user.update!(persona_grants: ["landessportwart"])
    @user.sportwart_disciplines << @karambol
    t = Tournament.new(location_id: @location.id, discipline_id: @cadre.id)
    assert_nil note_for(t, user_id: @user.id), "Karambol-Wurzel deckt Cadre via root_chain ab"
  end

  test "HaJo-Fall: Kegel-Sportwart öffnet Karambol-Cadre-Turnier → führender Scope-Hinweis" do
    @user.update!(persona_grants: ["landessportwart"])
    @user.sportwart_disciplines << @kegel
    t = Tournament.new(location_id: @location.id, discipline_id: @cadre.id)

    note = note_for(t, user_id: @user.id)
    refute_nil note, "out-of-scope muss einen Hinweis liefern"
    assert_includes note, "SN-Cadre 35/2", "nennt die Turnier-Disziplin"
    assert_includes note, "SN-Karambol", "nennt den Branch (Wurzel der Hierarchie)"
    assert_includes note, "SN-Kegel", "nennt den eigenen Wirkbereich"
    assert_includes note, "nicht zuständig", "macht die Nichtzuständigkeit klar"
    refute_includes note.downcase, "verknüpft", "vermeidet die irreführende Konfig-Narration"
  end

  test "plain sportwart out-of-scope (Location irrelevant für Disziplin-Hinweis) → Hinweis" do
    @user.update!(persona_grants: ["sportwart"])
    @user.sportwart_disciplines << @kegel
    # Disziplin-Hinweis ist location-unabhängig (bewusst nur Disziplin, vgl. Helper-Doku).
    t = Tournament.new(location_id: 99_999_999, discipline_id: @karambol.id)
    refute_nil note_for(t, user_id: @user.id)
  end

  # Issue 3 (Live-Test 2026-06-14): lookup_tournament committed_list_warning. Der Blank-meldeliste-
  # Pfad kehrt VOR dem CC-Client zurück → testbar mit In-Memory-Records (kein Mocking).
  # Out-of-Scope-Sportwart darf NICHT die "Verknüpfung fehlt / LSW informieren"-Eskalation sehen.
  test "lookup_tournament: Out-of-Scope-Sportwart bekommt Scope-Hinweis statt Daten-Lücke" do
    @user.update!(persona_grants: ["landessportwart"])
    @user.sportwart_disciplines << @kegel
    tcc = TournamentCc.new(meldeliste_cc_id: nil)
    tcc.tournament = Tournament.new(location_id: @location.id, discipline_id: @cadre.id)

    meta = {}
    McpServer::Tools::LookupTournament.read_committed_players(
      tournament_cc: tcc, meldeliste_cc_id_override: nil, fed_id: 20, meta: meta,
      server_context: {user_id: @user.id}
    )
    assert_includes meta[:committed_list_warning], "nicht zuständig", "out-of-scope → Scope-Hinweis"
    refute_includes meta[:committed_list_warning].to_s, "Administrator", "keine Eskalations-Narration"
  end

  test "lookup_tournament: ohne User-Kontext sachliche Admin-nicht-verfügbar-Meldung (keine Eskalation)" do
    tcc = TournamentCc.new(meldeliste_cc_id: nil)
    tcc.tournament = Tournament.new(location_id: @location.id, discipline_id: @cadre.id)

    meta = {}
    McpServer::Tools::LookupTournament.read_committed_players(
      tournament_cc: tcc, meldeliste_cc_id_override: nil, fed_id: 20, meta: meta,
      server_context: nil
    )
    assert_includes meta[:committed_list_warning], "Admin-Zugang"
    refute_includes meta[:committed_list_warning].to_s, "informieren", "keine Eskalation an Admin/Info-Stelle"
  end

  # Live-Test 2026-06-14 (User-Direktive „einfacher"): öffentlicher Turnier-Link statt Parser.
  # DB-frei via Struct-Doubles — testet nur die URL-Bauform.
  test "public_tournament_url baut die öffentliche sb_meisterschaft-URL" do
    region = Struct.new(:public_cc_url_base, :region_cc).new("https://www.ndbv.de/", Struct.new(:cc_id).new(20))
    tournament = Struct.new(:organizer_type, :organizer, :season, :tournament_cc).new(
      "Region", region, Struct.new(:name).new("2025/2026"), Struct.new(:cc_id).new(939)
    )
    assert_equal "https://www.ndbv.de/sb_meisterschaft.php?p=20--2025/2026-939----1-100000-",
      McpServer::Tools::BaseTool.public_tournament_url(tournament)
  end

  test "public_tournament_url → nil wenn tournament_cc_id fehlt" do
    region = Struct.new(:public_cc_url_base, :region_cc).new("https://www.ndbv.de/", Struct.new(:cc_id).new(20))
    tournament = Struct.new(:organizer_type, :organizer, :season, :tournament_cc).new(
      "Region", region, Struct.new(:name).new("2025/2026"), Struct.new(:cc_id).new(nil)
    )
    assert_nil McpServer::Tools::BaseTool.public_tournament_url(tournament)
  end

  test "public_tournament_url(nil) → nil" do
    assert_nil McpServer::Tools::BaseTool.public_tournament_url(nil)
  end

  test "public_tournament_url_from baut URL aus expliziten Teilen (Listen-Variante, kein N+1)" do
    assert_equal "https://www.ndbv.de/sb_meisterschaft.php?p=20--2025/2026-939----1-100000-",
      McpServer::Tools::BaseTool.public_tournament_url_from(base: "https://www.ndbv.de/", fed: 20, season: "2025/2026", tcc_id: 939)
  end

  test "public_tournament_url_from → nil bei fehlendem Teil" do
    assert_nil McpServer::Tools::BaseTool.public_tournament_url_from(base: nil, fed: 20, season: "2025/2026", tcc_id: 939)
    assert_nil McpServer::Tools::BaseTool.public_tournament_url_from(base: "https://x/", fed: 20, season: "2025/2026", tcc_id: nil)
  end

  test "public_view_hint hängt Link an, leer wenn nicht baubar" do
    region = Struct.new(:public_cc_url_base, :region_cc).new("https://www.ndbv.de/", Struct.new(:cc_id).new(20))
    tournament = Struct.new(:organizer_type, :organizer, :season, :tournament_cc).new(
      "Region", region, Struct.new(:name).new("2025/2026"), Struct.new(:cc_id).new(939)
    )
    assert_includes McpServer::Tools::BaseTool.public_view_hint(tournament), "Öffentliche Ansicht"
    assert_equal "", McpServer::Tools::BaseTool.public_view_hint(nil)
  end
end
