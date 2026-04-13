# frozen_string_literal: true

# Wandelt extrahierten PDF-Text einer UMB-Spielerliste in strukturierte Daten um.
#
# Reines PORO — kein DB-Zugriff, keine ActiveRecord-Abhängigkeit (per D-03).
# Gibt ein Array von Hashes zurück; der Aufrufer entscheidet, was persistiert wird.
#
# Output-Kontrakt (D-08):
#   { caps_name: "JASPERS", mixed_name: "Dick", nationality: "NL", position: 1 }
class Umb::PdfParser::PlayerListParser
  # Pattern: Position  LASTNAME Firstname  COUNTRY  RankPos  RankPts  PlayerID
  # Beispiel: "1   JASPERS Dick   NL   1   480   0106   Confirmed"
  PLAYER_LINE_PATTERN = /
    ^\s*(\d+)             # (1) Setzposition
    \s+
    ([A-Z][A-Z\s]+?[A-Z]) # (2) CAPS-Nachname (≥2 Buchstaben)
    \s+
    ([A-Z][a-z]+.*?)      # (3) Mixed-Vorname
    \s+
    ([A-Z]{2,3})          # (4) Nationalitätscode
    \s+\d+\s+\d+\s+(\d+) # RankPos, RankPts, PlayerID (erfasst, aber nicht ausgegeben)
  /x

  def initialize(pdf_text)
    @pdf_text = pdf_text
  end

  # Gibt ein Array von Spieler-Hashes zurück.
  # Gibt [] zurück bei nil/leerem Input oder fehlenden Spielerzeilen.
  #
  # @return [Array<Hash>] mit Schlüsseln: :caps_name, :mixed_name, :nationality, :position
  def parse
    return [] if @pdf_text.nil? || @pdf_text.strip.empty?

    results = []

    @pdf_text.each_line do |line|
      match = line.match(PLAYER_LINE_PATTERN)
      next unless match

      caps_name = match[2].strip
      mixed_name = clean_mixed_name(match[3].strip)

      results << {
        position: match[1].to_i,
        caps_name: caps_name,
        mixed_name: mixed_name,
        nationality: match[4].strip
      }
    end

    results
  end

  private

  # Entfernt ggf. anhängende Länderkürzel aus dem Vornamen-Feld
  def clean_mixed_name(name)
    name.gsub(/\s+[A-Z]{2,3}$/, "").strip
  end
end
