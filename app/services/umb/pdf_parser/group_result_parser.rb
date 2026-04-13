# frozen_string_literal: true

# Wandelt extrahierten PDF-Text eines UMB-Gruppenresultats in strukturierte Match-Daten um.
#
# Reines PORO — kein DB-Zugriff, keine ActiveRecord-Abhängigkeit (per D-03).
# Verwendet V2's Pair-Accumulator-Ansatz (per D-06): erste Spielerzeile wird
# zwischengespeichert, zweite Spielerzeile komplettiert das Match-Paar.
#
# Output-Kontrakt (D-08):
#   {
#     group: "A",
#     player_a: { name:, nationality:, points:, innings:, average:, hs:, match_points: },
#     player_b: { ... },
#     winner_name: "Vorname Nachname"
#   }
class Umb::PdfParser::GroupResultParser
  # Erkennt Gruppenüberschriften: "Group A", "Group B", etc.
  GROUP_HEADER_PATTERN = /^Group\s+([A-Z])/i

  # Überspringt Kopfzeilen mit diesen Schlüsselwörtern
  HEADER_LINE_PATTERN = /^\s*(Players|Nat|Group)/i

  # Spielerzeile: CAPS-NAME MixedName   Pts   Inn   Avg   MP   HS1   HS2
  # Beispiel: "JASPERS Dick   30   14   2.142   2   9   4"
  # Hinweis: Nutzt non-greedy Regex für Sicherheit gegen DoS (T-26-05)
  PLAYER_LINE_PATTERN = /
    ^\s*
    ([A-Z][A-Z\s]+?)          # (1) CAPS-Teile des Namens
    \s+
    ([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)  # (2) Mixed-Teile des Namens
    \s+(\d+)                  # (3) Punkte
    \s+(\d+)                  # (4) Aufnahmen
    \s+([\d.]+)               # (5) Durchschnitt
    \s+(\d+)                  # (6) Match-Punkte
    \s+(\d+)                  # (7) HS1
    \s+(\d+)                  # (8) HS2
  /x

  def initialize(pdf_text)
    @pdf_text = pdf_text
  end

  # Gibt ein Array von Match-Hashes zurück.
  # Gibt [] zurück bei nil/leerem Input.
  #
  # @return [Array<Hash>]
  def parse
    return [] if @pdf_text.nil? || @pdf_text.strip.empty?

    results = []
    current_group = nil
    pending_player = nil  # Pair-Accumulator: erster Spieler des Match-Paares

    @pdf_text.each_line do |line|
      # Gruppenüberschrift erkannt → pending_player zurücksetzen (kein Bleed-over)
      if (group_match = line.match(GROUP_HEADER_PATTERN))
        current_group = group_match[1].upcase
        pending_player = nil
        next
      end

      # Kopf-/Labelzeilen überspringen
      next if line.match?(HEADER_LINE_PATTERN)

      player_match = line.match(PLAYER_LINE_PATTERN)
      next unless player_match

      caps_part = player_match[1].strip
      # Einzelne Buchstaben sind Gruppenmarkierungen, kein Spielername
      next if caps_part.length == 1

      mixed_part = clean_mixed_name(player_match[2].strip)
      full_name = "#{caps_part} #{mixed_part}"

      player_data = build_player_data(full_name, player_match)

      if pending_player
        # Beide Spieler bekannt → Match-Hash erstellen
        results << build_match(current_group, pending_player, player_data)
        pending_player = nil
      else
        # Ersten Spieler zwischenspeichern
        pending_player = player_data
      end
    end

    results
  end

  private

  def clean_mixed_name(name)
    name.gsub(/\s+(KR|VN|TR|JP|FR|DE|BE|NL|EG|SE|GR|JO)$/i, "").strip
  end

  def build_player_data(full_name, match)
    {
      name: full_name,
      nationality: nil,  # Nicht direkt in V2's Gruppenresultat-PDF enthalten
      points: match[3].to_i,
      innings: match[4].to_i,
      average: match[5].to_f,
      match_points: match[6].to_i,
      hs: match[7].to_i  # Höchstserie (erster Wert)
    }
  end

  def build_match(group, player_a, player_b)
    winner = player_a[:match_points] >= player_b[:match_points] ? player_a : player_b

    {
      group: group,
      player_a: player_a,
      player_b: player_b,
      winner_name: winner[:name]
    }
  end
end
