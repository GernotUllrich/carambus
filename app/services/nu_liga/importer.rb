# frozen_string_literal: true

module NuLiga
  # DB-schreibender Struktur-Importer für BBV/NuLiga (Milestone v0.5, Phase 16).
  #
  # Guard-Strategie (Vorbild LigaManager::Importer): Default dry-run; Schreiben nur bei armed:true →
  # instance-level create!/update! → PaperTrail-Version → Regional-Server-Sync; broadcast-frei
  # (skip_cable_ready_updates). LocalProtector schützt globale Records (id < 50_000_000) auf
  # Nicht-Authority-Servern. Keine Migration.
  #
  # KERNUNTERSCHIED zu LigaManager::Importer: die BBV-Saison 2025/26 ist in Carambus LEER →
  # dieser Importer LEGT Leagues + LeagueTeams NEU AN (find-or-create über Natur-Key, idempotent),
  # statt nur bestehende Records zu reconcilieren.
  #
  # 16-01: Struktur-Skelett — reconcile_clubs (VNr↔cc_id/ba_id + Namens-Gegenprobe, keine Neuanlage),
  # create_leagues, create_teams. Players/Seedings = 16-02; Parties/PartyGames = Phase 17.
  #
  # Match-Strategie (Phase 15 belegt):
  # - Clubs:   NuLiga-VNr (clubInfoDisplay) ↔ Carambus cc_id ODER ba_id (PRIMÄR); Namens-Gegenprobe → Review.
  # - Leagues: Branch (Sparte) + normalisierter Name; Discipline = Branch (Discipline.find_by(name:)).
  # - Teams:   League + normalisierter Team-Name; club_id über die VNr des Teams.
  class Importer
    def initialize(federation:, region_id:, season_id:, branches: Scraper::BRANCHES, armed: false, scraper: nil)
      @federation = federation
      @region_id = region_id
      @season_id = season_id
      @branches = branches
      @armed = armed
      @scraper = scraper || Scraper.new(federation: federation, season: Season.find(season_id).name)
      @leagues_by_group = {}
    end

    def run
      {clubs: reconcile_clubs, leagues: create_leagues, teams: create_teams,
       players: reconcile_players, seedings: reconcile_seedings}
    end

    # Club-Reconcile: NuLiga-VNr ↔ Carambus cc_id/ba_id (PRIMÄR). Setzt source_url der gematchten Clubs
    # (idempotent). Namens-Gegenprobe → name_mismatches (Review, KEIN Write darüber). Keine Club-Neuanlage.
    def reconcile_clubs
      cb = carambus_clubs
      matched = 0
      updated = 0
      name_mismatches = []
      unmatched = []

      nuliga_clubs.each do |c|
        hit = c[:vnr] && (cb[:by_cc][c[:vnr]] || cb[:by_ba][c[:vnr]])
        if hit
          matched += 1
          updated += 1 if apply_source_url(hit, club_source_url(c[:club_id]))
          unless name_matches?(c[:name], hit)
            name_mismatches << {vnr: c[:vnr], nu: c[:name], cb: hit.name}
            mismatch_vnrs << c[:vnr] # 16-02: solche VNr NICHT für Team-club_id verwenden (falscher Verein)
          end
        else
          unmatched << "#{c[:vnr] || "club=#{c[:club_id]}"} — #{c[:name]}"
        end
      end

      {matched: matched, updated: updated, name_mismatches: name_mismatches, unmatched: unmatched.sort}
    end

    # League find-or-create: Natur-Key region/season/Branch|Name. Discipline = Branch (fehlt → skip+melden).
    # Füllt @leagues_by_group (group_id → League) für create_teams.
    def create_leagues
      index = League.where(region_id: @region_id, season_id: @season_id).includes(:discipline)
        .index_by { |l| league_key(l.discipline&.name, l.name) }
      matched = 0
      created = 0
      updated = 0
      skipped = []

      nuliga_leagues.each do |l|
        existing = index[league_key(l[:branch], l[:name])]
        if existing
          matched += 1
          updated += 1 if apply_source_url(existing, league_source_url(l[:group_id]))
          @leagues_by_group[l[:group_id]] = existing
          next
        end

        discipline = Discipline.find_by(name: l[:branch])
        unless discipline
          skipped << "#{l[:group_id]} — #{l[:name]} (#{l[:branch]}: keine Discipline)"
          next
        end

        if @armed
          league = create_league(l, discipline)
          if league
            created += 1
            @leagues_by_group[l[:group_id]] = league
          else
            skipped << "#{l[:group_id]} — #{l[:name]} (create fehlgeschlagen)"
          end
        else
          created += 1
        end
      end

      {matched: matched, created: created, updated: updated, skipped: skipped.sort}
    end

    # LeagueTeam find-or-create: Natur-Key league_id + normalisierter Name. club_id über die Team-VNr.
    # 16-02: bei VNr-Namens-Mismatch KEIN club_id (nil statt falscher Verein) → club_mismatch-Report.
    def create_teams
      created = 0
      updated = 0
      club_unmatched = []
      club_mismatch = []
      league_missing = []

      nuliga_teams.each do |t|
        league = @leagues_by_group[t[:group_id]]
        unless league
          # In dry-run existiert eine neu-anzulegende Liga noch nicht → Team zählt als „würde anlegen".
          if @armed
            league_missing << "#{t[:teamtable_id]} — #{t[:name]} (Liga #{t[:group_id]} fehlt)"
          else
            created += 1
          end
          next
        end

        existing = league_team_index(league.id)[Comparison.normalize_key(t[:name])]
        if existing
          updated += 1 if apply_source_url(existing, team_source_url(t[:teamtable_id]))
          next
        end

        club = carambus_club_for(t[:club_id])
        if club.nil? && mismatch_vnr_for?(t[:club_id])
          club_mismatch << "#{t[:teamtable_id]} — #{t[:name]} (VNr-Namens-Mismatch → club_id nil)"
        elsif club.nil?
          club_unmatched << "#{t[:teamtable_id]} — #{t[:name]} (club=#{t[:club_id]})"
        end
        created += 1
        create_team(league, t, club) if @armed
      end

      {created: created, updated: updated, club_unmatched: club_unmatched.sort,
       club_mismatch: club_mismatch.sort, league_missing: league_missing.sort}
    end

    # Player-Reconcile: Roster je Liga (player_ranking) namensbasiert geschichtet (Club-scoped → Region-
    # Fallback). genau-1 → SeasonParticipation (club/season) mit source_url; >1 → ambiguous (skip);
    # 0 → neuer Player (region, source_url) + SeasonParticipation. Füllt @roster_links für Seedings.
    def reconcile_players
      matched = 0
      created = 0
      ambiguous = []
      sp_updated = 0
      @roster_links = []

      nuliga_roster.each do |r|
        lt = r[:league_team]
        club = lt&.club
        player, kind = resolve_player(r[:name], club, r[:person_id])
        case kind
        when :ambiguous
          ambiguous << "#{r[:name]} (#{club&.name || "?"})"
          next
        when :matched then matched += 1
        when :created then created += 1
        end
        next unless player

        @roster_links << {player: player, league_team: lt} if lt
        sp_updated += 1 if mark_season_participation(player, club, r[:person_id]) == :updated
      end

      {matched: matched, created: created, ambiguous: ambiguous.sort, sp_updated: sp_updated}
    end

    # Seeding-Reconcile: je @roster_links-Paar (Player, LeagueTeam) ein Seeding (Natur-Key, dedupliziert).
    def reconcile_seedings
      seen = Set.new
      seedings_matched = 0
      seedings_created = 0
      unmatched = []

      Array(@roster_links).each do |link|
        lt = link[:league_team]
        player = link[:player]
        key = [lt.id, player.id]
        next if seen.include?(key)

        seen << key
        if Seeding.exists?(league_team_id: lt.id, player_id: player.id)
          seedings_matched += 1
        else
          seedings_created += 1
          create_seeding(lt.id, player.id) if @armed
        end
      end

      {seedings_matched: seedings_matched, seedings_created: seedings_created, unmatched: unmatched.uniq.sort}
    end

    private

    # --- Schreib-Guard (nur bei @armed; broadcast-frei; instance-level → PaperTrail → Sync) ---

    def apply_source_url(record, url)
      return false if record.source_url == url

      if @armed
        record.class.skip_cable_ready_updates do
          record.update!(source_url: url)
        end
      end
      true
    end

    # Legt eine League an — organizer=Region (konsistent zum BBV-Bestand); shortname aus dem Namen
    # abgeleitet (Validierung verlangt shortname bei organizer_type=='Region'). nil bei Validierungsfehler
    # (z.B. Name-Kollision im uniqueness-Scope) — der Aufrufer meldet den Fehldruck, statt abzubrechen.
    def create_league(nu_league, discipline)
      League.skip_cable_ready_updates do
        League.create!(
          region_id: @region_id,
          season_id: @season_id,
          organizer_type: "Region",
          organizer_id: @region_id,
          discipline_id: discipline.id,
          name: nu_league[:name],
          shortname: nu_league[:name],
          source_url: league_source_url(nu_league[:group_id])
        )
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn("NuLiga::Importer create_league(#{nu_league[:name]}) fehlgeschlagen: #{e.message}")
      nil
    end

    def create_team(league, nu_team, club)
      LeagueTeam.skip_cable_ready_updates do
        LeagueTeam.create!(
          league_id: league.id,
          name: nu_team[:name],
          club_id: club&.id,
          source_url: team_source_url(nu_team[:teamtable_id])
        )
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn("NuLiga::Importer create_team(#{nu_team[:name]}) fehlgeschlagen: #{e.message}")
      nil
    end

    # --- Carambus-Seite (read-only-Lookups) ---

    def carambus_clubs
      @carambus_clubs ||= begin
        list = Club.where(region_id: @region_id).to_a
        {list: list, by_cc: list.index_by(&:cc_id), by_ba: list.index_by(&:ba_id)}
      end
    end

    # NuLiga-club_id → Carambus-Club über die VNr (cc_id/ba_id). nil, wenn keine VNr/kein Treffer
    # ODER die VNr ein Namens-Mismatch ist (16-02: dann NICHT den falsch benannten Verein verknüpfen).
    def carambus_club_for(nuliga_club_id)
      vnr = vnr_by_nuliga_id[nuliga_club_id]
      return nil unless vnr
      return nil if mismatch_vnrs.include?(vnr)

      carambus_clubs[:by_cc][vnr] || carambus_clubs[:by_ba][vnr]
    end

    def vnr_by_nuliga_id
      @vnr_by_nuliga_id ||= nuliga_clubs.to_h { |c| [c[:club_id], c[:vnr]] }
    end

    # Set der VNrs, deren Carambus-Club namentlich abweicht (aus reconcile_clubs; leer bis reconcile_clubs lief).
    def mismatch_vnrs
      @mismatch_vnrs ||= Set.new
    end

    # true, wenn die VNr des NuLiga-club_id ein Namens-Mismatch ist (für create_teams-Report).
    def mismatch_vnr_for?(nuliga_club_id)
      vnr = vnr_by_nuliga_id[nuliga_club_id]
      vnr && mismatch_vnrs.include?(vnr)
    end

    def league_team_index(league_id)
      (@league_team_index ||= {})[league_id] ||=
        LeagueTeam.where(league_id: league_id).index_by { |t| Comparison.normalize_key(t.name) }
    end

    def name_matches?(nu_name, cb)
      n = Comparison.normalize_name(nu_name)
      n == Comparison.normalize_name(cb.name) || n == Comparison.normalize_name(cb.shortname)
    end

    def league_key(branch, name)
      "#{Comparison.normalize_name(branch)}|#{Comparison.normalize_key(name)}"
    end

    # --- NuLiga-Seite (read-only via Scraper; Fehler je Ebene → überspringen) ---

    def nuliga_leagues
      @nuliga_leagues ||= @branches.flat_map do |branch|
        @scraper.leagues(branch).map { |l| l.merge(branch: branch) }
      rescue => e
        Rails.logger.warn("NuLiga::Importer leagues(#{branch}) übersprungen: #{e.message}")
        []
      end
    end

    # [{group_id:, branch:, teamtable_id:, name:, club_id:}] — Team + NuLiga-club_id (via teamPortrait).
    def nuliga_teams
      @nuliga_teams ||= nuliga_leagues.flat_map do |l|
        @scraper.group(l[:group_id], branch: l[:branch])[:teams].map do |t|
          {group_id: l[:group_id], branch: l[:branch], teamtable_id: t[:teamtable_id], name: t[:name],
           club_id: team_club_id(t[:teamtable_id], l[:group_id], l[:branch])}
        end
      rescue => e
        Rails.logger.warn("NuLiga::Importer group(#{l[:group_id]}) übersprungen: #{e.message}")
        []
      end
    end

    def team_club_id(teamtable_id, group_id, branch)
      @scraper.team(teamtable_id, group_id: group_id, branch: branch)[:club][:club_id]
    rescue => e
      Rails.logger.warn("NuLiga::Importer team(#{teamtable_id}) übersprungen: #{e.message}")
      nil
    end

    # Eindeutige NuLiga-Clubs (mit VNr) über die club_ids der Teams.
    def nuliga_clubs
      @nuliga_clubs ||= nuliga_teams.map { |t| t[:club_id] }.compact.uniq.filter_map do |cid|
        @scraper.club(cid)
      rescue => e
        Rails.logger.warn("NuLiga::Importer club(#{cid}) übersprungen: #{e.message}")
        nil
      end
    end

    # Roster je Liga (player_ranking) mit aufgelöstem Carambus-LeagueTeam (über team_name).
    # [{person_id:, name:, league_team:}] — league_team nil, wenn die Liga (dry-run) noch nicht angelegt ist.
    def nuliga_roster
      @nuliga_roster ||= nuliga_leagues.flat_map do |l|
        league = @leagues_by_group[l[:group_id]]
        # Frischer Team-Index (nach create_teams gebaut) — NICHT die create_teams-Memo (die entstand vor der Anlage).
        lt_index = league ? LeagueTeam.where(league_id: league.id).index_by { |t| Comparison.normalize_key(t.name) } : {}
        @scraper.player_ranking(l[:group_id], branch: l[:branch]).map do |p|
          {person_id: p[:person_id], name: p[:name], league_team: lt_index[Comparison.normalize_key(p[:team_name])]}
        end
      rescue => e
        Rails.logger.warn("NuLiga::Importer player_ranking(#{l[:group_id]}) übersprungen: #{e.message}")
        []
      end
    end

    # --- Player-Match (geschichtet: Club-scoped → Region-Fallback) + Neuanlage ---

    # → [player_or_nil, :matched|:ambiguous|:created]
    def resolve_player(name, club, person_id)
      key = Comparison.normalize_name(name)
      if club
        cands = club_players_by_key(club)[key] || []
        return [cands.first, :matched] if cands.size == 1
        return [nil, :ambiguous] if cands.size > 1
      end

      rcands = region_players_by_key[key] || []
      case rcands.size
      when 1 then [rcands.first, :matched]
      when 0 then [(@armed ? create_player(name, person_id) : nil), :created]
      else [nil, :ambiguous]
      end
    end

    def club_players_by_key(club)
      (@club_players ||= {})[club.id] ||=
        (Player.where(club_id: club.id).to_a + club.players.to_a).uniq
          .group_by { |p| player_key_for(p) }
    end

    def region_players_by_key
      @region_players_by_key ||=
        Player.where(region_id: @region_id).to_a.group_by { |p| player_key_for(p) }
    end

    def player_key_for(player)
      Comparison.normalize_name("#{player.lastname} #{player.firstname}")
    end

    # „Nachname, Vorname" → [lastname, firstname]; ohne Komma → [name, ""].
    def split_name(name)
      last, first = name.to_s.split(",", 2).map(&:strip)
      [last.to_s, first.to_s]
    end

    def create_player(name, person_id)
      last, first = split_name(name)
      player = Player.skip_cable_ready_updates do
        Player.create!(lastname: last, firstname: first, region_id: @region_id,
          source_url: player_source_url(person_id))
      end
      (region_players_by_key[player_key_for(player)] ||= []) << player # Dedup: nicht doppelt anlegen im Lauf
      player
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn("NuLiga::Importer create_player(#{name}) fehlgeschlagen: #{e.message}")
      nil
    end

    # SeasonParticipation find-or-create (Player↔Club↔Season) mit source_url-Provenienz. :updated wenn
    # angelegt/geändert (bzw. im dry-run „würde"), sonst nil.
    def mark_season_participation(player, club, person_id)
      return nil unless player && club

      sp = SeasonParticipation.find_by(player_id: player.id, club_id: club.id, season_id: @season_id)
      if sp
        apply_source_url(sp, player_source_url(person_id)) ? :updated : nil
      elsif @armed
        SeasonParticipation.skip_cable_ready_updates do
          SeasonParticipation.create!(player_id: player.id, club_id: club.id, season_id: @season_id,
            region_id: @region_id, source_url: player_source_url(person_id))
        end
        :updated
      else
        :updated
      end
    end

    def create_seeding(league_team_id, player_id)
      Seeding.skip_cable_ready_updates do
        Seeding.create!(league_team_id: league_team_id, player_id: player_id)
      end
    end

    # --- Provenienz-URLs (NuLiga-Ressourcen; stabil + eindeutig) ---

    def nuliga_base
      "#{Client::DEFAULT_BASE_URL}#{Client::WA_PATH}"
    end

    def club_source_url(club_id)
      "#{nuliga_base}/clubInfoDisplay?club=#{club_id}"
    end

    def league_source_url(group_id)
      "#{nuliga_base}/groupPage?group=#{group_id}"
    end

    def team_source_url(teamtable_id)
      "#{nuliga_base}/teamPortrait?teamtable=#{teamtable_id}"
    end

    def player_source_url(person_id)
      "#{nuliga_base}/playerPortrait?person=#{person_id}"
    end
  end
end
