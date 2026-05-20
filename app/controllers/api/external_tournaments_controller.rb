# frozen_string_literal: true

module Api
  # Plan 15-02: External-Tournament-Bridge Seeding-Endpoint (Carambus → 3BandMannschaftsTurnier-App)
  #
  # Liefert carambus.seeding/v1-konformes JSON-Dokument für externe Turnier-Apps
  # (Pilot: 3BandMannschaftsTurnier in /Users/gullrich/2BandTurnier; BC Wedel 3-Band-Mannschaft).
  #
  # Auth: devise-jwt (Bearer-Token aus POST /login eines 2band-bridge-Service-Account-Users
  # wie 2band-nbv-bridge@carambus.de; angelegt via `rake service_accounts:create_2band[NBV]`).
  # D-15-01-A: Service-Account-Pattern analog G.14 (Pattern aus TournamentCcsController).
  #
  # Spec: /Users/gullrich/2BandTurnier/docs/json-schema.md
  # Beispiel: /Users/gullrich/2BandTurnier/docs/examples/seeding-3band-mannschaft.json
  class ExternalTournamentsController < ApplicationController
    before_action :authenticate_user!
    skip_forgery_protection

    # GET /api/external_tournament/seeding?tournament_cc_id=X&region=NBV
    #
    # Response (200):
    #   {
    #     "schema": "carambus.seeding/v1",
    #     "region": { "shortname": "NBV", "url": "https://nbv.carambus.de" },
    #     "tournament": { "cc_id": 12345, "name": "...", "discipline": {...}, "format": {...}, ... },
    #     "teams": [ { "seeding_position": 1, "name": "...", "club": {...}, "players": [...] }, ... ]
    #   }
    #
    # Errors:
    #   - 401 — fehlende/ungültige/revoked JWT
    #   - 404 — tournament_cc_id existiert nicht für die Region
    #   - 422 — region_shortname passt nicht zur Tournament-Region, oder TournamentCc noch nicht verlinkt
    def seeding
      region = Region.find_by!(shortname: params[:region].to_s.upcase)
      tournament_cc = TournamentCc.find_by!(
        cc_id: params[:tournament_cc_id],
        context: region.shortname.downcase
      )

      tournament = tournament_cc.tournament
      if tournament.nil?
        return render json: {error: "Tournament not yet linked"}, status: :unprocessable_entity
      end

      if tournament.region_id != region.id
        return render json: {error: "Region mismatch"}, status: :unprocessable_entity
      end

      render json: build_seeding_payload(tournament, tournament_cc, region)
    rescue ActiveRecord::RecordNotFound => e
      render json: {error: e.message}, status: :not_found
    end

    # POST /api/external_tournament/round_start
    #
    # Body: carambus.round_start/v1-Dokument (siehe /Users/gullrich/2BandTurnier/docs/json-schema.md).
    # Erzeugt pro games[]-Eintrag genau einen Game-Record + GameParticipations + setzt
    # TableMonitor.game_id. Idempotent via Game.data["external_id"].
    #
    # Response (201 / 200 bei Idempotenz):
    #   { "games": [{ "external_id": "...", "game_id": 123, "table_monitor_id": 45 }, ...] }
    #
    # Errors:
    #   - 401 — fehlende/ungültige/revoked JWT
    #   - 404 — TournamentCc / Region nicht gefunden
    #   - 422 — Region-Mismatch / Player nicht resolved / TableMonitor nicht gefunden
    def round_start
      payload = round_start_params.to_h.deep_symbolize_keys
      region = Region.find_by!(shortname: payload.dig(:region, :shortname).to_s.upcase)
      tournament_cc = TournamentCc.find_by!(
        cc_id: payload.dig(:tournament, :cc_id),
        context: region.shortname.downcase
      )

      tournament = tournament_cc.tournament
      if tournament.nil?
        return render json: {error: "Tournament not yet linked"}, status: :unprocessable_entity
      end

      if tournament.region_id != region.id
        return render json: {error: "Region mismatch"}, status: :unprocessable_entity
      end

      result = ExternalTournament::RoundStartProcessor.new(
        tournament: tournament,
        region: region,
        payload: payload
      ).call

      render json: {games: result.games}, status: result.created_any? ? :created : :ok
    rescue ActiveRecord::RecordNotFound => e
      render json: {error: e.message}, status: :not_found
    rescue ExternalTournament::RoundStartProcessor::PlayerResolutionError => e
      render json: {error: "Player not resolved", participant: e.participant}, status: :unprocessable_entity
    rescue ExternalTournament::RoundStartProcessor::TableNotFoundError => e
      render json: {error: "Table not found: #{e.identifier}"}, status: :unprocessable_entity
    rescue ExternalTournament::RoundStartProcessor::TableMonitorNotFoundError => e
      render json: {error: "TableMonitor not found for #{e.identifier}"}, status: :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => e
      render json: {error: e.message}, status: :unprocessable_entity
    end

    # GET /api/external_tournament/round_result?tournament_cc_id=X&round_no=N&region=NBV
    #
    # Aggregiert alle Games der angegebenen Runde zu einem carambus.round_result/v1-Doc.
    # Read-only Endpoint (keine DB-Writes).
    #
    # Response (200): carambus.round_result/v1-JSON mit results[]-Array (kann leer sein).
    #
    # Errors:
    #   - 401 — fehlende/ungültige JWT
    #   - 404 — TournamentCc / Region nicht gefunden
    #   - 422 — Region-Mismatch / round_no fehlt oder nicht numerisch
    def round_result
      region = Region.find_by!(shortname: params[:region].to_s.upcase)
      tournament_cc = TournamentCc.find_by!(
        cc_id: params[:tournament_cc_id],
        context: region.shortname.downcase
      )

      tournament = tournament_cc.tournament
      if tournament.nil?
        return render json: {error: "Tournament not yet linked"}, status: :unprocessable_entity
      end
      if tournament.region_id != region.id
        return render json: {error: "Region mismatch"}, status: :unprocessable_entity
      end

      round_no = parse_round_no(params[:round_no])
      if round_no.nil?
        return render json: {error: "round_no is required and must be numeric"}, status: :unprocessable_entity
      end

      payload = ExternalTournament::RoundResultAggregator.new(
        tournament: tournament,
        tournament_cc: tournament_cc,
        region: region,
        round_no: round_no
      ).call

      render json: payload
    rescue ActiveRecord::RecordNotFound => e
      render json: {error: e.message}, status: :not_found
    end

    # GET /api/external_tournament/tables?location_id=X&region=NBV
    #   alternativ: ?location_cc_id=11&region=NBV
    #
    # Plan 15-06 (R1): Read-only Discovery-Endpoint. Liefert die echten Table#name-Strings
    # einer Location, damit externe Apps die Tisch-Namen nicht raten müssen
    # (D-15-06-A: Table-Namen sind beliebige Strings wie "Tisch 5"/"Gr. Tisch 1", keine Nummern).
    #
    # Response (200): carambus.tables/v1
    #   { "schema": "carambus.tables/v1", "region": {...}, "location": {id, cc_id, name},
    #     "tables": [{ "name": "Tisch 5", "table_kind": "Small Billard", "has_monitor": true }, ...] }
    #
    # Errors:
    #   - 401 — fehlende/ungültige JWT
    #   - 404 — Region/Location nicht gefunden
    def tables
      region = Region.find_by!(shortname: params[:region].to_s.upcase)
      location = resolve_location(params, region)
      return render json: {error: "Location not found"}, status: :not_found unless location

      render json: {
        schema: "carambus.tables/v1",
        region: {shortname: region.shortname},
        location: {id: location.id, cc_id: location.cc_id, name: location.name},
        tables: location.tables.includes(:table_kind, :table_monitor).sort_by { |t| t.name.to_s }.map do |t|
          {
            name: t.name,
            table_kind: t.table_kind&.name,
            has_monitor: t.read_attribute(:table_monitor_id).present?,
            # Plan 17-02: Verfuegbarkeit — Tisch ist fuer den Turnierbetrieb belegt, wenn sein
            # TableMonitor an einen TournamentMonitor gebunden ist (bestehender Carambus-Mechanismus).
            in_tournament: t.table_monitor&.tournament_monitor_id.present? || false
          }
        end
      }
    rescue ActiveRecord::RecordNotFound => e
      render json: {error: e.message}, status: :not_found
    end

    # POST /api/external_tournament/tournament
    #
    # Plan 17-02: Legt ein lokales App-Turnier OHNE TournamentPlan/Executor an (D-17-vision-1).
    # Idempotent via external_id (region-scoped). Erzeugt einen schlanken TournamentMonitor.
    #
    # Body: { region:{shortname}, location:{id|cc_id}(optional), title, discipline:{name}(optional),
    #         external_id }
    # Response (201 / 200 idempotent): carambus.tournament/v1
    #   { schema, region:{shortname}, tournament:{ id, external_id, tournament_monitor_id, title, location_id } }
    #
    # Errors: 401 (Auth) / 404 (Region) / 422 (external_id fehlt, RecordInvalid)
    def tournament
      payload = tournament_params.to_h.deep_symbolize_keys
      region = Region.find_by!(shortname: payload.dig(:region, :shortname).to_s.upcase)

      result = ExternalTournament::LocalTournamentCreator.new(region: region, payload: payload).call
      t = result.tournament

      render json: {
        schema: "carambus.tournament/v1",
        region: {shortname: region.shortname},
        tournament: {
          id: t.id,
          external_id: t.external_id,
          tournament_monitor_id: t.tournament_monitor&.id,
          title: t.title,
          location_id: t.location_id
        }
      }, status: result.created? ? :created : :ok
    rescue ActiveRecord::RecordNotFound => e
      render json: {error: e.message}, status: :not_found
    rescue ArgumentError => e
      render json: {error: e.message}, status: :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => e
      render json: {error: e.message}, status: :unprocessable_entity
    end

    # POST /api/external_tournament/lock_table
    #
    # Plan 17-02: Die App sperrt selbst einen Tisch fuer ihr lokales Turnier (locked_for_tournament)
    # + bindet den TableMonitor an den TournamentMonitor + nimmt den Tisch in data["table_ids"] auf.
    # lock=false kehrt das um (einfache Teil-Freigabe).
    #
    # Body: { region:{shortname}, tournament_id | tournament:{external_id}, table:{id|name}, lock(default true) }
    # Response (200): { table_id, locked_for_tournament, table_monitor_id }
    #
    # Errors: 401 (Auth) / 404 (Region) / 422 (Tournament/Table not found, Konflikt, kein Monitor)
    def lock_table
      payload = lock_table_params.to_h.deep_symbolize_keys
      region = Region.find_by!(shortname: payload.dig(:region, :shortname).to_s.upcase)

      result = ExternalTournament::TableLocker.new(region: region, payload: payload).call

      render json: {
        table_id: result.table.id,
        # Lock = TournamentMonitor-Bindung (kein eigenes Flag mehr, siehe Refactor 3e7c4739).
        in_tournament: result.table_monitor.tournament_monitor_id.present?,
        table_monitor_id: result.table_monitor.id
      }
    rescue ActiveRecord::RecordNotFound => e
      render json: {error: e.message}, status: :not_found
    rescue ExternalTournament::TableLocker::TournamentNotFoundError
      render json: {error: "Tournament not found"}, status: :unprocessable_entity
    rescue ExternalTournament::TableLocker::TableNotFoundError => e
      render json: {error: "Table not found: #{e.identifier}"}, status: :unprocessable_entity
    rescue ExternalTournament::TableLocker::TableConflictError => e
      render json: {error: "Table already in use: #{e.identifier}"}, status: :unprocessable_entity
    rescue ExternalTournament::TableLocker::TableMonitorNotFoundError => e
      render json: {error: "TableMonitor not found for #{e.identifier}"}, status: :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => e
      render json: {error: e.message}, status: :unprocessable_entity
    end

    # POST /api/external_tournament/start_game
    #
    # Plan 17-03 (B1): App startet ein Spiel auf einem turnier-gebundenen Tisch mit
    # PER-SPIELER-Disziplinen + Format. Erzeugt Game + GameParticipations + bringt den Tisch
    # in Warmup (loest 15-06). Ersetzt round_start im App-Lifecycle.
    #
    # Body: { region:{shortname}, tournament:{external_id}|tournament_id, table:{id|name},
    #         external_id, free_game_form, innings_goal, sets_to_play, sets_to_win,
    #         participants:[{role:"playera|playerb", player:{...}, discipline, balls_goal}] }
    # Response (201 / 200 idempotent): { external_id, game_id, table_monitor_id, state }
    #
    # Errors: 401 / 404 (Region) / 422 (Tournament/Table not found, nicht gebunden, Player, Invalid)
    def start_game
      payload = start_game_params.to_h.deep_symbolize_keys
      region = Region.find_by!(shortname: payload.dig(:region, :shortname).to_s.upcase)

      result = ExternalTournament::StartGameProcessor.new(region: region, payload: payload).call

      render json: {
        external_id: payload[:external_id],
        game_id: result.game&.id,
        table_monitor_id: result.table_monitor.id,
        state: result.state
      }, status: result.created? ? :created : :ok
    rescue ActiveRecord::RecordNotFound => e
      render json: {error: e.message}, status: :not_found
    rescue ExternalTournament::StartGameProcessor::TournamentNotFoundError
      render json: {error: "Tournament not found"}, status: :unprocessable_entity
    rescue ExternalTournament::StartGameProcessor::TableNotFoundError => e
      render json: {error: "Table not found: #{e.identifier}"}, status: :unprocessable_entity
    rescue ExternalTournament::StartGameProcessor::TableNotBoundError => e
      render json: {error: "Table not bound to this tournament: #{e.identifier}"}, status: :unprocessable_entity
    rescue ExternalTournament::StartGameProcessor::TableMonitorNotFoundError => e
      render json: {error: "TableMonitor not found for #{e.identifier}"}, status: :unprocessable_entity
    rescue ExternalTournament::StartGameProcessor::PlayerResolutionError => e
      render json: {error: "Player not resolved", participant: e.participant}, status: :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => e
      render json: {error: e.message}, status: :unprocessable_entity
    end

    # POST /api/external_tournament/acknowledge_result
    #
    # Plan 17-04 (Vision J): App ruft das am Hold (:final_match_score) erfasste Ergebnis
    # ab + gibt den Tisch frei. Bis zu diesem Aufruf ist der Operator-Release am
    # Scoreboard gesperrt (TableMonitor#external_result_pending?-Guard). Idempotent:
    # ein 2. Aufruf liefert dasselbe Ergebnis ohne erneuten Release.
    #
    # Body: { region:{shortname}, tournament:{external_id}|tournament_id, game:{external_id} }
    # Response (200): carambus.ack/v1
    #   { schema, region:{shortname}, tournament:{id,external_id}, game:{id,external_id,gname},
    #     table:{id,name}|null, state, already_acknowledged, acknowledged_at,
    #     result:{ ...ba_results..., "sets":[...] } }
    #
    # Errors: 401 (Auth) / 404 (Region) / 409 (NotReady — Ergebnis noch nicht erfasst)
    #         / 422 (Tournament/Game/TableMonitor not found)
    def acknowledge_result
      payload = acknowledge_result_params.to_h.deep_symbolize_keys
      region = Region.find_by!(shortname: payload.dig(:region, :shortname).to_s.upcase)

      result = ExternalTournament::AcknowledgeResultProcessor.new(region: region, payload: payload).call
      t = result.tournament
      g = result.game
      tbl = g&.table_monitor&.table

      render json: {
        schema: "carambus.ack/v1",
        region: {shortname: region.shortname},
        tournament: {id: t.id, external_id: t.external_id},
        game: {id: g.id, external_id: (g.data.is_a?(Hash) ? g.data["external_id"] : nil), gname: g.gname},
        table: tbl ? {id: tbl.id, name: tbl.name} : nil,
        state: result.state,
        already_acknowledged: result.already_acknowledged,
        acknowledged_at: result.acknowledged_at&.iso8601,
        result: result.result
      }, status: :ok
    rescue ActiveRecord::RecordNotFound => e
      render json: {error: e.message}, status: :not_found
    rescue ExternalTournament::AcknowledgeResultProcessor::TournamentNotFoundError
      render json: {error: "Tournament not found"}, status: :unprocessable_entity
    rescue ExternalTournament::AcknowledgeResultProcessor::GameNotFoundError => e
      render json: {error: "Game not found: #{e.identifier}"}, status: :unprocessable_entity
    rescue ExternalTournament::AcknowledgeResultProcessor::TableMonitorNotFoundError => e
      render json: {error: "TableMonitor not found for #{e.identifier}"}, status: :unprocessable_entity
    rescue ExternalTournament::AcknowledgeResultProcessor::NotReadyError => e
      render json: {error: e.message, state: e.state}, status: :conflict
    end

    # POST /api/external_tournament/end_tournament
    #
    # Plan 17-05 (Vision L): App meldet Turnierende → alle an das Turnier gebundenen
    # Tische werden freigegeben (force, auch unbestaetigte Hold-Ergebnisse — D-17-vision-5)
    # und der TournamentMonitor geschlossen. Idempotent (2. Aufruf: released_tables=0).
    #
    # Body: { region:{shortname}, tournament:{external_id} | tournament_id }
    # Response (200): carambus.tournament_end/v1
    #   { schema, region:{shortname}, tournament:{id,external_id}, released_tables,
    #     unacknowledged, tournament_monitor_state }
    #
    # Errors: 401 (Auth) / 404 (Region) / 422 (Tournament not found)
    def end_tournament
      payload = end_tournament_params.to_h.deep_symbolize_keys
      region = Region.find_by!(shortname: payload.dig(:region, :shortname).to_s.upcase)
      tournament = resolve_external_tournament(payload, region)
      return render json: {error: "Tournament not found"}, status: :unprocessable_entity if tournament.blank?

      r = ExternalTournament::TableReleaser.release_tournament(tournament)
      render json: {
        schema: "carambus.tournament_end/v1",
        region: {shortname: region.shortname},
        tournament: {id: tournament.id, external_id: tournament.external_id},
        released_tables: r.released,
        unacknowledged: r.unacknowledged,
        tournament_monitor_state: r.tournament_monitor_state
      }, status: :ok
    rescue ActiveRecord::RecordNotFound => e
      render json: {error: e.message}, status: :not_found
    end

    private

    # Plan 17-05: region-scoped Tournament-Resolve (tournament_id ODER tournament.external_id).
    def resolve_external_tournament(payload, region)
      if payload[:tournament_id].present?
        Tournament.find_by(id: payload[:tournament_id], region_id: region.id)
      elsif payload.dig(:tournament, :external_id).present?
        Tournament.where(region_id: region.id, external_id: payload.dig(:tournament, :external_id)).first
      end
    end

    # Plan 15-06 (R1/R2): Location-Auflösung aus Params bzw. Payload.
    # location_id (Carambus-PK, global eindeutig) hat Vorrang vor location_cc_id.
    # D-15-07-A: location_cc_id MUSS region-scoped sein — cc_id ist nur intra-region
    # eindeutig (z.B. 3 Locations mit cc_id=11 in verschiedenen Regionen).
    def resolve_location(p, region)
      if p[:location_id].present?
        Location.find_by(id: p[:location_id])
      elsif p[:location_cc_id].present?
        Location.find_by(cc_id: p[:location_cc_id], region_id: region.id)
      end
    end

    # D-15-04-F: round_no Query-Param ist required; nicht-numerisch → nil → 422.
    def parse_round_no(raw)
      return nil if raw.blank?
      raw_str = raw.to_s.strip
      return nil unless raw_str.match?(/\A\d+\z/)
      raw_str.to_i
    end

    # Strong-Parameters für POST round_start.
    def round_start_params
      params.permit(
        :schema, :round_no, :round_name,
        region: [:shortname],
        location: [:id, :cc_id], # Plan 15-06 (R2): explizite Location (id|cc_id), optional
        tournament: [:cc_id, :name],
        games: [
          :external_id, :table_no, :table_name, # Plan 15-06 (R2): table_name bevorzugt
          {discipline: [:name],
           format: [:target_points, :max_innings],
           context: [:round_no, :round_name, :gname, :group_no, :seqno],
           participants: [
             :role, :team_name, :team_position,
             {player: [:cc_id, :firstname, :lastname, :dbu_nr]}
           ]}
        ]
      )
    end

    # Plan 17-02: Strong-Parameters fuer POST tournament (Lokal-Turnier-Anlage).
    def tournament_params
      params.permit(
        :schema, :title, :external_id,
        region: [:shortname],
        location: [:id, :cc_id],
        discipline: [:name]
      )
    end

    # Plan 17-02: Strong-Parameters fuer POST lock_table.
    def lock_table_params
      params.permit(
        :schema, :tournament_id, :lock,
        region: [:shortname],
        tournament: [:external_id],
        table: [:id, :name]
      )
    end

    # Plan 17-03: Strong-Parameters fuer POST start_game (per-Spiel/Spieler-Disziplinen).
    def start_game_params
      params.permit(
        :schema, :tournament_id, :external_id, :free_game_form,
        :innings_goal, :sets_to_play, :sets_to_win, :timeouts, :timeout,
        :kickoff_switches_with, :allow_follow_up, :allow_overflow, :initial_red_balls,
        region: [:shortname],
        tournament: [:external_id],
        table: [:id, :name],
        participants: [
          :role, :discipline, :balls_goal,
          {player: [:cc_id, :firstname, :lastname, :dbu_nr, :club_cc_id]}
        ]
      )
    end

    # Plan 17-04: Strong-Parameters fuer POST acknowledge_result.
    def acknowledge_result_params
      params.permit(
        :schema, :tournament_id,
        region: [:shortname],
        tournament: [:external_id],
        game: [:external_id]
      )
    end

    # Plan 17-05: Strong-Parameters fuer POST end_tournament.
    def end_tournament_params
      params.permit(:schema, :tournament_id, region: [:shortname], tournament: [:external_id])
    end

    # === Seeding-Payload-Builder ===

    def build_seeding_payload(tournament, tournament_cc, region)
      # Polymorphic-aware Seeding-Lookup (Spec-Pivot 2 aus 15-01-Audit).
      # Tournament#seedings hat `-> { order(position: :asc) }`-Scope (siehe Tournament-Model).
      seedings = tournament.seedings.includes(:player, :league_team)

      teams = group_seedings_into_teams(seedings)

      {
        schema: "carambus.seeding/v1",
        region: {
          shortname: region.shortname,
          url: "https://#{region.shortname.downcase}.carambus.de"
        },
        tournament: build_tournament_meta(tournament, tournament_cc),
        teams: teams.map { |t| serialize_team(t) }
      }
    end

    # Gruppiert Seedings nach league_team_id (Mannschaftsturnier) oder
    # behandelt jedes Seeding als 1-Player-Team (Single-Tournament).
    def group_seedings_into_teams(seedings)
      if seedings.any? { |s| s.league_team_id.present? }
        seedings.group_by(&:league_team_id).map do |_team_id, ss|
          ordered = ss.sort_by { |s| s.position || 0 }
          {
            league_team: ordered.first.league_team,
            seeding_position: ordered.first.position,
            seedings: ordered
          }
        end.sort_by { |t| t[:seeding_position] || 0 }
      else
        seedings.sort_by { |s| s.position || 0 }.map.with_index(1) do |s, idx|
          {league_team: nil, seeding_position: idx, seedings: [s]}
        end
      end
    end

    # === Tournament-Meta-Mapping (Decisions aus 15-02-AUDIT-NOTES.md) ===

    def build_tournament_meta(tournament, tournament_cc)
      {
        cc_id: tournament_cc.cc_id,
        name: tournament.title,
        discipline: build_discipline(tournament.discipline),
        format: build_format(tournament),
        starts_at: tournament.date&.iso8601,
        location: build_location(tournament.location)
      }
    end

    # Plan 15-06 (R3): location als {id, cc_id, name}-Objekt statt String,
    # damit die App nach Seedlist-Pull die Location für den Round-Start vorbelegen kann.
    # null wenn tournament.location_id nil ist — dann setzt die App die Location manuell.
    def build_location(location)
      return nil unless location
      {id: location.id, cc_id: location.cc_id, name: location.name}
    end

    def build_discipline(discipline)
      return nil unless discipline
      {
        name: discipline.name,
        synonyms: discipline_synonyms(discipline)
      }
    end

    # D-15-02 (Mapping-Decision): discipline.synonyms ist newline-separated; enthält Name selbst.
    # Spec-`synonyms` = nur ALTERNATIVE Namen, deshalb Name subtrahieren.
    def discipline_synonyms(discipline)
      return [] unless discipline.synonyms.present?
      (discipline.synonyms.split("\n").map(&:strip).reject(&:blank?) - [discipline.name])
    end

    # D-15-02 (Mapping-Decision aus 15-02-AUDIT-NOTES.md Q3):
    #   target_points = balls_goal | max_innings = innings_goal
    #   sets = sets_to_play         | frames = nil (Carambus hat kein Frame-Konzept)
    def build_format(tournament)
      {
        target_points: tournament.balls_goal,
        max_innings: tournament.innings_goal,
        sets: tournament.sets_to_play,
        frames: nil
      }
    end

    # === Team/Player-Serialisierung ===

    def serialize_team(team)
      league_team = team[:league_team]
      first_player = team[:seedings].first.player
      {
        seeding_position: team[:seeding_position],
        name: league_team&.name || first_player.fl_name,
        club: serialize_club(league_team_club(team) || first_player.clubs.first),
        players: team[:seedings].map.with_index(1) { |s, idx| serialize_player(s, idx) }
      }
    end

    def league_team_club(team)
      return nil unless team[:league_team]
      return nil unless team[:league_team].respond_to?(:club_id) && team[:league_team].club_id
      Club.find_by(id: team[:league_team].club_id)
    end

    def serialize_club(club)
      return nil unless club
      {cc_id: club.cc_id, shortname: club.shortname}
    end

    def serialize_player(seeding, position_in_team)
      player = seeding.player
      return {position_in_team: position_in_team, firstname: nil, lastname: nil} unless player
      {
        position_in_team: position_in_team,
        firstname: player.firstname,
        lastname: player.lastname,
        cc_id: player.cc_id,
        dbu_nr: player.dbu_nr&.to_s,
        nationality: player.try(:nationality) || "DE"
      }
    end
  end
end
