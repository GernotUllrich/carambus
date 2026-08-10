# frozen_string_literal: true

# Wandelt extrahierten PDF-Text eines UMB-Hauptrunden-Resultats (MTResults) in
# strukturierte K.-o.-Match-Daten um: Quarter Final, Semi Final, Final.
#
# Reines PORO — kein DB-Zugriff, keine ActiveRecord-Abhängigkeit (analog zu
# Umb::PdfParser::GroupResultParser). Verwendet denselben Pair-Accumulator-Ansatz:
# zwei aufeinanderfolgende Spielerzeilen ergeben ein Match.
#
# WICHTIG — anderes Spaltenlayout als GroupResults:
#   GroupResults: "CAPS Mixed  Pts Inn Avg MP HS1 HS2"  (keine Nation, kein Penality)
#   MTResults:    "CAPS Mixed  Nat T-Car T-Inn Penality Avg MP HR"
# Deshalb ein eigener Parser mit eigener Zeilen-Regex.
#
# Output-Kontrakt (kompatibel zu GroupResultParser, plus :round):
#   {
#     round: "Quarter Final" | "Semi Final" | "Final",
#     player_a: { name:, nationality:, points:, innings:, average:, match_points:, hs: },
#     player_b: { ... },
#     winner_name: "CAPS Mixed"
#   }
class Umb::PdfParser::MainTournamentParser
  # Abschnittsüberschrift im PDF, z.B. "Main Tournament - Quarter_Final",
  # "Main Tournament - Semi_Final", "Main Tournament - Final".
  ROUND_HEADER_PATTERN = /Main\s+Tournament\s*-\s*([A-Za-z0-9_-]+)/i

  # Kopf-/Labelzeile der Ergebnistabelle ("Match Players  Nat  T-Car ...")
  HEADER_LINE_PATTERN = /Players\s+Nat|Match\s+Players/i

  # Spielerzeile im MTResults-Format:
  #   CAPS-Mixed-Name   Nat   T-Car   T-Inn   Penality   Avg   MP   HR
  #   "HEO Jung Han      KR    50      25      0          2.000 2    9"
  # Non-greedy Name-Capture (T-26-05 DoS-Sicherheit), Nat = ISO-2.
  PLAYER_LINE_PATTERN = /
    \A\s*
    (.+?)                 # (1) Name (CAPS + Mixed)
    \s+([A-Z]{2})         # (2) Nationalität (ISO-2)
    \s+(\d+)              # (3) T-Car   = erzielte Punkte (Karambolagen)
    \s+(\d+)              # (4) T-Inn   = Aufnahmen
    \s+(\d+)              # (5) Penality (verworfen)
    \s+([\d.]+)           # (6) Avg     = Generaldurchschnitt
    \s+(\d+)              # (7) MP      = Matchpunkte (2 = Sieger, 0 = Verlierer)
    \s+(\d+)              # (8) HR      = Höchstserie
    \s*\z
  /x

  def initialize(pdf_text)
    @pdf_text = pdf_text
  end

  # @return [Array<Hash>] Match-Hashes; [] bei nil/leerem Input
  def parse
    return [] if @pdf_text.nil? || @pdf_text.strip.empty?

    results = []
    current_round = nil
    pending_player = nil # Pair-Accumulator: erster Spieler des Match-Paares

    @pdf_text.each_line do |line|
      if (round_match = line.match(ROUND_HEADER_PATTERN))
        current_round = humanize_round(round_match[1])
        pending_player = nil # kein Bleed-over über Rundengrenzen
        next
      end

      next if line.match?(HEADER_LINE_PATTERN)

      player_match = line.match(PLAYER_LINE_PATTERN)
      next unless player_match

      # Ohne erkannte Runde kein sinnvolles Match — überspringen
      next if current_round.nil?

      player_data = build_player_data(player_match)

      if pending_player
        results << build_match(current_round, pending_player, player_data)
        pending_player = nil
      else
        pending_player = player_data
      end
    end

    results
  end

  private

  # "Quarter_Final" -> "Quarter Final", "Semi_Final" -> "Semi Final", "Final" -> "Final"
  def humanize_round(token)
    token.to_s.gsub(/[_-]+/, " ").squeeze(" ").strip
  end

  def build_player_data(match)
    {
      name: match[1].strip,
      nationality: match[2],
      points: match[3].to_i,       # T-Car (erzielte Punkte)
      innings: match[4].to_i,      # T-Inn
      average: match[6].to_f,      # Avg (GD)
      match_points: match[7].to_i, # MP (2 = Sieger)
      hs: match[8].to_i            # HR (Höchstserie)
    }
  end

  def build_match(round, player_a, player_b)
    winner =
      if player_a[:match_points] == player_b[:match_points]
        (player_a[:points] >= player_b[:points]) ? player_a : player_b
      else
        (player_a[:match_points] > player_b[:match_points]) ? player_a : player_b
      end

    {
      round: round,
      player_a: player_a,
      player_b: player_b,
      winner_name: winner[:name]
    }
  end
end
