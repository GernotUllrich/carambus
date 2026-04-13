# frozen_string_literal: true

# Wandelt extrahierten PDF-Text eines UMB-Rankings in strukturierte Daten um.
#
# Unterstützt zwei Formate (per D-07, RANK-01):
#   :final   — Turnier-Abschlussranking (position, name, nat, points, average)
#   :weekly  — Wöchentliches UMB-Weltranking (rank, name, nat, points)
#             URL-Muster: files.umb-carom.org/Public/Ranking/1_WP_Ranking/YEAR/WWEEK_YEAR.pdf
#
# Reines PORO — kein DB-Zugriff, keine ActiveRecord-Abhängigkeit (per D-03).
# Das frühere Modell für internationale Ergebnisse existiert nicht mehr —
# Daten werden als plain Hashes zurückgegeben (per D-08).
#
# Output-Kontrakt (D-08):
#   :final  → { position:, player_name:, nationality:, points:, average: }
#   :weekly → { rank:, player_name:, nationality:, points: }
class Umb::PdfParser::RankingParser
  VALID_TYPES = %i[final weekly].freeze

  # Final ranking: "1.  JASPERS Dick   NL   150   60   2.500"
  # Position kann mit oder ohne Punkt sein: "1." oder "1"
  # Nutzt non-greedy Quantifiers für Sicherheit (T-26-05)
  FINAL_LINE_PATTERN = /
    ^\s*(\d+)\.?\s+          # (1) Position (mit optionalem Punkt)
    ([A-Z][A-Z\s]+?[A-Z])   # (2) CAPS-Nachname
    \s+
    ([A-Z][a-z]+\S*(?:\s+[A-Z][a-z]+\S*)*)  # (3) Mixed-Vorname
    \s+
    ([A-Z]{2,3})             # (4) Nationalitätscode
    \s+(\d+)                 # (5) Punkte
    \s+\d+                   # Aufnahmen (nicht ausgegeben)
    \s+([\d.]+)              # (6) Durchschnitt
  /x

  # Weekly ranking: "1  JASPERS Dick   NL   1200"
  # Rank kann mit oder ohne Punkt sein: "1." oder "1"
  WEEKLY_LINE_PATTERN = /
    ^\s*(\d+)\.?\s+          # (1) Rang
    ([A-Z][A-Z\s]+?[A-Z])   # (2) CAPS-Nachname
    \s+
    ([A-Z][a-z]+\S*(?:\s+[A-Z][a-z]+\S*)*)  # (3) Mixed-Vorname
    \s+
    ([A-Z]{2,3})             # (4) Nationalitätscode
    \s+(\d+)                 # (5) Punkte
  /x

  def initialize(pdf_text, type: :final)
    @pdf_text = pdf_text
    @type = type
  end

  # Gibt ein Array von Ranking-Hashes zurück.
  # Gibt [] zurück bei nil/leerem Input.
  #
  # @return [Array<Hash>]
  def parse
    return [] if @pdf_text.nil? || @pdf_text.strip.empty?

    case @type
    when :final
      parse_final
    when :weekly
      parse_weekly
    else
      []
    end
  end

  private

  def parse_final
    results = []

    @pdf_text.each_line do |line|
      match = line.match(FINAL_LINE_PATTERN)
      next unless match

      player_name = build_player_name(match[2], match[3])

      results << {
        position: match[1].to_i,
        player_name: player_name,
        nationality: match[4].strip,
        points: match[5].to_i,
        average: match[6].to_f
      }
    end

    results
  end

  def parse_weekly
    results = []

    @pdf_text.each_line do |line|
      match = line.match(WEEKLY_LINE_PATTERN)
      next unless match

      player_name = build_player_name(match[2], match[3])

      results << {
        rank: match[1].to_i,
        player_name: player_name,
        nationality: match[4].strip,
        points: match[5].to_i
      }
    end

    results
  end

  def build_player_name(caps_part, mixed_part)
    "#{caps_part.strip} #{mixed_part.strip}"
  end
end
