# frozen_string_literal: true

require "test_helper"

# Phase 17 / 17-01: Tischbezogene Reservierung + Scoreboard-Sperre.
# Deckt AC-1 (reserved persistiert LOCAL_METHODS-konform) und AC-2/AC-4
# (locked_scoreboard folgt der Reservierung) auf Model-Ebene ab.
class TableReservationTest < ActiveSupport::TestCase
  # AC-1: lokaler Tisch (id >= MIN_ID) persistiert reserved direkt auf der tables-Spalte
  test "reserved? default false und toggelbar auf lokalem Tisch" do
    table = tables(:one) # id 50_000_001 >= MIN_ID
    assert_not table.reserved?, "frischer Tisch ist nicht reserviert"

    table.update!(reserved: true)
    assert tables(:one).reload.reserved?, "reserved=true persistiert auf lokalem Tisch"

    table.update!(reserved: false)
    assert_not tables(:one).reload.reserved?
  end

  # AC-1: globaler Tisch (id < MIN_ID) persistiert reserved via table_local (LocalProtector-konform)
  test "reserved auf globalem Tisch laeuft ueber table_local" do
    global = Table.create!(id: 1234, name: "Global T", location: locations(:one), table_kind_id: 50_000_001)
    assert global.id < Table::MIN_ID
    assert_not global.reserved?

    global.reserved = true
    global.reload
    assert global.reserved?, "Getter liest reserved aus table_local"
    assert global.table_local.present?, "table_local-Row wurde angelegt"
    assert_equal true, global.table_local.reserved, "Wert liegt auf table_local, nicht auf tables-Spalte"
  end

  # AC-2/AC-4: locked_scoreboard folgt der Reservierung, unabhaengig vom AASM-State
  test "locked_scoreboard true bei reserviertem Tisch unabhaengig vom state" do
    tm = TableMonitor.create!(state: "playing", data: {})
    table = tables(:one)
    table.update!(table_monitor_id: tm.id, reserved: false)
    tm.reload

    assert_not tm.locked_scoreboard, "playing + nicht reserviert => nicht gesperrt"

    table.update!(reserved: true)
    tm.reload
    assert tm.locked_scoreboard, "reserviert => gesperrt trotz state=playing"

    # AC-4: Freigabe hebt die Sperre auf
    table.update!(reserved: false)
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
