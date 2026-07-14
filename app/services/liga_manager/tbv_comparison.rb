# frozen_string_literal: true

module LigaManager
  # Struktur-Abgleich CC↔LigaManager für einen Verband (Pilot TBV): vergleicht Vereine,
  # Ligen und Teams beider Seiten und liefert einen Diskrepanz-Report. Read-only auf beiden
  # Seiten — KEINE Persistenz (Import/Mapping-Write ist Phase 9).
  #
  # Matching:
  # - Vereine: LigaManager asso_no ↔ Carambus Club.ba_id (exakt, verifiziert in Phase 6)
  # - Ligen:   Disziplin (game_type/Branch) + normalisierter Name
  # - Teams:   Verein (asso_no↔ba_id) + Team-Nummer
  class TbvComparison
    RECHTSFORM_RE = /\b(?:e\.?\s?v\.?|ev|gmbh)\b/i

    def initialize(association_id:, region_id:, season_id:, scraper: nil)
      @association_id = association_id
      @region_id = region_id
      @season_id = season_id
      @scraper = scraper || Scraper.new(association_id: association_id)
    end

    def run
      {clubs: compare_clubs, leagues: compare_leagues, teams: compare_teams}
    end

    # --- Reine Helfer (DB-/HTTP-frei, unit-testbar) ------------------------------------

    # Normalisiert einen Vereins-/Team-/Liga-Namen für den Vergleich: Kleinschreibung,
    # Rechtsform (e.V./GmbH) entfernen, Interpunktion/Whitespace vereinheitlichen.
    def self.normalize_name(str)
      str.to_s.downcase
        .gsub(RECHTSFORM_RE, " ")
        .gsub(/[^a-z0-9äöüß]+/, " ")
        .strip
        .squeeze(" ")
    end

    # Schlüssel-Normalisierung für Liga-Namen: space-insensitiv (deutsche Komposita
    # "Dreiband Oberliga - Staffel A" == "Dreibandoberliga Staffel A"). Reihenfolge bleibt
    # erhalten — echte Wortumstellungen (z.B. "Mehrkampf Oberliga" vs "Oberliga Mehrkampf")
    # bleiben als Review-Fall in only_LM/only_Carambus sichtbar (kein Über-Matchen).
    def self.normalize_key(str)
      normalize_name(str).delete(" ")
    end

    # Vergleicht zwei { key => label }-Maps → {matched, only_lm, only_carambus, mismatches}.
    # matched = Zähler gemeinsamer Keys; mismatches = gemeinsamer Key, aber Label unterscheidet
    # sich nach normalize_name.
    def self.diff_maps(lm_map, cb_map)
      common = lm_map.keys & cb_map.keys
      mismatches = common.select { |k| normalize_name(lm_map[k]) != normalize_name(cb_map[k]) }
        .map { |k| {key: k, lm: lm_map[k], cb: cb_map[k]} }
      {
        matched: common.size,
        only_lm: (lm_map.keys - cb_map.keys).sort_by(&:to_s).map { |k| "#{k} — #{lm_map[k]}" },
        only_carambus: (cb_map.keys - lm_map.keys).sort_by(&:to_s).map { |k| "#{k} — #{cb_map[k]}" },
        mismatches: mismatches
      }
    end

    private

    def norm(str) = self.class.normalize_name(str)

    def compare_clubs
      lm = @scraper.clubs.to_h { |c| [c["asso_no"].to_i, c["name"].to_s] }
      cb = carambus_clubs.to_h { |c| [c.ba_id, c.name.to_s] }
      self.class.diff_maps(lm, cb)
    end

    def compare_leagues
      lm = lm_leagues.to_h { |l| [league_key(l["game_type_name"], l["name"]), l["name"].to_s] }
      cb = carambus_leagues.to_h { |l| [league_key(l.discipline&.name, l.name), l.name.to_s] }
      self.class.diff_maps(lm, cb)
    end

    def compare_teams
      club_by_lm_id = @scraper.clubs.to_h { |c| [c["id"], c["asso_no"].to_i] }
      lm = lm_teams.to_h do |t|
        [team_key(club_by_lm_id[t["club_id"]], t["team_number"]), t["name"].to_s]
      end
      cb = carambus_league_teams.to_h do |t|
        [team_key(t.club&.ba_id, t.name.to_s[/(\d+)\s*\z/, 1]), t.name.to_s]
      end
      self.class.diff_maps(lm, cb)
    end

    # --- LigaManager-Seite (read-only via Scraper) ---

    def lm_leagues
      @lm_leagues ||= @scraper.seasons.flat_map { |s| @scraper.leagues(s["id"]) }
    end

    def lm_teams
      @lm_teams ||= lm_leagues.flat_map { |l| @scraper.teams(l["id"]) }
    end

    # --- Carambus-Seite (read-only via ActiveRecord) ---

    def carambus_clubs
      Club.where(region_id: @region_id).where.not(ba_id: nil)
    end

    def carambus_leagues
      League.where(region_id: @region_id, season_id: @season_id).includes(:discipline)
    end

    def carambus_league_teams
      LeagueTeam.where(league_id: carambus_leagues.select(:id)).includes(:club)
    end

    # --- Schlüssel ---

    def league_key(discipline_or_game_type, name)
      "#{norm(branch_name(discipline_or_game_type))}|#{self.class.normalize_key(name)}"
    end

    def team_key(club_key, number)
      "#{club_key}##{number}"
    end

    # Bringt LigaManager-game_type-Namen und Carambus-Disziplin-Namen auf denselben Branch-Nenner.
    def branch_name(name)
      norm(name.to_s).then { |n| n.start_with?("karambol", "kegel", "pool", "snooker") ? n.split(" ").first : n }
    end
  end
end
