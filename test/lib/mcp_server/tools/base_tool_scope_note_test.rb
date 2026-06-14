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
    @user.persona_grants = ["sportwart"]
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
    @user.persona_grants = ["landessportwart"]
    t = Tournament.new(location_id: @location.id, discipline_id: @cadre.id)
    assert_nil note_for(t, user_id: @user.id), "leerer Disziplin-Scope = alle Disziplinen → kein Hinweis"
  end

  test "Turnier-Disziplin IM Wirkbereich (direkt) → nil" do
    @user.persona_grants = ["sportwart"]
    @user.sportwart_disciplines << @kegel
    t = Tournament.new(location_id: @location.id, discipline_id: @kegel.id)
    assert_nil note_for(t, user_id: @user.id)
  end

  test "Turnier-Sub-Disziplin IM Wirkbereich (root_chain deckt ab) → nil" do
    @user.persona_grants = ["landessportwart"]
    @user.sportwart_disciplines << @karambol
    t = Tournament.new(location_id: @location.id, discipline_id: @cadre.id)
    assert_nil note_for(t, user_id: @user.id), "Karambol-Wurzel deckt Cadre via root_chain ab"
  end

  test "HaJo-Fall: Kegel-Sportwart öffnet Karambol-Cadre-Turnier → führender Scope-Hinweis" do
    @user.persona_grants = ["landessportwart"]
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
    @user.persona_grants = ["sportwart"]
    @user.sportwart_disciplines << @kegel
    # Disziplin-Hinweis ist location-unabhängig (bewusst nur Disziplin, vgl. Helper-Doku).
    t = Tournament.new(location_id: 99_999_999, discipline_id: @karambol.id)
    refute_nil note_for(t, user_id: @user.id)
  end
end
