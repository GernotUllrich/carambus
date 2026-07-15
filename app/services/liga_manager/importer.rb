# frozen_string_literal: true

module LigaManager
  # DB-schreibender Struktur-Importer für den TBV-Cutover (Milestone v0.4, Phase 10).
  #
  # Keying-/Guard-Strategie (in Phase 9 festgelegt, .paul/phases/09-import-foundation/09-01-RESEARCH.md):
  # - Erstlauf-Match gegen den migrierten Bestand über die verifizierten v0.3-Matcher (TbvComparison):
  #   Club asso_no ↔ cc_id ODER ba_id · League Branch+Normname · LeagueTeam Verein+Team-Nummer.
  # - Provenienz/Idempotenz über `source_url` (LigaManager-API-URL). cc_id/ba_id/dbu_nr UNANGETASTET.
  # - Default dry-run; Schreiben nur bei armed:true → instance-level update! → PaperTrail-Version →
  #   Regional-Server-Sync; broadcast-frei (skip_cable_ready_updates). LocalProtector schützt globale
  #   Records (id < 50_000_000) auf Nicht-Authority-Servern.
  #
  # 10-01: Club-Reconcile, League-Match, LeagueTeam-Match (Struktur-Container). Legt bei fehlendem
  # Match KEINE neuen Records an (nur Report). Player/SeasonParticipation/Seeding = 10-02;
  # Ergebnisse/PartyGame/GamePlan = Phase 11.
  class Importer
    BASE_URL = "https://ligen.billard.center"

    def initialize(association_id:, region_id:, season_id:, armed: false, scraper: nil)
      @association_id = association_id
      @region_id = region_id
      @season_id = season_id
      @armed = armed
      @scraper = scraper || Scraper.new(association_id: association_id)
    end

    # Fährt Club → League → Team → Player → Seedings → Parties → PartyGames und liefert je Stufe den Report.
    def run
      {clubs: reconcile_clubs, leagues: import_leagues, teams: import_teams,
       players: reconcile_players, seedings: reconcile_seedings, parties: reconcile_parties,
       party_games: import_party_games}
    end

    # Club-Reconcile: LM asso_no ↔ Carambus Club.cc_id ODER ba_id (Region). Setzt source_url der
    # gematchten Clubs (idempotent). Legt KEINE neuen Clubs an — unmatched nur melden.
    def reconcile_clubs
      cb = Club.where(region_id: @region_id).where("cc_id IS NOT NULL OR ba_id IS NOT NULL").to_a
      by_cc = cb.index_by(&:cc_id)
      by_ba = cb.index_by(&:ba_id)
      matched = 0
      updated = 0
      unmatched = []

      @scraper.clubs.each do |c|
        no = c["asso_no"].to_i
        club = by_cc[no] || by_ba[no]
        if club
          matched += 1
          updated += 1 if apply_source_url(club, club_source_url(no))
        else
          unmatched << "#{no} — #{c["name"]}"
        end
      end

      {matched: matched, updated: updated, unmatched: unmatched.sort}
    end

    # League-Match über Region+Season+Branch+Normname (v0.3-Matcher). Setzt source_url=LM-URL.
    # GamePlan-Ableitung ist Phase 11 (CC-GamePlan-Schema ist mit Ergebnisdaten verzahnt).
    def import_leagues
      cb_by_key = carambus_leagues.index_by { |l| league_key(l.discipline&.name, l.name) }
      matched = 0
      updated = 0
      unmatched = []

      lm_leagues.each do |l|
        league = cb_by_key[league_key(l["game_type_name"], l["name"])]
        if league
          matched += 1
          updated += 1 if apply_source_url(league, league_source_url(l["id"]))
        else
          unmatched << "#{l["id"]} — #{l["name"]} (#{l["game_type_name"]})"
        end
      end

      {matched: matched, updated: updated, unmatched: unmatched.sort}
    end

    # LeagueTeam-Match über League+Verein(asso_no↔cc_id/ba_id)+Team-Nummer. Setzt source_url=LM-URL.
    def import_teams
      cb_by_key = carambus_league_teams.index_by { |t| team_key(t.club&.cc_id || t.club&.ba_id, trailing_number(t.name)) }
      club_asso_by_lm_id = @scraper.clubs.to_h { |c| [c["id"], c["asso_no"].to_i] }
      matched = 0
      updated = 0
      unmatched = []

      lm_leagues.each do |l|
        @scraper.teams(l["id"]).each do |t|
          key = team_key(club_asso_by_lm_id[t["club_id"]], t["team_number"])
          team = cb_by_key[key]
          if team
            matched += 1
            updated += 1 if apply_source_url(team, team_source_url(l["id"], t["id"]))
          else
            unmatched << "#{t["id"]} — #{t["name"]} (#{key})"
          end
        end
      end

      {matched: matched, updated: updated, unmatched: unmatched.sort}
    end

    # Player-Reconcile NAMENSBASIERT (die öffentliche LM-API liefert keine dbu_nr, Phase 9):
    # je gematchtem Verein die LM-members über normalisierten fl_name (first_name last_name) gegen
    # den Carambus-Vereins-Saison-Roster (SeasonParticipation) matchen. Genau-1-Treffer → source_url;
    # mehrere Namensträger → :ambiguous (KEINE willkürliche Zuordnung); 0 → :unmatched.
    def reconcile_players
      lm_id_by_asso = @scraper.clubs.to_h { |c| [c["asso_no"].to_i, c["id"]] }
      matched = 0
      updated = 0
      ambiguous = []
      unmatched = []

      carambus_clubs.each do |club|
        lm_club_id = lm_id_by_asso[club.cc_id || club.ba_id]
        next unless lm_club_id

        roster_by_name = SeasonParticipation
          .where(club_id: club.id, season_id: @season_id).includes(:player)
          .group_by { |sp| TbvComparison.normalize_name(sp.player&.fl_name) }

        @scraper.members(lm_club_id).each do |m|
          next unless m["_status"].to_i == 1 # nur aktive LM-Mitglieder (Carambus-Roster = Saison-Teilnehmer)

          fl = "#{m["first_name"]} #{m["last_name"]}".strip
          candidates = Array(roster_by_name[TbvComparison.normalize_name(fl)]).map(&:player).compact.uniq
          case candidates.size
          when 0
            unmatched << "#{lm_club_id}/#{m["id"]} — #{fl} (#{club.name})"
          when 1
            matched += 1
            updated += 1 if apply_source_url(candidates.first, player_source_url(lm_club_id, m["id"]))
          else
            ambiguous << "#{fl} (#{club.name}): #{candidates.map(&:fl_name).join(" | ")}"
          end
        end
      end

      {matched: matched, updated: updated, ambiguous: ambiguous.sort, unmatched: unmatched.sort}
    end

    # Seeding-Reconcile aus der LigaManager-Rangliste (leagues/{id}/ranking): verknüpft je
    # Ranglisten-Eintrag den Carambus-Player (namensbasiert im Vereins-Saison-Roster) mit dem
    # Carambus-LeagueTeam (über LM team_id). Bestehende Seedings zählen als matched; fehlende werden
    # unter armed idempotent angelegt (Natur-Key league_team_id+player_id; Seeding hat kein source_url).
    # Für eindeutig verknüpfte Player wird zusätzlich die bestehende SeasonParticipation mit source_url
    # als Provenienz markiert. KEINE neuen Player. Echte Roster-Lücken (Player nicht im Saison-Roster)
    # landen als :unmatched — deren SeasonParticipation-Anlage braucht breiteres Matching → Plan 10-04.
    def reconcile_seedings
      lt_by_lm_team = lt_by_lm_team_id
      seen = Set.new
      seedings_matched = 0
      seedings_created = 0
      sp_updated = 0
      ambiguous = []
      unmatched = []

      lm_leagues.each do |l|
        @scraper.ranking(l["id"]).values.flatten.each do |row|
          lt = lt_by_lm_team[row["team_id"]]
          unless lt
            unmatched << "#{row["Spielername"]} (Team #{row["team_id"]} nicht migriert)"
            next
          end
          club = lt.club
          candidates = Array(roster_by_name(club)[ranking_name_key(row["Spielername"])])
            .map(&:player).compact.uniq

          case candidates.size
          when 0
            unmatched << "#{row["Spielername"]} (#{club&.name})"
          when 1
            player = candidates.first
            key = [lt.id, player.id]
            next if seen.include?(key) # Dedup: gleicher Spieler in mehreren Disziplin-Ranglisten

            seen << key
            if Seeding.exists?(league_team_id: lt.id, player_id: player.id)
              seedings_matched += 1
            else
              seedings_created += 1
              create_seeding(lt.id, player.id) if @armed
            end
            sp_updated += 1 if mark_season_participation(player, club, row) == :updated
          else
            ambiguous << "#{row["Spielername"]} (#{club&.name}): #{candidates.map(&:fl_name).join(" | ")}"
          end
        end
      end

      {seedings_matched: seedings_matched, seedings_created: seedings_created, sp_updated: sp_updated,
       ambiguous: ambiguous.uniq.sort, unmatched: unmatched.uniq.sort}
    end

    # Party-Reconcile: gleicht LM-Begegnungen (match_plans) über Liga + Mannschafts-Paar
    # (LM-Team → Carambus-LeagueTeam) gegen bestehende Carambus-Parties ab. Bestehende → source_url
    # als Provenienz (Ergebnis/data UNVERÄNDERT). Fehlende gespielte Begegnungen → Party anlegen
    # (league/team_a/team_b/host/date/data{result}/source_url). Begegnungen mit fehlendem Team in
    # Carambus (v.a. Pokal) → :unmatched (kein Anlegen, keine neuen Teams).
    # Idempotenz über (league_id, league_team_a_id, league_team_b_id); Rundenturnier ⇒ pro Saison
    # eindeutig (Hin-/Rückrunde vertauschen a/b).
    def reconcile_parties
      lt_by_lm = lt_by_lm_team_id
      cb_league_by_key = carambus_leagues.index_by { |l| league_key(l.discipline&.name, l.name) }
      # Schlüssel inkl. Datum: dasselbe Team-Paar kann in kleinen Ligen mehrfach in gleicher
      # Richtung an verschiedenen Terminen spielen (Doppel-/Dreifachrunde) — (Liga,Heim,Gast) allein
      # ist NICHT eindeutig. (Liga,Heim,Gast,Datum) ist in Carambus eindeutig.
      cb_party_by_key = Party.where(league_id: carambus_leagues.map(&:id))
        .index_by { |p| [p.league_id, p.league_team_a_id, p.league_team_b_id, party_date_key(p.date)] }
      matched = 0
      updated = 0
      created = 0
      filled = 0
      unmatched = []

      lm_leagues.each do |l|
        cbl = cb_league_by_key[league_key(l["game_type_name"], l["name"])]
        @scraper.match_plans(l["id"]).each do |m|
          a = lt_by_lm[m["home_team_id"]]
          b = lt_by_lm[m["away_team_id"]]
          unless a && b && cbl
            unmatched << "#{m["home_team_name"]} vs #{m["away_team_name"]} (#{m["scheduled_date"]}) — Team/Liga fehlt in Carambus"
            next
          end

          result = "#{m.dig("matchpoints", "total_home_points")}:#{m.dig("matchpoints", "total_guest_points")}"
          party = cb_party_by_key[[cbl.id, a.id, b.id, party_date_key(m["scheduled_date"])]]
          if party
            matched += 1
            updated += 1 if apply_source_url(party, party_source_url(m["id"]))
            filled += 1 if fill_empty_result(party, result)
          else
            created += 1
            create_party(cbl, a, b, m, result) if @armed
          end
        end
      end

      {matched: matched, updated: updated, created: created, filled: filled, unmatched: unmatched.uniq.sort}
    end

    # Einzelspiel-Import (PartyGame): für jede Party mit source_url = ".../api/match-plans/{id}", die
    # noch KEINE Einzelspiele hat, den Spielbericht holen und je game ein PartyGame anlegen
    # (seqno=Position, name="Spiel N::Disziplin", discipline via Synonym/classify, player_a/b namensbasiert
    # im jeweiligen Team-Roster, data{result + stats aus 11-01}). Idempotent über (party_id, seqno).
    # Bestehende Einzelspiele (CC-Parties) werden NICHT angefasst; keine neuen Player/Teams.
    def import_party_games
      parties_processed = 0
      games_created = 0
      players_unmatched = 0
      disciplines_unmatched = 0
      parties_skipped = 0

      carambus_parties_without_games.each do |party|
        mp_id = match_plan_id_from(party.source_url)
        unless mp_id
          parties_skipped += 1
          next
        end

        report = @scraper.match_report(mp_id)
        roster_a = roster_by_league_team(party.league_team_a_id)
        roster_b = roster_by_league_team(party.league_team_b_id)
        parties_processed += 1

        Array(report[:games]).each do |g|
          seqno = g[:position]
          next if seqno.nil? || PartyGame.where(party_id: party.id, seqno: seqno).exists?

          discipline = discipline_for(g[:discipline])
          disciplines_unmatched += 1 if discipline.nil?
          player_a = unique_roster_player(roster_a, g[:home_player])
          player_b = unique_roster_player(roster_b, g[:away_player])
          players_unmatched += 1 if player_a.nil?
          players_unmatched += 1 if player_b.nil?

          games_created += 1
          create_party_game(party, seqno, g, discipline, player_a, player_b) if @armed
        end
      end

      {parties_processed: parties_processed, games_created: games_created,
       players_unmatched: players_unmatched, disciplines_unmatched: disciplines_unmatched,
       parties_skipped: parties_skipped}
    end

    # READ-ONLY GamePlan-Abgleich: der GamePlan ist saisonstabil (CC→LM unverändert). Prüft je Liga die
    # Anzahl der Spiel-Slots im GamePlan (data["rows"] mit seqno) gegen die Anzahl der Einzelspiele einer
    # LM-Beispielbegegnung (naming-unabhängig). Erwartet 0 Diskrepanzen. Schreibt NICHTS, rekonstruiert
    # NICHTS (vgl. reconstruct_game_plans_for_season = saisonweit/alle Regionen = Footgun).
    def check_game_plans
      lm_by_key = lm_leagues.index_by { |l| league_key(l["game_type_name"], l["name"]) }
      carambus_leagues.map do |cbl|
        gp = cbl.game_plan
        lm = lm_by_key[league_key(cbl.discipline&.name, cbl.name)]
        gp_games = gp ? Array(gp.data["rows"]).count { |r| r.is_a?(Hash) && r["seqno"] } : nil
        lm_games = lm ? sample_lm_game_count(lm["id"]) : nil
        status =
          if gp.nil?
            :no_game_plan
          elsif lm.nil?
            :no_lm_league
          elsif lm_games.nil?
            :no_lm_report
          elsif gp_games == lm_games
            :ok
          else
            :discrepancy
          end
        {league: cbl.name, gameplan_games: gp_games, lm_games: lm_games, status: status}
      end
    end

    # Kuratierter Club-Identitäts-Fix: gibt einem Region-Club, dessen Name das Fragment EINDEUTIG
    # enthält und der noch KEIN cc_id trägt, die echte LM-Nummer (cc_id=asso_no) — behebt Clubs mit
    # synthetischer Nummer (z. B. SV Sömmerda → 1567), damit reconcile_clubs sie matcht. Konservativ:
    # nur genau-1-Namens-Treffer mit cc_id nil; ba_id/dbu_nr/Name unangetastet; idempotent; versioniert
    # → Sync, broadcast-frei. fixes = {asso_no => name_fragment} (kuratierte, association-spezifische Liste).
    def assign_club_identity(fixes)
      assigned = 0
      would_assign = 0
      skipped = []
      region_clubs = Club.where(region_id: @region_id).to_a

      fixes.each do |asso_no, fragment|
        frag = TbvComparison.normalize_name(fragment)
        candidates = region_clubs.select { |c| c.cc_id.nil? && TbvComparison.normalize_name(c.name).include?(frag) }
        if candidates.size == 1
          club = candidates.first
          would_assign += 1
          if @armed
            club.class.skip_cable_ready_updates { club.update!(cc_id: asso_no) }
            assigned += 1
          end
        else
          skipped << "#{asso_no} → #{fragment.inspect}: #{candidates.size} Kandidaten mit cc_id nil (nur genau 1 wird zugeordnet)"
        end
      end

      {assigned: assigned, would_assign: would_assign, skipped: skipped.sort}
    end

    private

    # Carambus-Clubs der Region mit Vereinsnummer (cc_id ODER ba_id) — Match-Basis für asso_no.
    def carambus_clubs
      Club.where(region_id: @region_id).where("cc_id IS NOT NULL OR ba_id IS NOT NULL").to_a
    end

    # LigaManager-Ligen aller aktiven/abgeschlossenen Saisons (wie TbvComparison).
    def lm_leagues
      @lm_leagues ||= @scraper.seasons.flat_map { |s| @scraper.leagues(s["id"]) }
    end

    def carambus_leagues
      League.where(region_id: @region_id, season_id: @season_id).includes(:discipline).to_a
    end

    def carambus_league_teams
      LeagueTeam.where(league_id: carambus_leagues.map(&:id)).includes(:club).to_a
    end

    # LM team_id → Carambus LeagueTeam (dieselbe Team-Match-Logik wie import_teams).
    def lt_by_lm_team_id
      cb_by_key = carambus_league_teams.index_by { |t| team_key(t.club&.cc_id || t.club&.ba_id, trailing_number(t.name)) }
      club_asso_by_lm_id = @scraper.clubs.to_h { |c| [c["id"], c["asso_no"].to_i] }
      map = {}
      lm_leagues.each do |l|
        @scraper.teams(l["id"]).each do |t|
          lt = cb_by_key[team_key(club_asso_by_lm_id[t["club_id"]], t["team_number"])]
          map[t["id"]] = lt if lt
        end
      end
      map
    end

    # Vereins-Saison-Roster gruppiert nach normalisiertem fl_name (SeasonParticipation, je Club gecacht).
    def roster_by_name(club)
      (@roster_cache ||= {})[club&.id] ||= SeasonParticipation
        .where(club_id: club&.id, season_id: @season_id).includes(:player)
        .group_by { |sp| TbvComparison.normalize_name(sp.player&.fl_name) }
    end

    # Ranglisten-Name "Nachname, Vorname" → Schlüssel in fl_name-Reihenfolge (Vorname Nachname).
    # normalize_name sortiert NICHT, daher muss die Reihenfolge dem Roster-Schlüssel entsprechen.
    def ranking_name_key(spielername)
      last, first = spielername.to_s.split(",", 2).map(&:strip)
      TbvComparison.normalize_name(first.present? ? "#{first} #{last}" : last.to_s)
    end

    # TBV-Parties der Region/Season OHNE Einzelspiele (nur diese bekommen PartyGames).
    def carambus_parties_without_games
      Party.where(league_id: carambus_leagues.map(&:id))
        .where.missing(:party_games)
        .to_a
    end

    # Extrahiert die match_plan-id aus einer source_url ".../api/match-plans/{id}"; nil sonst.
    def match_plan_id_from(url)
      url.to_s[%r{/api/match-plans/(\d+)}, 1]
    end

    # Spieler eines LeagueTeams (via Seedings) gruppiert nach normalisiertem Namen — Roster für den Match.
    def roster_by_league_team(league_team_id)
      (@lt_roster_cache ||= {})[league_team_id] ||=
        Seeding.where(league_team_id: league_team_id).includes(:player)
          .filter_map(&:player).group_by { |p| TbvComparison.normalize_name(p.fl_name) }
    end

    # Ranglisten-/Berichts-Name "Nachname, Vorname" → eindeutiger Roster-Spieler (nil bei 0/>1).
    def unique_roster_player(roster, spielername)
      candidates = Array(roster[ranking_name_key(spielername)]).uniq
      (candidates.size == 1) ? candidates.first : nil
    end

    # Disziplin über exakten Synonym-Zeilentreffer (wie ClubCloudScraper), Fallback classify_from_title.
    def discipline_for(name)
      return nil if name.to_s.strip.empty?

      (@discipline_cache ||= {})[name] ||= begin
        by_syn = Discipline.where("synonyms ilike ?", "%#{name}%").to_a
          .find { |d| d.synonyms.to_s.split("\n").map(&:strip).include?(name.strip) }
        by_syn || Discipline.classify_from_title(name)
      end
    end

    # Legt ein PartyGame an (broadcast-frei). name = "Spiel N::Disziplin"; data{result + stats}.
    def create_party_game(party, seqno, game, discipline, player_a, player_b)
      data = {"result" => game[:set_result]}
      data["match_points"] = game[:match_points] if game[:match_points].present?
      data["stats"] = game[:stats] if game[:stats]
      PartyGame.skip_cable_ready_updates do
        PartyGame.create!(
          party_id: party.id,
          seqno: seqno,
          name: "Spiel #{seqno}::#{game[:discipline]}",
          discipline_id: discipline&.id,
          player_a_id: player_a&.id,
          player_b_id: player_b&.id,
          data: data
        )
      end
    end

    # Legt eine fehlende Begegnung an (Heim=a, Gast=b, Gastgeber=Heim), broadcast-frei. Ergebnis als
    # data["result"]="H:G"; source_url = LM-Provenienz. Minimal + konsistent zum Bestand (round/party_no nil).
    def create_party(league, home, away, match_plan, result)
      Party.skip_cable_ready_updates do
        Party.create!(
          league_id: league.id,
          league_team_a_id: home.id,
          league_team_b_id: away.id,
          host_league_team_id: home.id,
          date: match_plan["scheduled_date"],
          data: {"result" => result},
          source_url: party_source_url(match_plan["id"])
        )
      end
    end

    # Legt ein Minimal-Seeding an (Player↔LeagueTeam, tournament nil, state registered), broadcast-frei.
    def create_seeding(league_team_id, player_id)
      Seeding.skip_cable_ready_updates do
        Seeding.create!(league_team_id: league_team_id, player_id: player_id)
      end
    end

    # Setzt source_url-Provenienz auf die (bestehende) SeasonParticipation des gematchten Players.
    def mark_season_participation(player, club, row)
      sp = SeasonParticipation.find_by(player_id: player.id, club_id: club&.id, season_id: @season_id)
      return nil unless sp

      apply_source_url(sp, player_source_url(row["club_id"], row["player_id"])) ? :updated : nil
    end

    # Setzt source_url idempotent. true, wenn eine Änderung nötig war (bzw. im dry-run: wäre).
    # Nur bei armed wird tatsächlich geschrieben (instance-level → PaperTrail → Sync, broadcast-frei).
    def apply_source_url(record, url)
      return false if record.source_url == url

      if @armed
        record.class.skip_cable_ready_updates do
          record.update!(source_url: url)
        end
      end
      true
    end

    # --- Provenienz-URLs (LigaManager-API-Ressourcen; stabil + eindeutig) ---

    def club_source_url(asso_no)
      "#{BASE_URL}/api/clubs/public?association_id=#{@association_id}&asso_no=#{asso_no}"
    end

    def league_source_url(lm_id)
      "#{BASE_URL}/api/leagues/#{lm_id}"
    end

    def team_source_url(lm_league_id, lm_team_id)
      "#{BASE_URL}/api/teams?league_id=#{lm_league_id}&id=#{lm_team_id}"
    end

    def player_source_url(lm_club_id, member_id)
      "#{BASE_URL}/api/members/public?club_id=#{lm_club_id}&id=#{member_id}"
    end

    def party_source_url(match_plan_id)
      "#{BASE_URL}/api/match-plans/#{match_plan_id}"
    end

    # Anzahl der Einzelspiele einer gespielten LM-Beispielbegegnung der Liga (read-only, für check_game_plans).
    def sample_lm_game_count(lm_league_id)
      mp = @scraper.match_plans(lm_league_id).find { |m| m["is_completed"] || m["matchpoints"].is_a?(Hash) }
      return nil unless mp

      Array(@scraper.match_report(mp["id"])[:games]).size
    end

    # Normalisiert CB-Datetime (Party#date) und LM-Datumsstring ("2026-02-14") auf "YYYY-MM-DD".
    def party_date_key(date)
      date.respond_to?(:to_date) ? date.to_date.to_s : date.to_s[0, 10]
    end

    # Füllt data["result"] NUR wenn das Carambus-Ergebnis leer ist (CC-Ruhephase-Platzhalter);
    # überschreibt NIE ein vorhandenes Ergebnis. LM-Ergebnis muss selbst nicht-leer sein.
    def fill_empty_result(party, result)
      return false unless blank_result?(party.data)
      return false if result.gsub(/[^0-9]/, "").empty?

      if @armed
        party.class.skip_cable_ready_updates do
          party.update!(data: (party.data || {}).merge("result" => result))
        end
      end
      true
    end

    def blank_result?(data)
      (data.is_a?(Hash) ? data["result"].to_s : "").gsub(/[^0-9]/, "").empty?
    end

    # --- Match-Schlüssel (identisch zu TbvComparison, dort private) ---

    def league_key(discipline_or_game_type, name)
      "#{TbvComparison.normalize_name(branch_name(discipline_or_game_type))}|#{sorted_name_key(name)}"
    end

    # Wortreihenfolge-insensitiver Namensschlüssel: Token sortieren, dann verketten. Löst
    # Wortumstellungen („Mehrkampf Oberliga" ↔ „Oberliga Mehrkampf"), da beide Seiten identisch
    # sortiert werden (order-erhaltend für bereits matchende Paare). Echte Wortvarianten bleiben Rest.
    def sorted_name_key(name)
      TbvComparison.normalize_name(name).split(" ").sort.join
    end

    def team_key(club_key, number)
      "#{club_key}##{number}"
    end

    def trailing_number(name)
      name.to_s[/(\d+)\s*\z/, 1]
    end

    # Bringt LigaManager-game_type-Namen und Carambus-Disziplin-Namen auf denselben Branch-Nenner.
    def branch_name(name)
      TbvComparison.normalize_name(name.to_s)
        .then { |n| n.start_with?("karambol", "kegel", "pool", "snooker") ? n.split(" ").first : n }
    end
  end
end
