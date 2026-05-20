# frozen_string_literal: true

module ExternalTournament
  # Plan 17-02: App-getriebener Tisch-Lock fuer ein lokales App-Turnier.
  #
  # Die App sperrt selbst die Tische, die sie nutzen will (nach eigener Auslosung etc.):
  #   - setzt table.locked_for_tournament = true (Operator-/Fremdspiel-Sperre, Phase 17-01;
  #     NICHT die Google-Calendar-"Reservierung")
  #   - bindet den TableMonitor an den TournamentMonitor des Turniers
  #   - nimmt die Tisch-ID in tournament.data["table_ids"] auf
  # lock=false kehrt das um (einfache Teil-Freigabe; Voll-Lifecycle/Mitternacht = Slice 5).
  #
  # Konflikt: Ist der TableMonitor bereits an ein ANDERES (Tournament)Monitor gebunden,
  # wird der Lock abgelehnt (TableConflictError -> 422).
  class TableLocker
    Result = Struct.new(:table, :table_monitor, :locked, keyword_init: true)

    class TournamentNotFoundError < StandardError; end

    class TableNotFoundError < StandardError
      attr_reader :identifier
      def initialize(identifier)
        @identifier = identifier
        super("Table not found: #{identifier}")
      end
    end

    class TableConflictError < StandardError
      attr_reader :identifier
      def initialize(identifier)
        @identifier = identifier
        super("Table already in use by another tournament: #{identifier}")
      end
    end

    class TableMonitorNotFoundError < StandardError
      attr_reader :identifier
      def initialize(identifier)
        @identifier = identifier
        super("TableMonitor not found for #{identifier}")
      end
    end

    def initialize(region:, payload:)
      @region = region
      @payload = payload.is_a?(Hash) ? payload.deep_symbolize_keys : payload
    end

    def call
      lock = @payload.key?(:lock) ? !!@payload[:lock] : true
      tournament = resolve_tournament
      owner = tournament.tournament_monitor
      raise TournamentNotFoundError, "tournament has no tournament_monitor" if owner.blank?

      table = resolve_table(tournament)
      monitor = table.table_monitor || table.table_monitor!
      raise TableMonitorNotFoundError, table.name if monitor.blank?

      ActiveRecord::Base.transaction do
        if lock
          raise TableConflictError, table.name if bound_to_other?(monitor, owner)
          # Der Lock IST die TournamentMonitor-Bindung: ein gebundener Tisch erscheint im
          # Location-Scoreboard unter Tournaments + ist nicht mehr fuer Training-Spiele waehlbar
          # (bestehender Carambus-Mechanismus, scoreboard_tables.html.erb: tm.tournament_monitor.present?).
          monitor.update!(tournament_monitor_id: owner.id, tournament_monitor_type: "TournamentMonitor")
          update_table_ids(tournament) { |ids| ids | [table.id.to_s] }
        else
          if monitor.tournament_monitor_id == owner.id && monitor.tournament_monitor_type == "TournamentMonitor"
            monitor.update!(tournament_monitor_id: nil, tournament_monitor_type: nil)
          end
          update_table_ids(tournament) { |ids| ids.reject { |x| x.to_s == table.id.to_s } }
        end
      end

      Result.new(table: table, table_monitor: monitor, locked: lock)
    end

    private

    def bound_to_other?(monitor, owner)
      monitor.tournament_monitor_id.present? &&
        !(monitor.tournament_monitor_id == owner.id && monitor.tournament_monitor_type == "TournamentMonitor")
    end

    def resolve_tournament
      tournament =
        if @payload[:tournament_id].present?
          Tournament.find_by(id: @payload[:tournament_id], region_id: @region.id)
        elsif @payload.dig(:tournament, :external_id).present?
          Tournament.where(region_id: @region.id, external_id: @payload.dig(:tournament, :external_id)).first
        end
      raise TournamentNotFoundError, "tournament not found" if tournament.blank?
      tournament
    end

    def resolve_table(tournament)
      tbl = @payload[:table] || {}
      table =
        if tbl[:id].present?
          Table.find_by(id: tbl[:id])
        elsif tbl[:name].present?
          Table.where(location_id: tournament.location_id).find_by(name: tbl[:name])
        end
      raise TableNotFoundError, (tbl[:id] || tbl[:name]).to_s if table.blank?
      table
    end

    # data["table_ids"] enthaelt Table-IDs als Strings (Format wie t_no_from erwartet:
    # table_id.to_i == table.id). manual_assignment=true laesst die data-Validierung passieren.
    def update_table_ids(tournament)
      data = tournament.data.is_a?(Hash) ? tournament.data.dup : {}
      data["table_ids"] = yield(Array(data["table_ids"]))
      tournament.update!(data: data)
    end
  end
end
