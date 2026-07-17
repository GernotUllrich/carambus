# frozen_string_literal: true

module NuLiga
  # Read-only Struktur-/Deckungs-Abgleich Carambus ↔ NuLiga (BBV) für eine Saison. Beide Seiten
  # read-only (AR-Queries + Scraper), KEINE Persistenz (Import = Phase 16). Liefert einen
  # Diskrepanz-/Deckungs-Report als reine Hashes. Vorbild: LigaManager::TbvComparison.
  #
  # Matching:
  # - Clubs:   NuLiga-VNr (aus clubInfoDisplay) ↔ Carambus cc_id ODER ba_id (PRIMÄR), sonst namensbasiert.
  #            (Der NuLiga-URL-Param club=<id> ist intern und NICHT die VNr.)
  # - Leagues: Branch (Sparte) + normalisierter Name (space-insensitiv).
  # - Teams:   normalisierter Team-Name (space-insensitiv).
  # - Players: namensbasiert („Nachname, Vorname" ↔ lastname/firstname), genau-1/ambiguous/nur-NuLiga.
  class Comparison
    RECHTSFORM_RE = /\b(?:e\.?\s?v\.?|ev|gmbh)\b/i

    def initialize(federation:, region_id:, season_id:, branches: Scraper::BRANCHES, scraper: nil)
      @federation = federation
      @region_id = region_id
      @season_id = season_id
      @branches = branches
      @scraper = scraper || Scraper.new(federation: federation, season: Season.find(season_id).name)
    end

    def run
      {clubs: compare_clubs, leagues: compare_leagues, teams: compare_teams, players: compare_players}
    end

    # --- Reine Helfer (DB-/HTTP-frei, unit-testbar) ------------------------------------

    def self.normalize_name(str)
      str.to_s.downcase
        .gsub(RECHTSFORM_RE, " ")
        .gsub(/[^a-z0-9äöüß]+/, " ")
        .strip
        .squeeze(" ")
    end

    # Space-insensitiver Schlüssel (deutsche Komposita); Reihenfolge bleibt erhalten.
    def self.normalize_key(str)
      normalize_name(str).delete(" ")
    end

    # Vergleicht zwei { key => label }-Maps → {matched, only_nuliga, only_carambus, mismatches}.
    def self.diff_maps(nu_map, cb_map)
      common = nu_map.keys & cb_map.keys
      mismatches = common.select { |k| normalize_name(nu_map[k]) != normalize_name(cb_map[k]) }
        .map { |k| {key: k, nu: nu_map[k], cb: cb_map[k]} }
      {
        matched: common.size,
        only_nuliga: (nu_map.keys - cb_map.keys).sort_by(&:to_s).map { |k| "#{k} — #{nu_map[k]}" },
        only_carambus: (cb_map.keys - nu_map.keys).sort_by(&:to_s).map { |k| "#{k} — #{cb_map[k]}" },
        mismatches: mismatches
      }
    end

    private

    def norm(str) = self.class.normalize_name(str)

    # --- Clubs: VNr-primär, namensbasiert-Fallback ---
    def compare_clubs
      cb = carambus_clubs.to_a
      by_cc = cb.index_by(&:cc_id)
      by_ba = cb.index_by(&:ba_id)
      matched = []
      by_vnr = 0
      by_name = 0
      only_nu = []
      mismatches = []

      nuliga_clubs.each do |c|
        hit = c[:vnr] && (by_cc[c[:vnr]] || by_ba[c[:vnr]])
        if hit
          by_vnr += 1
          matched << hit
          mismatches << {vnr: c[:vnr], nu: c[:name], cb: hit.name} unless name_matches?(c[:name], hit)
        elsif (nmatch = match_club_by_name(c[:name], cb))
          by_name += 1
          matched << nmatch
        else
          only_nu << "#{c[:vnr] || "club=#{c[:club_id]}"} — #{c[:name]}"
        end
      end

      matched.uniq!
      only_cb = (cb - matched).map { |x| "#{x.cc_id || x.ba_id} — #{x.name}" }
      {matched: matched.size, matched_by_vnr: by_vnr, matched_by_name: by_name,
       only_nuliga: only_nu.sort, only_carambus: only_cb.sort, mismatches: mismatches}
    end

    def name_matches?(nu_name, cb)
      n = norm(nu_name)
      n == norm(cb.name) || n == norm(cb.shortname)
    end

    def match_club_by_name(nu_name, cb_list)
      n = norm(nu_name)
      cb_list.find { |x| norm(x.name) == n || norm(x.shortname) == n }
    end

    # --- Leagues: Branch + Name (Saison-Deckung) ---
    def compare_leagues
      nu = nuliga_leagues.to_h { |l| [league_key(l[:branch], l[:name]), l[:name].to_s] }
      cb = carambus_leagues.to_h { |l| [league_key(branch_name(l.discipline&.name), l.name), l.name.to_s] }
      self.class.diff_maps(nu, cb)
    end

    # --- Teams: normalisierter Team-Name (Saison-Deckung) ---
    def compare_teams
      nu = nuliga_teams.to_h { |t| [self.class.normalize_key(t[:name]), t[:name].to_s] }
      cb = carambus_league_teams.to_h { |t| [self.class.normalize_key(t.name), t.name.to_s] }
      self.class.diff_maps(nu, cb)
    end

    # --- Players: namensbasiert (matched/ambiguous/nur-NuLiga) ---
    def compare_players
      index = Hash.new(0)
      carambus_player_names.each { |name| index[norm(name)] += 1 }

      matched = 0
      ambiguous = []
      only_nu = []
      nuliga_player_names.each do |name|
        n = index[norm(name)]
        case n
        when 0 then only_nu << name
        when 1 then matched += 1
        else ambiguous << name
        end
      end
      {matched: matched, ambiguous: ambiguous.sort, only_nuliga: only_nu.sort}
    end

    # --- NuLiga-Seite (read-only via Scraper; Branch-Fehler → Branch überspringen) ---

    def nuliga_leagues
      @nuliga_leagues ||= @branches.flat_map do |branch|
        @scraper.leagues(branch).map { |l| l.merge(branch: branch) }
      rescue => e
        Rails.logger.warn("NuLiga::Comparison leagues(#{branch}) übersprungen: #{e.message}")
        []
      end
    end

    # [{branch:, group_id:, name:, teamtable_id:}] — Teams je Liga (group).
    def nuliga_teams
      @nuliga_teams ||= nuliga_leagues.flat_map do |l|
        @scraper.group(l[:group_id], branch: l[:branch])[:teams].map do |t|
          {branch: l[:branch], group_id: l[:group_id], teamtable_id: t[:teamtable_id], name: t[:name]}
        end
      rescue => e
        Rails.logger.warn("NuLiga::Comparison group(#{l[:group_id]}) übersprungen: #{e.message}")
        []
      end
    end

    # Eindeutige NuLiga-Clubs (mit VNr) über teamPortrait(team)→club_id→clubInfoDisplay(club).
    def nuliga_clubs
      @nuliga_clubs ||= begin
        club_ids = nuliga_teams.filter_map do |t|
          @scraper.team(t[:teamtable_id], group_id: t[:group_id], branch: t[:branch])[:club][:club_id]
        rescue => e
          Rails.logger.warn("NuLiga::Comparison team(#{t[:teamtable_id]}) übersprungen: #{e.message}")
          nil
        end
        club_ids.uniq.filter_map do |cid|
          @scraper.club(cid)
        rescue => e
          Rails.logger.warn("NuLiga::Comparison club(#{cid}) übersprungen: #{e.message}")
          nil
        end
      end
    end

    def nuliga_player_names
      @nuliga_player_names ||= nuliga_leagues.flat_map do |l|
        @scraper.player_ranking(l[:group_id], branch: l[:branch]).map { |p| p[:name] }
      rescue => e
        Rails.logger.warn("NuLiga::Comparison player_ranking(#{l[:group_id]}) übersprungen: #{e.message}")
        []
      end.uniq
    end

    # --- Carambus-Seite (read-only via ActiveRecord) ---

    def carambus_clubs
      Club.where(region_id: @region_id)
    end

    def carambus_leagues
      League.where(region_id: @region_id, season_id: @season_id).includes(:discipline)
    end

    def carambus_league_teams
      LeagueTeam.where(league_id: carambus_leagues.select(:id)).includes(:club)
    end

    def carambus_player_names
      Player.where(region_id: @region_id).pluck(:lastname, :firstname).map { |l, f| "#{l} #{f}" }
    end

    # --- Schlüssel/Branch ---

    def league_key(branch, name)
      "#{norm(branch)}|#{self.class.normalize_key(name)}"
    end

    # Carambus-Disziplin-Name → Branch-Nenner (Pool/Snooker/Karambol/Kegel).
    def branch_name(name)
      norm(name.to_s).then { |n| n.start_with?("karambol", "kegel", "pool", "snooker") ? n.split(" ").first : n }
    end
  end
end
