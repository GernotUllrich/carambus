# frozen_string_literal: true

module LigaManager
  # Ergebnis-Abgleich CC↔LigaManager (Pilot TBV): paart gematchte Ligen und vergleicht je Liga
  # die Begegnungen (über Datum + Team-Paar) samt Mannschaftsergebnis
  # (LigaManager matchpoints total_home:total_guest ↔ Carambus Party.data["result"]).
  # Read-only auf beiden Seiten — KEINE Persistenz (Import ist Phase 9).
  #
  # Nutzt die reinen Helfer aus TbvComparison (normalize_name/normalize_key).
  class ResultComparison
    # LigaManager hängt die Disziplin an den Teamnamen ("Sparta Ilmenau Dreiband 1"),
    # Carambus nicht ("Sparta Ilmenau 1") — für den Begegnungs-Key rausnormalisieren.
    DISCIPLINE_TOKENS = %w[dreiband einband mehrkampf cadre freie partie karambol kegel pool snooker].freeze

    def initialize(association_id:, region_id:, season_id:, scraper: nil)
      @association_id = association_id
      @region_id = region_id
      @season_id = season_id
      @scraper = scraper || Scraper.new(association_id: association_id)
    end

    def run
      per_league = matched_league_pairs.map do |lm_l, cb_l|
        cmp = self.class.compare_encounters(lm_encounters(lm_l), cb_encounters(cb_l))
        {
          league: "#{lm_l["name"]} ↔ #{cb_l.name}",
          matched: cmp[:matched],
          result_ok: cmp[:matched] - cmp[:result_mismatches].size,
          result_mismatches: cmp[:result_mismatches],
          only_lm: cmp[:only_lm],
          only_carambus: cmp[:only_carambus]
        }
      end
      {per_league: per_league, totals: totals(per_league)}
    end

    # Team-Name normalisieren UND Disziplin-Tokens entfernen (LigaManager hängt die Disziplin
    # an den Teamnamen an, Carambus nicht) — reiner Helfer, DB-/HTTP-frei.
    def self.normalize_team_name(name)
      TbvComparison.normalize_name(name).split(" ").reject { |t| DISCIPLINE_TOKENS.include?(t) }.join(" ")
    end

    # Reiner Helfer (DB-/HTTP-frei): vergleicht zwei Begegnungs-Maps { key => "H:G" }.
    # result_mismatch = gleiche Begegnung (Key), aber abweichendes Ergebnis.
    def self.compare_encounters(lm_map, cb_map)
      common = lm_map.keys & cb_map.keys
      result_mismatches = common.select { |k| lm_map[k] != cb_map[k] }
        .map { |k| {key: k, lm: lm_map[k], cb: cb_map[k]} }
      {
        matched: common.size,
        result_mismatches: result_mismatches,
        only_lm: (lm_map.keys - cb_map.keys),
        only_carambus: (cb_map.keys - lm_map.keys)
      }
    end

    private

    def totals(per_league)
      {
        matched_leagues: per_league.size,
        encounters_matched: per_league.sum { |l| l[:matched] },
        result_ok: per_league.sum { |l| l[:result_ok] },
        result_mismatch: per_league.sum { |l| l[:result_mismatches].size }
      }
    end

    # Liga-Paare (LM↔CB) über denselben Liga-Schlüssel wie TbvComparison (Branch + Name).
    def matched_league_pairs
      cb_by_key = carambus_leagues.index_by { |l| league_key(l.discipline&.name, l.name) }
      lm_leagues.filter_map do |lm_l|
        cb = cb_by_key[league_key(lm_l["game_type_name"], lm_l["name"])]
        [lm_l, cb] if cb
      end
    end

    def lm_encounters(lm_l)
      @scraper.match_plans(lm_l["id"]).to_h do |m|
        [encounter_key(m["scheduled_date"], m["home_team_name"], m["away_team_name"]),
          "#{m.dig("matchpoints", "total_home_points")}:#{m.dig("matchpoints", "total_guest_points")}"]
      end
    end

    def cb_encounters(cb_l)
      cb_l.parties.includes(:league_team_a, :league_team_b).to_h do |p|
        [encounter_key(p.date&.to_date, p.league_team_a&.name, p.league_team_b&.name),
          p.data&.dig("result").to_s]
      end
    end

    def encounter_key(date, home, away)
      "#{date}|#{self.class.normalize_team_name(home)}|#{self.class.normalize_team_name(away)}"
    end

    def lm_leagues
      @lm_leagues ||= @scraper.seasons.flat_map { |s| @scraper.leagues(s["id"]) }
    end

    def carambus_leagues
      @carambus_leagues ||= League.where(region_id: @region_id, season_id: @season_id).includes(:discipline).to_a
    end

    def norm(str) = TbvComparison.normalize_name(str)

    def league_key(discipline_or_game_type, name)
      branch = norm(discipline_or_game_type)
        .then { |n| n.start_with?("karambol", "kegel", "pool", "snooker") ? n.split(" ").first : n }
      "#{branch}|#{TbvComparison.normalize_key(name)}"
    end
  end
end
