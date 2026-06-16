# frozen_string_literal: true

require "test_helper"

# Phase 40 (D-40-1/D-40-2): rechte-gegatete interne Quellenangabe.
# BaseTool.source_label (bare, für JSON-Felder) + source_note (Prosa-Suffix) + acting_can_write_cc?.
# Die INTERNE Quelle (DB-Abbild / Live-CC) wird NUR Usern mit cc_write_access? genannt;
# read-only User + User-loser Stdio-Pfad (kein server_context[:user_id]) bekommen "".
class McpServer::Tools::BaseToolSourceNoteTest < ActiveSupport::TestCase
  setup do
    @writer = users(:system_admin) # cc_write_access? == true (role: system_admin)
    @reader = users(:player)       # cc_write_access? == false
  end

  test "Fixture-Vorbedingung: writer schreibberechtigt, reader nicht" do
    assert @writer.cc_write_access?, "system_admin-Fixture muss cc_write_access? haben"
    refute @reader.cc_write_access?, "player-Fixture darf KEIN cc_write_access? haben"
  end

  test "acting_can_write_cc? spiegelt cc_write_access? und ist robust gegen fehlenden User" do
    assert McpServer::Tools::BaseTool.acting_can_write_cc?({user_id: @writer.id})
    refute McpServer::Tools::BaseTool.acting_can_write_cc?({user_id: @reader.id})
    refute McpServer::Tools::BaseTool.acting_can_write_cc?({})
    refute McpServer::Tools::BaseTool.acting_can_write_cc?(nil)
    refute McpServer::Tools::BaseTool.acting_can_write_cc?({user_id: -1})
  end

  test "source_label: write-User bekommt die kind-spezifische Quelle" do
    assert_equal "Quelle: Carambus-Datenbank (Abbild der ClubCloud).",
      McpServer::Tools::BaseTool.source_label({user_id: @writer.id}, :db_mirror)
    assert_match(/direkt aus der ClubCloud/,
      McpServer::Tools::BaseTool.source_label({user_id: @writer.id}, :live_cc))
  end

  test "source_label: read-only / Stdio / unbekannte kind => leer" do
    assert_equal "", McpServer::Tools::BaseTool.source_label({user_id: @reader.id}, :db_mirror)
    assert_equal "", McpServer::Tools::BaseTool.source_label({user_id: @reader.id}, :live_cc)
    assert_equal "", McpServer::Tools::BaseTool.source_label(nil, :db_mirror)
    assert_equal "", McpServer::Tools::BaseTool.source_label({}, :db_mirror)
    assert_equal "", McpServer::Tools::BaseTool.source_label({user_id: @writer.id}, :unknown_kind)
  end

  test "source_note: Prosa-Suffix mit führendem Leerzeichen, sonst leer" do
    assert_equal " Quelle: Carambus-Datenbank (Abbild der ClubCloud).",
      McpServer::Tools::BaseTool.source_note({user_id: @writer.id}, :db_mirror)
    assert_equal "", McpServer::Tools::BaseTool.source_note({user_id: @reader.id}, :db_mirror)
    assert_equal "", McpServer::Tools::BaseTool.source_note({user_id: @writer.id}, :unknown_kind)
  end
end
