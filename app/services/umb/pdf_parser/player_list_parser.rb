# frozen_string_literal: true

# Wandelt extrahierten PDF-Text einer UMB-Spielerliste in strukturierte Daten um.
#
# Reines PORO — kein DB-Zugriff, keine ActiveRecord-Abhängigkeit (per D-03).
# Gibt ein Array von Hashes zurück; der Aufrufer entscheidet, was persistiert wird.
#
# Output-Kontrakt (D-08):
#   { caps_name: "JASPERS", mixed_name: "Dick", nationality: "NL", position: 1 }
class Umb::PdfParser::PlayerListParser
  # Pattern: Position  LASTNAME Firstname  COUNTRY  <beliebiger Rest>
  #
  # Nur die ersten vier Spalten sind stabil; was dahinter steht, hat die UMB
  # mehrfach umgestellt. Real beobachtete Varianten:
  #
  #   "1  BLOMDAHL Torbjorn  SE  1  402  Main Tournament  Confirmed"  (aelter)
  #   "1  DERICKS Rene       NL  CEB  Title Holder  UMB-1"            (seit 2026)
  #
  # Das fruehere Pattern verlangte hinter dem Laendercode drei Zahlen
  # (RankPos/RankPts/PlayerID) und traf damit KEINE der beiden Varianten — der
  # Parser lieferte an echten PDFs durchgaengig 0 Spieler. Der Rest der Zeile
  # wird deshalb bewusst nicht mehr geprueft.
  #
  # Nachnamen duerfen mehrteilig sein ("VAN DEN ZEGEL", "DE JONG") und
  # Apostroph/Bindestrich enthalten; Vornamen ebenfalls ("Haci Arap").
  #
  # Unicode-Zeichenklassen statt [A-Z]/[a-z]: die Listen enthalten Akzente und
  # Umlaute ("Frédéric", "Lütfi"), die an einer ASCII-Klasse scheitern wuerden.
  PLAYER_LINE_PATTERN = /
    ^\s*(\d{1,3})                          # (1) Setzposition
    \s+
    ([[:upper:]][[:upper:]\s'\-]*[[:upper:]]) # (2) CAPS-Nachname (≥2 Zeichen, ggf. mehrteilig)
    \s+
    ([[:upper:]][[:alpha:]\s'\-]*?)        # (3) Mixed-Vorname (non-greedy, ggf. mehrteilig)
    \s+
    ([A-Z]{2,3})                           # (4) Nationalitätscode (immer ASCII)
    (?=\s|$)                               # danach Spaltentrenner oder Zeilenende
  /x

  # Junioren-/Nachwuchslisten nutzen ein eigenes Layout mit AUSGESCHRIEBENEM Land
  # und Geburtsdatum: "No. | NAME | COUNTRY | BIRTHDAY | UMB ID | Notes"
  #
  #   "1  SANCHEZ Ubaldo  Mexico  15/12/2007  8041  World Champion"
  #
  # Ohne Laendercode laesst sich Vorname und Land nicht zuverlaessig trennen —
  # deshalb dient hier das Geburtsdatum als Anker: was direkt davor steht, ist
  # das Land, alles zwischen CAPS-Nachname und Land der Vorname.
  PLAYER_LINE_PATTERN_NAMED_COUNTRY = /
    ^\s*(\d{1,3})                          # (1) Setzposition
    \s+
    ([[:upper:]][[:upper:]\s'\-]*[[:upper:]]) # (2) CAPS-Nachname
    \s+
    ([[:upper:]][[:alpha:]\s'\-]*?)        # (3) Mixed-Vorname (non-greedy)
    \s+
    ([[:upper:]][[:alpha:]]+)              # (4) ausgeschriebenes Land
    \s+
    \d{1,2}\/\d{1,2}\/\d{2,4}              # Geburtsdatum als Anker
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
      # Laendercode-Layout zuerst; das Junioren-Layout mit ausgeschriebenem Land
      # ist der Sonderfall und wird nur geprueft, wenn das erste nicht greift.
      match = line.match(PLAYER_LINE_PATTERN) || line.match(PLAYER_LINE_PATTERN_NAMED_COUNTRY)
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
