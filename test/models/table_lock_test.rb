# frozen_string_literal: true

require "test_helper"

# Phase 17 / 17-01: Tisch-Lock fuer Turnierbetrieb (locked_for_tournament) + Scoreboard-Sperre.
# Deckt AC-1 (locked_for_tournament persistiert LOCAL_METHODS-konform) und AC-2/AC-4
# (locked_scoreboard folgt dem Lock) auf Model-Ebene ab. NICHT die Google-Calendar-"Reservierung".
class TableLockTest < ActiveSupport::TestCase
  # AC-1: lokaler Tisch (id >= MIN_ID) persistiert locked_for_tournament direkt auf der tables-Spalte
  test "locked_for_tournament? default false und toggelbar auf lokalem Tisch" do
    table = tables(:one) # id 50_000_001 >= MIN_ID
    assert_not table.locked_for_tournament?, "frischer Tisch ist nicht gesperrt"

    table.update!(locked_for_tournament: true)
    assert tables(:one).reload.locked_for_tournament?, "locked_for_tournament=true persistiert auf lokalem Tisch"

    table.update!(locked_for_tournament: false)
    assert_not tables(:one).reload.locked_for_tournament?
  end

  # AC-1: globaler Tisch (id < MIN_ID) persistiert locked_for_tournament via table_local
  # (LocalProtector-konform) — set_locked_for_tournament! darf KEIN Table#save! ausloesen.
  test "set_locked_for_tournament! auf globalem Tisch laeuft ueber table_local ohne Table#save" do
    global = Table.create!(id: 1234, name: "Global T", location: locations(:one), table_kind_id: 50_000_001)
    assert global.id < Table::MIN_ID
    assert_not global.locked_for_tournament?

    global.set_locked_for_tournament!(true)
    assert global.locked_for_tournament?, "Getter liest locked_for_tournament aus table_local"
    assert global.table_local.present?, "table_local-Row wurde angelegt"
    assert_equal true, global.table_local.locked_for_tournament, "Wert liegt auf table_local"
    assert_not global.read_attribute(:locked_for_tournament), "tables-Spalte selbst bleibt unberuehrt"

    global.set_locked_for_tournament!(false)
    assert_not global.reload.locked_for_tournament?, "Freigabe ueber table_local"
  end

  # AC-2/AC-4: locked_scoreboard folgt dem Lock, unabhaengig vom AASM-State
  test "locked_scoreboard true bei gesperrtem Tisch unabhaengig vom state" do
    tm = TableMonitor.create!(state: "playing", data: {})
    table = tables(:one)
    table.update!(table_monitor_id: tm.id, locked_for_tournament: false)
    tm.reload

    assert_not tm.locked_scoreboard, "playing + nicht gesperrt => nicht gesperrt"

    table.update!(locked_for_tournament: true)
    tm.reload
    assert tm.locked_scoreboard, "gesperrt => locked_scoreboard trotz state=playing"

    # AC-4: Freigabe hebt die Sperre auf
    table.update!(locked_for_tournament: false)
    tm.reload
    assert_not tm.locked_scoreboard, "Freigabe => Sperre faellt auf state-basierte Logik zurueck"
  end

  # locked_scoreboard ohne zugeordneten Tisch crasht nicht (table&. safe-nav)
  test "locked_scoreboard ohne Tisch ist false" do
    tm = TableMonitor.create!(state: "playing", data: {})
    assert_nil tm.table
    assert_not tm.locked_scoreboard
  end
end
