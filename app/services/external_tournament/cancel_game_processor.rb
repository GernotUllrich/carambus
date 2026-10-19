# frozen_string_literal: true

module ExternalTournament
  # Phase 28-01: Ein versehentlich angesetztes App-Spiel zuruecknehmen.
  #
  # Anlass: 23. DBU Grand Prix Biathlon (17./18.10.2026). Ein Spiel war auf dem falschen
  # Tisch angesetzt, und es gab keinen Weg zurueck — weder in der App (`delete
  # state.gameUI[key]` steht allein in `completeGame`, also hinter der Ergebniserfassung)
  # noch in Carambus: `external_result_pending?` blockiert "Partie abbrechen" und
  # `close_match` STILLSCHWEIGEND, solange ein App-Ergebnis nicht abgeholt ist.
  #
  # Dieser Guard ist richtig und bleibt — er verhindert, dass eine Fehlbedienung am
  # Scoreboard ein erfasstes Ergebnis vernichtet. Das bewusste Zuruecknehmen bekommt
  # deshalb einen eigenen Weg mit eigener, engerer Vorbedingung.
  #
  # WARUM EIN ENDPOINT UND NICHT ZWEI AUFRUFE AUS DER APP:
  # `reset_table_monitor` setzt auch `tournament_monitor: nil` (table_monitor.rb) — es gibt
  # den Tisch nicht nur frei, es loest ihn vom Turnier. Der naechste `start_game` liefe dann
  # in TableNotBoundError, also genau in das Symptom, das wir beseitigen. Freigeben und
  # Neubinden muessen in EINER Transaktion passieren; zwei Round-Trips lassen ein Fenster,
  # in dem der Tisch unbunden ist — bei der WLAN-Lage im Saal ein realer Fall.
  class CancelGameProcessor
    include AppGameLookup

    Result = Struct.new(:tournament, :game_external_id, :table, :table_monitor,
      :state, :still_bound, keyword_init: true)

    class TournamentNotFoundError < StandardError; end

    class GameNotFoundError < StandardError
      attr_reader :identifier
      def initialize(identifier)
        @identifier = identifier
        super("Game not found: #{identifier}")
      end
    end

    class TableMonitorNotFoundError < StandardError
      attr_reader :identifier
      def initialize(identifier)
        @identifier = identifier
        super("TableMonitor not found for game #{identifier}")
      end
    end

    # 409: Auf dem Tisch wurde schon gespielt. `detail` nennt den Stand, damit der
    # Turnierleiter am Text erkennt, WARUM es nicht geht — nicht nur, DASS es nicht geht.
    class ScoringRecordedError < StandardError
      attr_reader :state, :detail
      def initialize(state, detail)
        @state = state
        @detail = detail
        super("Scoring already recorded (state: #{state})")
      end
    end

    # Zustaende, aus denen zurueckgenommen werden darf (Betreiber-Festlegung 2026-10-19).
    #
    # BEWUSST NICHT `StartGameProcessor#warmup_state?` — das heisst zwar so, bedeutet aber
    # "start_game muss nichts mehr tun" und schliesst `playing` ein. Hier ist das Gegenteil
    # gemeint: nur die Zustaende, in denen noch nichts passiert ist.
    #
    # `match_shootout` ist dabei, weil dort nur der Anstoss ausgespielt wurde — es geht
    # genauso wenig verloren wie im Warmup. Die Kette nach start_game ist
    # ready -> start_new_match! -> warmup, der frisch angesetzte Tisch steht also immer
    # in `warmup`.
    CANCELLABLE_STATES = %w[warmup warmup_a warmup_b match_shootout].freeze

    def initialize(region:, payload:)
      @region = region
      @payload = payload.is_a?(Hash) ? payload.deep_symbolize_keys : payload
    end

    def call
      tournament = resolve_tournament
      owner = tournament.tournament_monitor
      raise TournamentNotFoundError, "tournament has no tournament_monitor" if owner.blank?

      external_id = @payload.dig(:game, :external_id).to_s
      raise GameNotFoundError, "(missing game.external_id)" if external_id.blank?

      game = find_game(tournament, external_id)
      raise GameNotFoundError, external_id if game.blank?

      tm = game.table_monitor
      raise TableMonitorNotFoundError, external_id if tm.blank?

      table = tm.table
      forced = ActiveModel::Type::Boolean.new.cast(@payload[:force])
      ensure_cancellable!(tm) unless forced

      ActiveRecord::Base.transaction do
        # 1. Tisch freigeben. force: true umgeht external_result_pending? — genau das ist
        #    hier gewollt und durch ensure_cancellable! abgesichert.
        tm.reset_table_monitor(force: true)

        # 2. Bindung wiederherstellen. reset_table_monitor hat sie mitgenommen; ohne diesen
        #    Schritt liefe der naechste start_game in TableNotBoundError.
        tm.reload.update!(tournament_monitor_id: owner.id, tournament_monitor_type: "TournamentMonitor")

        # 3. Game abraeumen (Variante C der Spezifikation). Die external_id ist
        #    deterministisch aus dem Plan-Key abgeleitet; ein zurueckgenommenes und neu
        #    gestartetes Spiel traegt DIESELBE Kennung. Zwei Games damit in der Datenbank
        #    sind mindestens unuebersichtlich — und ueber tm.prev_game_id im
        #    PartyMonitor-Pfad potenziell ein falscher find_game-Treffer.
        game.game_participations.destroy_all
        game.destroy!
      end

      tm.reload
      Result.new(
        tournament: tournament,
        game_external_id: external_id,
        table: table,
        table_monitor: tm,
        state: tm.state,
        # Aus dem nachgeladenen Record, nicht konstant: Dieser Wert ist das einzige, woran
        # die App merkt, ob sie gleich in einen TableNotBoundError laeuft.
        still_bound: tm.tournament_monitor_id == owner.id
      )
    end

    private

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

    # Zwei Bedingungen, beide muessen gelten.
    def ensure_cancellable!(tm)
      unless CANCELLABLE_STATES.include?(tm.state.to_s)
        raise ScoringRecordedError.new(tm.state, state_detail(tm))
      end
      return if innings_untouched?(tm)

      raise ScoringRecordedError.new(tm.state, scoring_detail(tm))
    end

    # "Keine Aufnahme erfasst" heisst: keine einzige gestossene Aufnahme je Rolle.
    #
    # NICHT ueber die Summe der Baelle pruefen — eine Aufnahme ohne Treffer ist eine
    # gespielte Aufnahme und zaehlt. Die Liste ist nach start_game leer; der Vergleich
    # toleriert zusaetzlich einen fuehrenden 0-Eintrag, weil die Schwesterliste
    # innings_redo_list nachweislich so initialisiert wird (gemessen an den Spieldaten
    # des GP vom 17.10.2026).
    def innings_untouched?(tm)
      data = tm.data.is_a?(Hash) ? tm.data : {}
      %w[playera playerb].all? do |role|
        list = Array(data.dig(role, "innings_list"))
        list.empty? && data.dig(role, "innings").to_i.zero?
      end
    end

    def state_detail(tm)
      I18n.t("external_tournament.cancel_game.state_detail",
        state: tm.state,
        default: "Tisch steht in '#{tm.state}' — zuruecknehmen geht nur vor dem Anstoss.")
    end

    def scoring_detail(tm)
      data = tm.data.is_a?(Hash) ? tm.data : {}
      a = data.dig("playera", "result").to_i
      b = data.dig("playerb", "result").to_i
      innings = data.dig("playera", "innings").to_i
      I18n.t("external_tournament.cancel_game.scoring_detail",
        a: a, b: b, innings: innings,
        default: "Punkte erfasst: #{a}:#{b} in #{innings} Aufnahmen.")
    end
  end
end
