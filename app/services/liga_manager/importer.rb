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

    # Fährt Club → League → Team → Player → Seedings und liefert je Stufe den Reconcile-Report.
    def run
      {clubs: reconcile_clubs, leagues: import_leagues, teams: import_teams,
       players: reconcile_players, seedings: reconcile_seedings}
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
