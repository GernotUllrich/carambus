module PartiesHelper
  # Ergebnis-Schlüssel der Quellen: ClubCloud "Ergebnis:", BillardArea "Ergebnis" (ohne Doppelpunkt).
  ERGEBNIS_KEYS = ["Ergebnis:", "Ergebnis"].freeze

  def spielbericht_rows(party)
    plan = party.league.game_plan
    return spielbericht_rows_ohne_plan(party) unless plan && plan.data && plan.data["rows"]

    # PartyGames nach seqno indizieren
    games_by_seqno = party.party_games.index_by(&:seqno)

    plan.data["rows"].map do |row|
      if row["type"] == "Neue Runde" || row["type"] == "Gesamtsumme"
        { type: row["type"], r_no: row["r_no"] }
      else
        game = games_by_seqno[row["seqno"]]
        { type: row["type"], r_no: row["r_no"], row: row, game: game }
      end
    end
  end

  # Ohne GamePlan (alle BillardArea- und NuLiga-Ligen, wenige ClubCloud-Ligen) die Einzelspiele selbst,
  # nach seqno; Disziplin aus dem Spiel. Endstand nur, wenn die Quelle Spielpunkte mitliefert.
  def spielbericht_rows_ohne_plan(party)
    games = party.party_games.sort_by { |g| g.seqno.to_i }
    rows = games.map { |g| {type: g.discipline&.name, r_no: nil, row: nil, game: g} }
    rows << {type: "Gesamtsumme"} if games.any? { |g| spielbericht_spielpunkte(g) }
    rows
  end

  # Anzeige-Ergebnis für alle drei Formate: NuLiga String "6:5"; Hash mit Ergebnis-Schlüssel; sonst die
  # Werte (BillardArea 14.1: "Bälle:"/"Aufn.:"/"HS:").
  def spielbericht_ergebnis(game)
    result = game&.data&.dig("result")
    return result if result.is_a?(String)
    return nil unless result.is_a?(Hash) && result.any?

    result.values_at(*ERGEBNIS_KEYS).compact.first || result.values.join(" / ")
  end

  # Zusatzangaben neben dem Ergebnis (nur Hash-Formate).
  def spielbericht_details(game)
    result = game&.data&.dig("result")
    result.is_a?(Hash) ? result.except(*ERGEBNIS_KEYS) : {}
  end

  # Spielpunkte [heim, gast], wenn die Quelle sie liefert: NuLiga "match_points", ClubCloud "Punkte:".
  def spielbericht_spielpunkte(game)
    data = game&.data
    return nil unless data.is_a?(Hash)

    raw = data["match_points"] || (data["result"].is_a?(Hash) && data["result"]["Punkte:"])
    return nil unless raw.is_a?(String) && raw =~ /\A\s*(\d+)\s*:\s*(\d+)\s*\z/

    [$1.to_i, $2.to_i]
  end

  def spielbericht_punkte(game, row)
    return nil unless game && row
    if row["game_points"]
      if game.data && game.data["result"] && game.data["result"]["Ergebnis:"]
        ergebnis = game.data["result"]["Ergebnis:"]
        left, right = ergebnis.split(":").map(&:to_i)
        if left > right
          [row["game_points"]["win"], row["game_points"]["lost"]]
        elsif left < right
          [row["game_points"]["lost"], row["game_points"]["win"]]
        else
          [row["game_points"]["draw"], row["game_points"]["draw"]]
        end
      end
    end
  end

  def spielbericht_endstand(party)
    heim = 0
    gast = 0
    spielbericht_rows(party).each do |row|
      next unless row[:game] && row[:row] && row[:row]["game_points"]
      pkt = spielbericht_punkte(row[:game], row[:row])
      heim += pkt[0] if pkt
      gast += pkt[1] if pkt
    end
    [heim, gast]
  end

  def spielbericht_punkte_einfach(game, row, heim: true)
    return nil unless game && row && row["game_points"]
    if game.data && game.data["result"] && game.data["result"]["Ergebnis:"]
      ergebnis = game.data["result"]["Ergebnis:"]
      left, right = ergebnis.split(":").map(&:to_i)
      if heim
        left > right ? 1 : 0
      else
        right > left ? 1 : 0
      end
    end
  end

  def spielbericht_shootout_row(party)
    # Finde die Zeile mit Shootout im GamePlan
    spielbericht_rows(party).find { |row| row[:type].to_s.downcase.include?("shootout") }
  end

  def spielbericht_endstand_einfach(party)
    unless party.league.game_plan&.data&.dig("rows")
      punkte = party.party_games.filter_map { |g| spielbericht_spielpunkte(g) }
      return [punkte.sum(&:first), punkte.sum(&:last)]
    end
    heim = 0
    gast = 0
    shootout_row = spielbericht_shootout_row(party)
    reguläre_spiele = spielbericht_rows(party).select { |row| row[:game] && row[:row] && row[:row]["game_points"] && !row[:type].to_s.downcase.include?("shootout") }
    reguläre_spiele.each do |row|
      pkt_heim = spielbericht_punkte_einfach(row[:game], row[:row], heim: true)
      pkt_gast = spielbericht_punkte_einfach(row[:game], row[:row], heim: false)
      heim += pkt_heim if pkt_heim
      gast += pkt_gast if pkt_gast
    end
    # Wenn nach regulären Spielen Gleichstand, Shootout werten
    if heim == gast && shootout_row && shootout_row[:game]
      pkt_heim = spielbericht_punkte_einfach(shootout_row[:game], shootout_row[:row], heim: true)
      pkt_gast = spielbericht_punkte_einfach(shootout_row[:game], shootout_row[:row], heim: false)
      heim += pkt_heim if pkt_heim
      gast += pkt_gast if pkt_gast
    end
    [heim, gast]
  end

  # Phase 38.7 Plan 07 D-12 — Tiebreak indicator for Spielbericht-PDF.
  # Returns a localized suffix " (Stechen <PlayerName>)" when the game has a
  # tiebreak winner recorded; empty string otherwise. Defensive against nil
  # game and invalid TiebreakWinner values.
  #
  # Reads game.data['ba_results']['TiebreakWinner']  (1 = playera, 2 = playerb).
  # The integer is written by TableMonitor::ResultRecorder#update_ba_results_with_set_result!
  # (Plan 05) when the operator picks a winner via the protocol_final modal (Plan 06).
  #
  # Threat-model notes:
  #  - T-38.7-07-01: Player#shortname is rendered through Rails's `t` helper,
  #    which auto-escapes HTML interpolations. Do NOT pass the result through
  #    `html_safe` — Player names are user-editable from the admin surface.
  #  - T-38.7-07-02: Only the integers 1 and 2 are honored; any other value
  #    (including forged strings) returns empty string (defense-in-depth).
  def tiebreak_indicator(game)
    return "" if game.nil?
    tw = game.data&.dig("ba_results", "TiebreakWinner")
    # Per plan threat model T-38.7-07-02: only Integer 1 or 2 (or their
    # numeric String equivalents) yield a role; everything else falls through
    # to nil and the helper returns "". Strings like "X" coerce to 0 via to_i
    # and miss the 1/2 case; forged 99 likewise misses.
    role = case tw.to_i
    when 1 then game.player_a&.shortname.presence || game.player_a&.fullname
    when 2 then game.player_b&.shortname.presence || game.player_b&.fullname
    end
    return "" if role.blank?
    " #{t("parties.spielbericht.tiebreak_won_by", role: role)}"
  end
end
