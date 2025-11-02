# frozen_string_literal: true

# Service zum Extrahieren der Setzliste aus PDF oder Screenshot
class SeedingListExtractor
  def self.extract_from_file(file_path)
    file_type = File.extname(file_path).downcase
    
    case file_type
    when '.pdf'
      extract_from_pdf(file_path)
    when '.png', '.jpg', '.jpeg'
      extract_from_image(file_path)
    else
      { error: "Nicht unterstütztes Dateiformat: #{file_type}" }
    end
  end
  
  private
  
  def self.extract_from_pdf(file_path)
    # Versuche Text aus PDF zu extrahieren
    begin
      require 'pdf-reader'
      
      reader = PDF::Reader.new(file_path)
      text = reader.pages.map(&:text).join("\n")
      
      parse_seeding_list(text)
    rescue LoadError
      # Fallback wenn pdf-reader nicht verfügbar
      { error: "PDF-Reader Gem nicht installiert", raw_text: nil }
    rescue => e
      { error: "PDF-Fehler: #{e.message}", raw_text: nil }
    end
  end
  
  def self.extract_from_image(file_path)
    # OCR mit Tesseract
    begin
      require 'rtesseract'
      
      image = RTesseract.new(file_path, lang: 'deu')
      text = image.to_s
      
      parse_seeding_list(text)
    rescue LoadError
      # Fallback wenn rtesseract nicht verfügbar
      { error: "RTesseract Gem nicht installiert", raw_text: nil }
    rescue => e
      { error: "OCR-Fehler: #{e.message}", raw_text: nil }
    end
  end
  
  def self.parse_seeding_list(text)
    players = []
    
    # Suche nach Setzliste-Sektion
    # Pattern: "Setzliste" gefolgt von nummerierten Spielern
    
    # Extrahiere Zeilen nach "Setzliste" oder "SETZLISTE"
    lines = text.split("\n")
    
    in_seeding_section = false
    lines.each do |line|
      # Start der Setzliste
      if line =~ /Setzliste|SETZLISTE/i
        in_seeding_section = true
        next
      end
      
      # Ende der Setzliste (bei nächster Überschrift)
      if in_seeding_section && line =~ /Gruppenbildung|Turniermodus|^[A-Z][a-z]+:/
        break
      end
      
      # Parse Spieler-Zeilen
      if in_seeding_section
        # WICHTIG: Zweispaltige Tabellen!
        # Format: "1. Lastname Firstname 54 Pkt       7. Lastname Firstname 25 Pkt"
        # oder:   "1 Lastname Firstname              7 Lastname Firstname"
        
        # Pattern mit Vorgaben (Pkt): Nummer + Name + Punkte + (optional) zweite Spalte
        two_column_with_points = /(\d+)[\.\s]+([A-ZÄÖÜ][\wäöüß\-]+)\s+([A-ZÄÖÜ][\wäöüß\-\.]+)\s+(\d+)\s*Pkt(?:\s{2,}|\t+)(\d+)[\.\s]+([A-ZÄÖÜ][\wäöüß\-]+)\s+([A-ZÄÖÜ][\wäöüß\-\.]+)\s+(\d+)\s*Pkt/i
        
        # Pattern ohne Vorgaben: Nummer + Name + zweite Spalte
        two_column_pattern = /(\d+)[\.\s]+([A-ZÄÖÜ][\wäöüß\-]+)\s+([A-ZÄÖÜ][\wäöüß\-\.]+)(?:\s{2,}|\t+)(\d+)[\.\s]+([A-ZÄÖÜ][\wäöüß\-]+)\s+([A-ZÄÖÜ][\wäöüß\-\.]+)/
        
        # Pattern einspaltig mit Vorgabe
        single_with_points = /^\s*(\d+)[\.\s]+([A-ZÄÖÜ][\wäöüß\-]+)\s+([A-ZÄÖÜ][\wäöüß\-\.]+)\s+(\d+)\s*Pkt/i
        
        if (match = line.match(two_column_with_points))
          # Zweispaltig MIT Vorgaben
          # Linke Spalte
          players << {
            position: match[1].to_i,
            lastname: match[2].strip,
            firstname: match[3].strip,
            full_name: "#{match[2].strip}, #{match[3].strip}",
            balls_goal: match[4].to_i
          }
          
          # Rechte Spalte
          players << {
            position: match[5].to_i,
            lastname: match[6].strip,
            firstname: match[7].strip,
            full_name: "#{match[6].strip}, #{match[7].strip}",
            balls_goal: match[8].to_i
          }
        elsif (match = line.match(two_column_pattern))
          # Zweispaltig OHNE Vorgaben
          # Linke Spalte
          players << {
            position: match[1].to_i,
            lastname: match[2].strip,
            firstname: match[3].strip,
            full_name: "#{match[2].strip}, #{match[3].strip}"
          }
          
          # Rechte Spalte
          players << {
            position: match[4].to_i,
            lastname: match[5].strip,
            firstname: match[6].strip,
            full_name: "#{match[5].strip}, #{match[6].strip}"
          }
        elsif (match = line.match(single_with_points))
          # Einspaltig MIT Vorgabe
          players << {
            position: match[1].to_i,
            lastname: match[2].strip,
            firstname: match[3].strip,
            full_name: "#{match[2].strip}, #{match[3].strip}",
            balls_goal: match[4].to_i
          }
        # Einspaltig OHNE Vorgabe (Fallback)
        elsif (match = line.match(/^\s*(\d+)[\.\s]+([A-ZÄÖÜ][\wäöüß\-]+)\s+([A-ZÄÖÜ][\wäöüß\-\.]+)/))
          position = match[1].to_i
          lastname = match[2].strip
          firstname = match[3].strip
          
          players << {
            position: position,
            lastname: lastname,
            firstname: firstname,
            full_name: "#{lastname}, #{firstname}"
          }
        end
      end
    end
    
    # Sortiere nach Position (wichtig wenn zweispaltig durcheinander kam)
    players.sort_by! { |p| p[:position] }
    
    {
      success: players.any?,
      players: players,
      count: players.count,
      raw_text: text
    }
  end
  
  # Matched Spieler aus der Datenbank mit der extrahierten Liste
  def self.match_with_database(extracted_players, tournament)
    matched = []
    unmatched = []
    
    extracted_players.each do |ep|
      # Suche in der Meldeliste des Tournaments
      player = tournament.seedings
                         .joins(:player)
                         .where("players.lastname ILIKE ? AND players.firstname ILIKE ?", 
                                ep[:lastname], ep[:firstname])
                         .first&.player
      
      if player
        matched << {
          position: ep[:position],
          player: player,
          extracted_name: ep[:full_name],
          balls_goal: ep[:balls_goal],  # Vorgabe mitgeben
          confidence: :high
        }
      else
        # Fuzzy-Match in allen Spielern
        player = fuzzy_match_player(ep[:lastname], ep[:firstname])
        
        if player
          matched << {
            position: ep[:position],
            player: player,
            extracted_name: ep[:full_name],
            balls_goal: ep[:balls_goal],  # Vorgabe mitgeben
            confidence: :medium,
            suggestion: true
          }
        else
          unmatched << ep
        end
      end
    end
    
    {
      matched: matched,
      unmatched: unmatched,
      match_rate: (matched.count.to_f / extracted_players.count * 100).round
    }
  end
  
  def self.fuzzy_match_player(lastname, firstname)
    # Suche mit Levenshtein-Distanz oder ähnlich
    # Für jetzt: einfache ILIKE-Suche
    Player.where("lastname ILIKE ? OR firstname ILIKE ?", 
                 "%#{lastname}%", "%#{firstname}%").first
  end
end

