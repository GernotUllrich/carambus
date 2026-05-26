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

    # GET /api/external_tournament/clubs?region=NBV
    #
    # Plan 18-01: Clubs der Region (mit cc_id) fuer den App-Club-Picker. cc_id ist der
    # Schluessel fuer club_players. Region-scoped, read-only.
    # Response: carambus.clubs/v1
    #   { schema, region:{shortname}, season:{name,current:true}, clubs:[{cc_id,shortname,name}] }
    # Errors: 401 (Auth) / 404 (Region)
    def clubs
      region = Region.find_by!(shortname: params[:region].to_s.upcase)
      season = ExternalTournament::ClubRosterQuery.current_season
      render json: {
        schema: "carambus.clubs/v1",
        region: {shortname: region.shortname},
        season: {name: season&.name, current: true},
        clubs: ExternalTournament::ClubRosterQuery.clubs(region)
      }
    rescue ActiveRecord::RecordNotFound => e
      render json: {error: e.message}, status: :not_found
    end

    # GET /api/external_tournament/club_players?region=NBV&club_cc_id=11
    #   alternativ: ?region=NBV&club_cc_ids=11,12 (mehrere Clubs in einem Call)
    #
    # Plan 18-01: In der laufenden Saison SPIELBERECHTIGTE (status="active") Spieler eines
    # Clubs, je cc_id + dbu_nr (CSV-relevant). Region-scoped (Club.cc_id nur regional
    # eindeutig), read-only.
    # Response (Einzel-Club): carambus.club_players/v1
    #   { schema, region, season:{name}, club:{cc_id,shortname,name},
    #     players:[{cc_id,firstname,lastname,dbu_nr,status}] }
    # Response (club_cc_ids): { schema, region, season, clubs:[{...club, players:[...]}] }
    # Errors: 401 (Auth) / 404 (Region | unbekannter club_cc_id) / 422 (club_cc_id fehlt)
    def club_players
      region = Region.find_by!(shortname: params[:region].to_s.upcase)
      season = ExternalTournament::ClubRosterQuery.current_season

      # Plan 20-03 (F5): optionaler player_class-Filter (disziplin-gebunden, D-20-03).
      # discipline angegeben aber nicht aufloesbar -> 404 (D-20-03-C, wie 20-02).
      disc = nil
      if params[:discipline].present?
        disc = ExternalTournament::RankingQuery.find_disciplines(params[:discipline]).first
        return render json: {error: "Discipline not found: #{params[:discipline]}"}, status: :not_found if disc.nil?
      end
      # player_class braucht eine discipline (Leistungsklasse ist disziplin-gebunden) -> sonst 422.
      pclass = params[:player_class].presence
      if pclass && disc.nil?
        return render json: {error: "discipline required for player_class filter"}, status: :unprocessable_entity
      end
      # Plan 21-01 (D-21-01-D): unbekannte player_class -> 422. PLAYER_CLASS_ORDER ist die
      # Quelle der gueltigen Klassen-Shortnames (worst→best, TB 7..1 + MB I..III).
      if pclass && !Discipline::PLAYER_CLASS_ORDER.include?(pclass)
        return render json: {error: "unknown player_class: #{pclass}"}, status: :unprocessable_entity
      end
      # Klassen-Saison = Vorsaison (D-20-03-B / D-19-01-SEASON); Eligibility-Saison bleibt current_season.
      rseason = ExternalTournament::RankingQuery.resolve_season(season_name: params[:season])
      # age_class/gender (D-20-03-E): DEFERRED -> Params werden ignoriert (Phase 21).

      if params[:club_cc_ids].present?
        cc_ids = params[:club_cc_ids].to_s.split(",").map(&:strip).reject(&:blank?)
        clubs = cc_ids.filter_map { |cc| ExternalTournament::ClubRosterQuery.find_club(region, cc) }
        return render json: {
          schema: "carambus.club_players/v1",
          region: {shortname: region.shortname},
          season: {name: season&.name},
          clubs: clubs.map do |club|
            {
              club: ExternalTournament::ClubRosterQuery.club_hash(club),
              players: ExternalTournament::ClubRosterQuery.players(region: region, club: club, season: season,
                discipline: disc, player_class: pclass, ranking_season: rseason)
            }
          end
        }
      end

      if params[:club_cc_id].blank?
        return render json: {error: "club_cc_id is required"}, status: :unprocessable_entity
      end

      club = ExternalTournament::ClubRosterQuery.find_club(region, params[:club_cc_id])
      return render json: {error: "Club not found in region #{region.shortname}"}, status: :not_found if club.blank?

      render json: {
        schema: "carambus.club_players/v1",
        region: {shortname: region.shortname},
        season: {name: season&.name},
        club: ExternalTournament::ClubRosterQuery.club_hash(club),
        players: ExternalTournament::ClubRosterQuery.players(region: region, club: club, season: season,
          discipline: disc, player_class: pclass, ranking_season: rseason)
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
    # Plan 16-01 (D-16-GC-A / D-16-01-A): Mit cleanup:true (opt-in, Default off) wird NACH dem
    # Tisch-Release das Turnier + seine Marker-Games (+GameParticipation) geloescht — Carambus
    # haelt kein Gedaechtnis (die App hat ihr eigenes). Datenkritisch → bewusst opt-in.
    #
    # Body: { region:{shortname}, tournament:{external_id} | tournament_id, cleanup(default false) }
    # Response (200): carambus.tournament_end/v1
    #   { schema, region:{shortname}, tournament:{id,external_id}, released_tables,
    #     unacknowledged, tournament_monitor_state[, tournament_deleted, games_deleted] }
    #
    # Errors: 401 (Auth) / 404 (Region) / 422 (Tournament not found)
    def end_tournament
      payload = end_tournament_params.to_h.deep_symbolize_keys
      region = Region.find_by!(shortname: payload.dig(:region, :shortname).to_s.upcase)
      tournament = resolve_external_tournament(payload, region)
      return render json: {error: "Tournament not found"}, status: :unprocessable_entity if tournament.blank?

      r = ExternalTournament::TableReleaser.release_tournament(tournament)
      # tournament:{id,external_id} VOR dem cleanup snapshotten — das Objekt ist danach destroyed.
      body = {
        schema: "carambus.tournament_end/v1",
        region: {shortname: region.shortname},
        tournament: {id: tournament.id, external_id: tournament.external_id},
        released_tables: r.released,
        unacknowledged: r.unacknowledged,
        tournament_monitor_state: r.tournament_monitor_state
      }

      if ActiveModel::Type::Boolean.new.cast(payload[:cleanup])
        c = ExternalTournament::AppTournamentCleaner.cleanup(tournament)
        body[:tournament_deleted] = c[:tournament_deleted]
        body[:games_deleted] = c[:games_deleted]
      end

      render json: body, status: :ok
    rescue ActiveRecord::RecordNotFound => e
      render json: {error: e.message}, status: :not_found
    end

    # POST /api/external_tournament/player_reconcile
    #
    # Plan 17-06 (Vision C/D): App-Teilnehmerliste gegen Carambus-lokal reconcilen.
    # Liefert pro Eintrag die dbu_nr + den kanonischen Player (region-scoped, KEIN Create —
    # D-17-vision-2). Wiederverwendung von ExternalTournament::PlayerMatcher.
    #
    # Body: { region:{shortname}, participants:[{ ref?, cc_id?, dbu_nr?, firstname?, lastname?, club_cc_id? }] }
    # Response (200): carambus.player_reconcile/v1
    #   { schema, region:{shortname},
    #     results:[{ ref, matched, player:{id,cc_id,dbu_nr,firstname,lastname,club:{cc_id,shortname}}|null }] }
    #
    # Errors: 401 (Auth) / 404 (Region) / 422 (participants fehlt oder kein Array)
    def player_reconcile
      payload = player_reconcile_params.to_h.deep_symbolize_keys
      region = Region.find_by!(shortname: payload.dig(:region, :shortname).to_s.upcase)

      participants = payload[:participants]
      unless participants.is_a?(Array) && participants.any?
        return render json: {error: "participants required (non-empty array)"}, status: :unprocessable_entity
      end

      results = ExternalTournament::PlayerReconciler.new(region: region).call(participants: participants)
      render json: {
        schema: "carambus.player_reconcile/v1",
        region: {shortname: region.shortname},
        results: results
      }, status: :ok
    rescue ActiveRecord::RecordNotFound => e
      render json: {error: e.message}, status: :not_found
    end

    # GET /api/external_tournament/player_rankings?region=NBV&discipline=Dreiband+klein
    #   optional: &player_cc_ids=11683,10024  (Filter; ohne -> ganze Rangliste)
    #   optional: &season=2024/2025           (Default: VORSAISON — D-19-01-SEASON)
    #
    # Plan 19-01 (v0.6 F1): Disziplin-Ranking-Setzliste (bestes Ranking = Setzplatz 1) fuer
    # die App-Setzliste (Doppel-KO). Sortierung rank aufsteigend, bei Gleichstand gd absteigend.
    # Default-Saison = VORSAISON (Rankings der laufenden Saison noch nicht final; D-19-01-SEASON);
    # explizites season uebersteuert. Quelle PlayerRanking via ExternalTournament::RankingQuery. Read-only.
    #
    # Response (200): carambus.player_rankings/v1
    #   { schema, region:{shortname}, season:{name}, discipline:{name},
    #     players:[{cc_id,firstname,lastname,dbu_nr,rank,gd,hs,balls,innings}], unranked:[cc_id,...] }
    # Errors: 401 (Auth) / 404 (Region | Disziplin nicht gefunden) / 422 (discipline fehlt)
    def player_rankings
      region = Region.find_by!(shortname: params[:region].to_s.upcase)
      if params[:discipline].blank?
        return render json: {error: "discipline is required"}, status: :unprocessable_entity
      end

      cc_ids = params[:player_cc_ids].to_s.split(",").map(&:strip).reject(&:blank?)
      result = ExternalTournament::RankingQuery.players(
        region: region, discipline_name: params[:discipline],
        player_cc_ids: cc_ids, season_name: params[:season]
      )
      if result.nil?
        return render json: {error: "Discipline not found: #{params[:discipline]}"}, status: :not_found
      end

      render json: {
        schema: "carambus.player_rankings/v1",
        region: {shortname: region.shortname},
        season: {name: result.season&.name},
        discipline: {name: result.discipline.name},
        players: result.ranked,
        unranked: result.unranked
      }, status: :ok
    rescue ActiveRecord::RecordNotFound => e
      render json: {error: e.message}, status: :not_found
    end

    # GET /api/external_tournament/disciplines?region=NBV
    #
    # Plan 20-01 (v0.6 F3): Region-relevante offizielle Disziplinen als Selektor-Substrat fuer
    # den Turnier-Manager (exakte Namen, die 1:1 in player_rankings/start_game matchen) inkl.
    # normalisierter TournamentPlan-Matrix (points/innings/players/player_class) + Plan-Definitionen.
    # Region-scoped (D-20-01-A: Disziplinen mit Rankings ODER Tournaments in der Region), read-only.
    # Quelle: ExternalTournament::DisciplineQuery.
    #
    # Response (200): carambus.disciplines/v1
    #   { schema, region:{shortname},
    #     tournament_plans:{ "<name>":{players,tables,ngroups,nrepeats,rulesystem,executor_class,
    #                                  executor_params,more_description,even_more_description}, ... },
    #     disciplines:[{ name, synonyms:[...], table_kind, super_discipline, player_classes:[...],
    #                    parameters:[{tournament_plan,players,player_class,points,innings}] }] }
    # Errors: 401 (Auth) / 404 (Region)
    def disciplines
      region = Region.find_by!(shortname: params[:region].to_s.upcase)
      result = ExternalTournament::DisciplineQuery.call(region: region)
      render json: {
        schema: "carambus.disciplines/v1",
        region: {shortname: region.shortname},
        tournament_plans: result.tournament_plans,
        disciplines: result.disciplines
      }, status: :ok
    rescue ActiveRecord::RecordNotFound => e
      render json: {error: e.message}, status: :not_found
    end

    # GET /api/external_tournament/categories?region=NBV[&discipline=Dreiband+klein]
    #
    # Kategorie-/Klassen-LISTEN als Selektor-Substrat fuer die Turnier-Anlage (F4).
    # discipline optional (D-20-02-B): mit → disziplin-skopiert + player_classes; ohne →
    # region-weite Kategorie-Listen + player_classes=[]. age_classes = rohe CategoryCc-Namen,
    # genders = CategoryCc::SEX_MAP-Keys (M/F/U). Per-Spieler age_class/gender DEFERRED (Phase 21).
    #
    # Response (200): carambus.categories/v1
    #   { schema, region:{shortname}, season:{name},
    #     player_classes:[...], age_classes:[...], genders:[...],
    #     categories:[{name, sex, min_age, max_age, status}] }
    # Errors: 401 (Auth) / 404 (Region unbekannt ODER discipline angegeben aber nicht aufloesbar)
    def categories
      region = Region.find_by!(shortname: params[:region].to_s.upcase)
      result = ExternalTournament::CategoryQuery.call(region: region, discipline_name: params[:discipline])
      unless result.discipline_resolved
        return render json: {error: "Discipline not found: #{params[:discipline]}"}, status: :not_found
      end
      render json: {
        schema: "carambus.categories/v1",
        region: {shortname: region.shortname},
        season: {name: result.season&.name},
        player_classes: result.player_classes,
        age_classes: result.age_classes,
        genders: result.genders,
        categories: result.categories
      }, status: :ok
    rescue ActiveRecord::RecordNotFound => e
      render json: {error: e.message}, status: :not_found
    end

    # GET /api/external_tournament/registration_lists?region=NBV
    #   [&season=2025/2026][&discipline=Dreiband+klein][&category=Herren][&status=Freigegeben]
    #
    # Meldelisten-Discovery (Slice B aus Phase-21-Cluster). Liefert RegistrationListCc-Records
    # einer Region+Saison mit deadline/qualifying_date/status, plus optionaler
    # tournament_cc-Verknuepfung (Bulk-Reverse-Lookup, KEIN N+1). Read-only.
    #
    # Default-Saison = Season.current_season (D-21-05-B). ⚠️ RegistrationSyncer-Cron ist heute
    # auskommentiert (D-21-DISC-C) → Default-Calls liefern leeres Array bis Slice E den Cron
    # re-aktiviert. Historische Saison explizit per ?season=2022/2023 anfragen.
    #
    # Response (200): carambus.registration_lists/v1
    #   { schema, region:{shortname}, season:{name},
    #     registration_lists:[{cc_id, name, deadline, qualifying_date, status, season,
    #                          discipline:{id,name}|null, category_cc:{id,name}|null,
    #                          tournament_cc:{id,name,date}|null}] }
    # Errors: 401 (Auth) / 404 (region/season/discipline/category nicht aufloesbar)
    def registration_lists
      region = Region.find_by!(shortname: params[:region].to_s.upcase)
      result = ExternalTournament::RegistrationListQuery.call(
        region: region,
        season: params[:season],
        discipline: params[:discipline],
        category: params[:category],
        status: params[:status]
      )
      unless result.season_resolved
        return render json: {error: "Season not found: #{params[:season]}"}, status: :not_found
      end
      unless result.discipline_resolved
        return render json: {error: "Discipline not found: #{params[:discipline]}"}, status: :not_found
      end
      unless result.category_resolved
        return render json: {error: "Category not found: #{params[:category]}"}, status: :not_found
      end
      render json: {
        schema: "carambus.registration_lists/v1",
        region: {shortname: region.shortname},
        season: {name: result.season&.name},
        registration_lists: result.items
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

    # Plan 17-05 / 16-01: Strong-Parameters fuer POST end_tournament (cleanup = opt-in Teardown).
    def end_tournament_params
      params.permit(:schema, :tournament_id, :cleanup, region: [:shortname], tournament: [:external_id])
    end

    # Plan 17-06: Strong-Parameters fuer POST player_reconcile (Batch-Liste).
    def player_reconcile_params
      params.permit(
        :schema,
        region: [:shortname],
        participants: [:ref, :cc_id, :dbu_nr, :firstname, :lastname, :club_cc_id]
      )
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
