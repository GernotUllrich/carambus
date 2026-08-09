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
    (.*)$                                  # (5) Rest der Zeile — traegt den Runden-Marker
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
    (.*)$                                  # (5) Rest der Zeile
  /x

  def initialize(pdf_text)
    @pdf_text = pdf_text
  end

  # Gibt ein Array von Spieler-Hashes zurück.
  # Gibt [] zurück bei nil/leerem Input oder fehlenden Spielerzeilen.
  #
  # @return [Array<Hash>] mit Schlüsseln: :caps_name, :mixed_name, :nationality,
  #   :position, :stage ("main" | "qualification")
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
        nationality: match[4].strip,
        qualifier_marker: match[5].to_s.strip
      }
    end

    assign_stages(results)
  end

  private

  # Trennt das gesetzte Hauptfeld vom Qualifikationsfeld.
  #
  # Die Spielerlisten der World Cups enthalten BEIDES: ein grosses Qualifikations-
  # feld (bei ID 280 waren es 276 von 293 Eintraegen) und die gesetzten
  # Hauptrunden-Teilnehmer.
  #
  # Unterscheidungsmerkmal in allen beobachteten Listen: gesetzte Spieler tragen
  # hinter dem Laendercode einen TEXT-Marker ("Main Tournament", "Wildcard CEB",
  # "Title Holder", "CEB-1"), Qualifikanten dagegen nur Zahlen (Ranglistenplatz/
  # Punkte) oder Striche.
  #
  # WICHTIG — was "main" bedeutet: die Spielerliste entsteht VOR dem Turnier.
  # "main" heisst also "war fuer die Hauptrunde gesetzt", NICHT "hat in der
  # Hauptrunde gespielt". Wer sich aus der Qualifikation durchsetzt, bleibt hier
  # als "qualification" stehen — empirisch bestaetigt an World Cup 2024
  # (Videos "[VEWC2024_L8] F. CAUDRON vs T. TASDEMIR" betreffen Spieler, die in
  # der Liste NICHT gesetzt waren). Wer die tatsaechliche Hauptrunden-Besetzung
  # braucht, muss die MTResults-PDFs auswerten (MT = Main Tournament).
  #
  # Listen ohne jeden Marker (z.B. Junioren-WM: festes Teilnehmerfeld ohne
  # Qualifikation) gelten vollstaendig als gesetzt — sonst fiele dort
  # faelschlich alles heraus.
  def assign_stages(results)
    any_marker = results.any? { |r| main_round_marker?(r[:qualifier_marker]) }

    results.map do |r|
      marker = r.delete(:qualifier_marker)
      stage = if !any_marker
        "main"
      else
        main_round_marker?(marker) ? "main" : "qualification"
      end
      r.merge(stage: stage)
    end
  end

  # Text-Marker = Hauptrunde; reine Zahlen/Striche = Qualifikationsfeld.
  def main_round_marker?(marker)
    marker.to_s.match?(/[[:alpha:]]{3,}/)
  end

  # Entfernt ggf. anhängende Länderkürzel aus dem Vornamen-Feld
  def clean_mixed_name(name)
    name.gsub(/\s+[A-Z]{2,3}$/, "").strip
  end
end
