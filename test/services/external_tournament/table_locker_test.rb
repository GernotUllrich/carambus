# frozen_string_literal: true

require "test_helper"

# Plan 17-02: TableLocker — App belegt Tisch fuer ihr Turnier. Der Lock IST die
# TournamentMonitor-Bindung (table_monitor.tournament_monitor_id) + Aufnahme in data[table_ids].
# Kein eigenes Flag (siehe Refactor 2026-05-20: locked_for_tournament entfernt zugunsten der Bindung).
module ExternalTournament
  class TableLockerTest < ActiveSupport::TestCase
    setup do
      @nbv = regions(:nbv)
      @location = locations(:one)
      @tournament = LocalTournamentCreator.new(region: @nbv, payload: {
        external_id: "app-lock-1", title: "Lock Cup", location: {id: @location.id}
      }).call.tournament

      @monitor = TableMonitor.create!(state: "ready", data: {})
      @table = tables(:one)
      @table.update_columns(table_monitor_id: @monitor.id)
    end

    teardown do
      %w[app-lock-1 app-lock-other].each do |ext|
        Tournament.where(region_id: @nbv.id, external_id: ext).each do |t|
          t.tournament_monitor&.destroy
          t.destroy
        end
      end
      @table&.update_columns(table_monitor_id: nil)
      @monitor&.destroy
    end

    test "lock bindet TableMonitor an TournamentMonitor + table_ids" do
      result = TableLocker.new(region: @nbv, payload: {
        tournament_id: @tournament.id, table: {id: @table.id}
      }).call

      assert result.locked
      assert_equal @tournament.tournament_monitor.id, @monitor.reload.tournament_monitor_id, "TableMonitor gebunden"
      assert_equal "TournamentMonitor", @monitor.tournament_monitor_type
      assert_includes Array(@tournament.reload.data["table_ids"]), @table.id.to_s
    end

    test "lehnt Tisch ab, der an anderes Turnier gebunden ist (Konflikt)" do
      other = LocalTournamentCreator.new(region: @nbv, payload: {
        external_id: "app-lock-other", location: {id: @location.id}
      }).call.tournament
      @monitor.update!(tournament_monitor_id: other.tournament_monitor.id, tournament_monitor_type: "TournamentMonitor")

      assert_raises(TableLocker::TableConflictError) do
        TableLocker.new(region: @nbv, payload: {tournament_id: @tournament.id, table: {id: @table.id}}).call
      end
    end

    test "unlock loest Bindung + entfernt aus table_ids" do
      TableLocker.new(region: @nbv, payload: {tournament_id: @tournament.id, table: {id: @table.id}}).call
      TableLocker.new(region: @nbv, payload: {tournament_id: @tournament.id, table: {id: @table.id}, lock: false}).call

      assert_nil @monitor.reload.tournament_monitor_id
      assert_not_includes Array(@tournament.reload.data["table_ids"]), @table.id.to_s
    end
  end
end
