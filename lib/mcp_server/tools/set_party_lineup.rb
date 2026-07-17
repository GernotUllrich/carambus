# frozen_string_literal: true

# cc_set_party_lineup — Phase 46-01: lokale Aufstellungs-Vorbereitung eines Pool-
# Mannschaftskampfs (Party). Setzt die Aufstellung EINER Mannschaft (team a|b) als
# party-scoped Seedings (role + position + optional playing_discipline) — exakt das
# party_monitor_reflex#assign_player-Muster, rein LOKAL (kein ClubCloud-Schreiben; das
# folgt in 46-02). armed-Dry-Run + Pre-Validation (Kader-Eligibility/Positionen/Scope) +
# idempotentes Ersetzen (nur lokale Seedings, id >= MIN_ID) + Read-Back.
# Registry-Stufe: WRITE_TOOLS (nur cc_write_access?-Personas).
module McpServer
  module Tools
    class SetPartyLineup < BaseTool
      tool_name "cc_set_party_lineup"
      description <<~DESC
        Wann nutzen? Wenn ein Sportwart die Aufstellung SEINER Mannschaft für einen Mannschaftskampf (Party) festlegt — "stelle für <Team> am Spieltag X auf", "Aufstellung Heim: ...".
        Was tippt der User typisch? "Stelle Team A auf: 1 Müller, 2 Schmidt, 3 Meyer", "Aufstellung für unseren nächsten Spieltag".
        Party finden: party_id (aus cc_league_schedule / cc_my_teams) ODER league_id + day_seqno/date. team: "a" (Heim) oder "b" (Gast).
        players: Liste der aufzustellenden Spieler in Reihenfolge — je Eintrag player_id ODER player_name (aus dem Mannschaftskader); optional position (Brett-Nr.) und discipline.
        Setzt die Aufstellung LOKAL in Carambus (party-scoped). armed:true führt aus, armed:false ist ein Probelauf. Eine bestehende lokale Aufstellung wird idempotent ersetzt. (Die Übertragung in die ClubCloud erfolgt separat.)
      DESC
      input_schema(
        properties: {
          party_id: {type: "integer", description: "Carambus party_id (aus cc_league_schedule / cc_my_teams) — eindeutigster Weg."},
          league_id: {type: "integer", description: "Alternativ zur party_id: Liga (aus cc_list_leagues) — mit day_seqno ODER date."},
          cc_id: {type: "integer", description: "Optional: ClubCloud league cc_id (statt league_id, mit day_seqno/date)."},
          day_seqno: {type: "integer", description: "Spieltag-Nummer (mit league_id/cc_id)."},
          date: {type: "string", description: "Datum YYYY-MM-DD (mit league_id/cc_id)."},
          team: {type: "string", enum: %w[a b], description: "Welche Mannschaft aufstellen: 'a' = Heim (league_team_a), 'b' = Gast (league_team_b)."},
          players: {
            type: "array",
            description: "Aufzustellende Spieler in Reihenfolge. Je Eintrag player_id ODER player_name (aus dem Mannschaftskader); optional position (Brett-Nr.) und discipline.",
            items: {
              type: "object",
              properties: {
                player_id: {type: "integer", description: "Carambus player_id."},
                player_name: {type: "string", description: "Spielername (wird im Mannschaftskader aufgelöst)."},
                position: {type: "integer", description: "Optional: Brett-/Reihenfolge-Nr. (Default = Reihenfolge in der Liste)."},
                discipline: {type: "string", description: "Optional: Disziplin dieses Bretts (z.B. '9-Ball')."}
              }
            }
          },
          armed: {type: "boolean", default: false, description: "false = Probelauf (zeigt die geplante Aufstellung). true = lokal setzen."}
        },
        required: %w[team players]
      )
      annotations(read_only_hint: false, destructive_hint: true)

      def self.call(party_id: nil, league_id: nil, cc_id: nil, day_seqno: nil, date: nil, team: nil, players: nil, armed: false, server_context: nil)
        err = validate_required!({team: team, players: players}, [:team, :players])
        return err if err
        team = team.to_s.downcase
        return error("team muss 'a' (Heim) oder 'b' (Gast) sein.") unless %w[a b].include?(team)
        entries = Array(players)
        return error("Bitte mindestens einen Spieler in players angeben.") if entries.empty?

        resolved = resolve_party(server_context, party_id: party_id, league_id: league_id, cc_id: cc_id, day_seqno: day_seqno, date: date)
        return resolved[:error] if resolved[:error]
        party = resolved[:party]

        auth_err = authorize_party_preparation!(party: party, server_context: server_context)
        return auth_err if auth_err

        team_lt = (team == "a") ? party.league_team_a : party.league_team_b
        return error("Die Party hat keine #{(team == "a") ? "Heim" : "Gast"}-Mannschaft (team_#{team}).") if team_lt.nil?

        # Mannschaftskader = Saison-Roster der Mannschaft (league_team-Seedings).
        roster = Seeding.where(league_team_id: team_lt.id).includes(:player).map(&:player).compact.uniq
        lineup, resolve_errors = resolve_lineup_entries(entries, roster)

        positions = lineup.map { |e| e[:position] }
        player_ids = lineup.map { |e| e[:player].id }

        validations = [
          {name: "team_belongs_to_party", ok: team_lt.present?, reason: "Mannschaft gehört nicht zu dieser Party."},
          {name: "players_eligible", ok: resolve_errors.empty?, reason: resolve_errors.join(" ")},
          {name: "positions_unique", ok: (positions.uniq.length == positions.length), reason: "Positionen (Brett-Nr.) müssen eindeutig sein."},
          {name: "no_duplicate_players", ok: (player_ids.uniq.length == player_ids.length), reason: "Ein Spieler darf nur einmal aufgestellt werden."},
          lambda {
            ok = party.team_size.to_i <= 0 || lineup.length <= party.team_size.to_i
            {name: "team_size", ok: ok, reason: "Mehr Spieler (#{lineup.length}) als die Mannschaftsgröße (#{party.team_size}) erlaubt."}
          }
        ]
        val = run_validations(validations)
        unless val[:all_passed]
          reasons = val[:results].reject { |r| r[:ok] }.map { |r| r[:reason] }.reject(&:blank?)
          return error("Aufstellung nicht möglich: #{reasons.join(" ")}")
        end

        planned = lineup.map { |e| {position: e[:position], player: e[:player].fullname, discipline: e[:discipline]&.name} }
          .sort_by { |h| h[:position] }

        unless armed
          return text(JSON.generate(
            ok: false, reason: "dry_run",
            party: party_brief(party), team: team, team_name: team_lt.name,
            current: serialize_lineup(party, team), planned: planned,
            note: "Probelauf — mit armed:true wird die Aufstellung lokal in Carambus gesetzt (noch keine Übertragung in die ClubCloud).",
            source: source_label(server_context, :db_mirror)
          ))
        end

        ActiveRecord::Base.transaction do
          # Idempotent: bestehende Aufstellung dieser Mannschaft ersetzen. Auf dem Local-Server
          # NUR lokale Seedings (id >= MIN_ID) — globale synced Records bleiben unangetastet
          # (LocalProtector würde sie ohnehin schützen). Auf Authority/Test (kein local_server?)
          # alle Role-Seedings der Party.
          del_scope = party.seedings.where(role: "team_#{team}")
          del_scope = del_scope.where("seedings.id >= ?", Seeding::MIN_ID) if ApplicationRecord.local_server?
          del_scope.destroy_all
          lineup.each do |e|
            Seeding.create!(
              player: e[:player], tournament: party, role: "team_#{team}",
              position: e[:position], playing_discipline: e[:discipline], state: "seeded"
            )
          end
        end
        Rails.logger.info "[cc_set_party_lineup] party=#{party.id} team=#{team} count=#{lineup.length} user=#{server_context&.dig(:user_id)}"

        text(JSON.generate(
          ok: true,
          message: "Aufstellung für #{team_lt.name} lokal in Carambus gesetzt (#{lineup.length} Spieler). Die Übertragung in die ClubCloud erfolgt separat.",
          party: party_brief(party), team: team, team_name: team_lt.name,
          lineup: serialize_lineup(party, team),
          source: source_label(server_context, :db_mirror)
        ))
      rescue => e
        Rails.logger.warn "[SetPartyLineup.call] #{e.class}: #{e.message}"
        error("Tool-Fehler: #{e.class.name} (Details im Server-Log).")
      end

      # Eingabe-Einträge gegen den Mannschaftskader auflösen (Eligibility + Reihenfolge).
      # Returns [lineup, errors]; lineup = [{player:, position:, discipline:}], errors = [String].
      def self.resolve_lineup_entries(entries, roster)
        errors = []
        lineup = entries.each_with_index.map do |raw, idx|
          e = raw.respond_to?(:transform_keys) ? raw.transform_keys(&:to_sym) : {}
          player = resolve_roster_player(e, roster)
          if player.nil?
            label = e[:player_name].presence || e[:player_id] || "Eintrag #{idx + 1}"
            errors << "Spieler '#{label}' ist nicht im Kader dieser Mannschaft."
            next nil
          end
          disc = e[:discipline].present? ? Discipline.find_by("name ILIKE ?", e[:discipline].to_s.strip) : nil
          {player: player, position: (e[:position].presence || (idx + 1)).to_i, discipline: disc}
        end.compact
        [lineup, errors]
      end

      # Spieler eindeutig im Kader auflösen: player_id (exakt) ODER player_name (normalisierte
      # Teilstring-Suche über fullname / "Nachname, Vorname"; nur bei genau EINEM Treffer).
      def self.resolve_roster_player(entry, roster)
        if entry[:player_id].present?
          return roster.find { |p| p.id == entry[:player_id].to_i }
        end
        if entry[:player_name].present?
          q = normalize_for_search(entry[:player_name])
          matches = roster.select do |p|
            normalize_for_search(p.fullname.to_s).include?(q) ||
              normalize_for_search("#{p.lastname}, #{p.firstname}").include?(q)
          end
          return matches.first if matches.length == 1
        end
        nil
      end

      # Aktuelle lokale Aufstellung einer Mannschaft (party-scoped Seedings), nach Position sortiert.
      def self.serialize_lineup(party, team)
        party.seedings.where(role: "team_#{team}").includes(:player, :playing_discipline)
          .sort_by { |s| s.position.to_i }
          .map { |s| {position: s.position, player: s.player&.fullname, discipline: s.playing_discipline&.name} }
      end

      def self.party_brief(party)
        {id: party.id, day_seqno: party.day_seqno, date: party.date&.iso8601,
         team_a: party.league_team_a&.name, team_b: party.league_team_b&.name, league: party.league&.name}
      end
    end
  end
end
