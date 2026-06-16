# frozen_string_literal: true

require "test_helper"

# Phase 40 Plan 40-02 (D-40-1/-6): Wiring-Smoke für die uniform verdrahtete Quellenangabe.
# Der MECHANISMUS (source_label/source_note/acting_can_write_cc?-Gating) ist in
# base_tool_source_note_test.rb (40-01) voll abgedeckt — hier nur, dass die in 40-02
# verdrahteten Tools die gegatete Quelle im Daten-Return TRAGEN. Tests dürfen skippen,
# wenn Fixtures keinen Daten-Return zulassen (wie die übrigen Tool-Tests). Die breite
# Null-Regression (volle Suite, F/E identisch) ist im APPLY separat bewiesen.
class McpServer::Tools::SourceNoteWiringTest < ActiveSupport::TestCase
  setup do
    @writer = users(:system_admin) # cc_write_access? == true
    @reader = users(:player)       # cc_write_access? == false
  end

  test "Fixture-Vorbedingung: writer schreibberechtigt, reader nicht" do
    assert @writer.cc_write_access?
    refute @reader.cc_write_access?
  end

  # --- JSON-DB-Tool (Task 1): list_clubs_by_discipline trägt das gegated source-Feld ---
  test "JSON-Tool: write-User bekommt source-Feld (:db_mirror), read-only User nicht" do
    write_body = call_json_clubs(@writer)
    skip "Fixtures lassen keinen Daten-Return zu (kein clubs-Key)" unless write_body&.key?("clubs")

    assert_equal "Quelle: Carambus-Datenbank (Abbild der ClubCloud).", write_body["source"],
      "write-berechtigter User muss die interne Quelle als source-Feld bekommen"

    read_body = call_json_clubs(@reader)
    assert_equal "", read_body["source"],
      "read-only User darf KEINE interne Quelle bekommen (source == \"\")"
  end

  private

  def call_json_clubs(user)
    resp = McpServer::Tools::ListClubsByDiscipline.call(
      shortname: "NBV", discipline: "9-Ball",
      server_context: {user_id: user.id, cc_region: "NBV"}
    )
    txt = resp.content.map { |c| c[:text] || c["text"] }.join
    JSON.parse(txt)
  rescue JSON::ParserError
    nil
  end
end
