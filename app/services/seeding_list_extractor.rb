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
    
    # Extrahiere Turniermodus-Info (z.B. "T21 - 3 Gruppen à 3, 4 und 4 Spieler")
    plan_info = extract_tournament_plan_info(text)
    
    # Extrahiere Turnier-Parameter (Bälle Ziel, Aufnahme-Begrenzung)
    extracted_params = extract_tournament_parameters(text)
    
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
      if in_seeding_section && line =~ /Gruppenbildung|Turniermodus|Ausspielziel|^[A-Z][a-z]+:/
        break
      end
      
      # Parse Spieler-Zeilen
      if in_seeding_section
        # Skip Header-Zeilen
        next if line =~ /Name\s+Pkt/i
        next if line =~ /^[\s]*Name[\s]*Name/i  # Header mit zwei "Name" Spalten
        next if line.strip.empty?
        
        # Pattern für Spieler mit Vorgabe (Zahl nach dem Namen)
        # Format: "1   Ullrich Gernot             54     5   Scharf Claus-Dieter         21"
        # oder:   "4   Jahn Wilfried              25" (einspaltig)
        # Struktur: Nummer + Name + viele Leerzeichen + Zahl + (viele Leerzeichen + zweiter Spieler)
        
        # WICHTIG: Prüfe zuerst zweispaltige Formate, BEVOR einspaltige geprüft werden!
        # Sonst wird nur der erste Spieler erkannt und die rechte Spalte ignoriert.
        
        # Zweispaltig MIT Vorgaben: Nummer + Name + Zahl + große Leerzeichen + Nummer + Name + Zahl
        two_column_with_points = /^\s*(\d+)\s+([A-ZÄÖÜ][\wäöüß\-]+)\s+([A-ZÄÖÜ][\wäöüß\-\.]+)\s+(\d+)(?:\s*Pkt)?\s{3,}(\d+)\s+([A-ZÄÖÜ][\wäöüß\-]+)\s+([A-ZÄÖÜ][\wäöüß\-\.]+)\s+(\d+)(?:\s*Pkt)?/i
        
        # Zweispaltig OHNE Vorgaben: Nummer + Name + große Leerzeichen + Nummer + Name
        # Format: "1 Smrcka Martin          4   Stahl Mario"
        two_column_without_points = /^\s*(\d+)\s+([A-ZÄÖÜ][\wäöüß\-]+)\s+([A-ZÄÖÜ][\wäöüß\-\.]+)\s{3,}(\d+)\s+([A-ZÄÖÜ][\wäöüß\-]+)\s+([A-ZÄÖÜ][\wäöüß\-\.]+)/i
        
        # NEUE Variante: Zweispaltig mit weniger Whitespace (z.B. "2 Schröder Hans-Jörg 6 Kämmer Lothar")
        # Die Zahl nach dem ersten Namen könnte Position (klein) oder Vorgabe (groß) sein
        # Wir prüfen: Wenn Zahl <= 20 UND ein weiterer Name folgt → Position, sonst Vorgabe
        two_column_compact = /^\s*(\d+)\s+([A-ZÄÖÜ][\wäöüß\-]+)\s+([A-ZÄÖÜ][\wäöüß\-\.]+)\s+(\d+)\s+([A-ZÄÖÜ][\wäöüß\-]+)\s+([A-ZÄÖÜ][\wäöüß\-\.]+)/i
        
        # Einspaltig mit Vorgabe: Nummer + Nachname + Vorname + flexible Whitespace + Zahl
        single_with_points = /^\s*(\d+)\s+([A-ZÄÖÜ][\wäöüß\-]+)\s+([A-ZÄÖÜ][\wäöüß\-\.]+)\s+(\d+)(?:\s*Pkt)?/i
        
        # Einspaltig ohne Vorgabe (Fallback)
        single_without_points = /^\s*(\d+)\s+([A-ZÄÖÜ][\wäöüß\-]+)\s+([A-ZÄÖÜ][\wäöüß\-\.]+)/i
        
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
        elsif (match = line.match(two_column_without_points))
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
        elsif (match = line.match(two_column_compact))
          # Kompaktes zweispaltiges Format: "2 Schröder Hans-Jörg 6 Kämmer Lothar"
          # Die Zahl nach dem ersten Namen könnte Position (klein, ≤20) oder Vorgabe (groß) sein
          # Heuristik: Wenn ≤ 20 → wahrscheinlich Position, sonst Vorgabe
          number_after_first = match[4].to_i
          
          if number_after_first <= 20
            # Wahrscheinlich Position → Zweispaltig OHNE Vorgaben
            players << {
              position: match[1].to_i,
              lastname: match[2].strip,
              firstname: match[3].strip,
              full_name: "#{match[2].strip}, #{match[3].strip}"
            }
            
            players << {
              position: number_after_first,
              lastname: match[5].strip,
              firstname: match[6].strip,
              full_name: "#{match[5].strip}, #{match[6].strip}"
            }
          else
            # Wahrscheinlich Vorgabe → Einspaltig MIT Vorgabe
            players << {
              position: match[1].to_i,
              lastname: match[2].strip,
              firstname: match[3].strip,
              full_name: "#{match[2].strip}, #{match[3].strip}",
              balls_goal: number_after_first
            }
          end
        elsif (match = line.match(single_with_points))
          # Einspaltig MIT Vorgabe (kann in zweispaltiger Tabelle vorkommen, z.B. letzte Zeile)
          players << {
            position: match[1].to_i,
            lastname: match[2].strip,
            firstname: match[3].strip,
            full_name: "#{match[2].strip}, #{match[3].strip}",
            balls_goal: match[4].to_i
          }
        elsif (match = line.match(single_without_points))
          # Einspaltig OHNE Vorgabe (Fallback)
          players << {
            position: match[1].to_i,
            lastname: match[2].strip,
            firstname: match[3].strip,
            full_name: "#{match[2].strip}, #{match[3].strip}"
          }
        end
      end
    end
    
    # Sortiere nach Position (wichtig wenn zweispaltig durcheinander kam)
    players.sort_by! { |p| p[:position] }
    
    # Versuche auch Gruppenbildung zu extrahieren (übergebe players für Namen-Matching)
    group_assignment = extract_group_assignment(text, players.count, players)
    
    {
      success: players.any?,
      players: players,
      count: players.count,
      group_assignment: group_assignment,
      plan_info: plan_info,
      extracted_params: extracted_params,
      raw_text: text
    }
  end
  
  # Extrahiert Turnier-Parameter wie Bälle Ziel und Aufnahme-Begrenzung
  def self.extract_tournament_parameters(text)
    params = {}
    lines = text.split("\n")
    
    lines.each do |line|
      # Bälle Ziel: "100 Bälle" oder "100 Pkt" oder "Ballziel: 100"
      if (match = line.match(/(?:Ballziel|Bälle|Pkt)[:\s]+(\d+)/i))
        params[:balls_goal] = match[1].to_i
      end
      
      # Aufnahme-Begrenzung: "Aufnahme-Begrenzung: 25" oder "max. 25 Aufnahmen"
      if (match = line.match(/(?:Aufnahme-Begrenzung|Aufnahmen|max\.?\s*\d+)[:\s]+(\d+)/i))
        params[:innings_goal] = match[1].to_i
      end
      
      # Alternative Pattern: "25 Aufnahmen"
      if (match = line.match(/(\d+)\s+Aufnahmen/i)) && !params[:innings_goal]
        params[:innings_goal] = match[1].to_i
      end
    end
    
    params
  end
  
  # Extrahiert Turniermodus-Info (z.B. "T21 - 3 Gruppen à 3, 4 und 4 Spieler")
  def self.extract_tournament_plan_info(text)
    lines = text.split("\n")
    
    lines.each do |line|
      # Format 1: "Turniermodus: T21 - 3 Gruppen à 3, 4 und 4 Spieler"
      if (match = line.match(/Turniermodus:\s*(.+)/i))
        plan_info = match[1].strip.gsub(/\s+/, ' ')
        Rails.logger.info "===== extract_plan_info ===== Found (Format 1): #{plan_info}"
        return plan_info if plan_info.present?
      end
      
      # Format 2: "T21     Turnier wird im Modus 3 Gruppen à 3, 4 und 4 Spieler"
      # Verwende \s+ für beliebige Whitespaces (Leerzeichen, Tabs, etc.)
      if (match = line.match(/(T\d+)\s+Turnier\s+wird\s+im\s+Modus\s+(.+)/i))
        plan_name = match[1].upcase
        plan_details = match[2].strip.split(/[,\.]/)[0]  # Bis zum ersten Komma/Punkt
        plan_info = "#{plan_name} - #{plan_details}"
        Rails.logger.info "===== extract_plan_info ===== Found (Format 2): #{plan_info}"
        return plan_info if plan_info.present?
      end
      
      # Format 3: Direkt "T21" am Zeilenanfang mit Beschreibung
      if (match = line.match(/^\s*(T\d+)\s+(.+Gruppen[^,]+(?:,\s*\d+)?)/i))
        plan_name = match[1].upcase
        # Extrahiere Gruppenbeschreibung (inkl. Zahlen nach Kommas)
        plan_details = match[2].strip
        plan_info = "#{plan_name} - #{plan_details}"
        Rails.logger.info "===== extract_plan_info ===== Found (Format 3): #{plan_info}"
        return plan_info if plan_info.present?
      end
    end
    
    Rails.logger.info "===== extract_plan_info ===== Keine Turniermodus-Info gefunden"
    nil
  rescue => e
    Rails.logger.error "===== extract_plan_info ===== Error: #{e.message}"
    nil
  end
  
  # Extrahiert Gruppenbildung aus der Einladung
  # Unterstützt zwei Formate:
  # 1. "Spieler 1 | Spieler 5 | Spieler 9" (Position-basiert)
  # 2. "Kämmer | Benkert | Petry" (Namen-basiert, benötigt extracted_players)
  def self.extract_group_assignment(text, player_count, extracted_players = [])
    lines = text.split("\n")
    in_group_section = false
    group_data = {}
    group_names = {}  # Hash statt Array! Für Namen-basiertes Format
    column_positions = []  # Spalten-Positionen aus Header-Zeile
    
    lines.each do |line|
      # Start der Gruppenbildung
      if line =~ /Gruppenbildung/i
        in_group_section = true
        next
      end
      
      # Ende der Sektion
      if in_group_section && line =~ /Spielrunde|Tisch\s+\d|Spielpaarung/i
        break
      end
      
      # Parse Gruppen-Header: "Gruppe 1    Gruppe 2     Gruppe 3"
      # WICHTIG: Extrahiere auch die Spalten-Positionen!
      if in_group_section && line =~ /Gruppe\s+\d/i
        group_numbers = line.scan(/Gruppe\s+(\d+)/i).flatten.map(&:to_i)
        group_numbers.each { |gn| group_data[gn] = []; group_names[gn] = [] }
        
        # Extrahiere Spalten-Positionen (wo beginnt "Gruppe 1", "Gruppe 2", etc.)
        column_positions = []
        group_numbers.each do |gn|
          match_pos = line.index(/Gruppe\s+#{gn}/i)
          column_positions << match_pos if match_pos
        end
        Rails.logger.info "===== extract_groups ===== Column positions: #{column_positions.inspect}"
        next
      end
      
      # Parse Spieler-Zeilen
      if in_group_section && group_data.any?
        # Format 1: "Spieler 1 | Spieler 5 | Spieler 9"
        if line =~ /Spieler\s+\d/
          player_numbers = line.scan(/Spieler\s+(\d+)/i).flatten.map(&:to_i)
          player_numbers.each_with_index do |pn, col_index|
            group_no = col_index + 1
            group_data[group_no] << pn if group_data[group_no]
          end
        # Format 2: Spielernamen in Spalten (positions-basiert!)
        elsif line =~ /[A-ZÄÖÜ]/  # Enthält Großbuchstaben (Nachnamen)
          # Skip Linien mit nur Trennstrichen
          next if line.gsub(/[\s\-]/, '').length < 3
          
          # Wenn wir Spalten-Positionen haben: positions-basiertes Splitting
          if column_positions.any?
            group_numbers = group_data.keys.sort
            group_numbers.each_with_index do |group_no, idx|
              start_pos = column_positions[idx]
              end_pos = column_positions[idx + 1] || line.length
              
              # Extrahiere Text aus dieser Spalte
              column_text = line[start_pos...end_pos].to_s.strip
              
              # Bereinige: Entferne führende Trennstriche
              clean_name = column_text.gsub(/^[\-]+/, '').strip
              
              # Füge hinzu wenn nicht leer
              if clean_name.present? && clean_name !~ /^[\-]+$/
                group_names[group_no] << clean_name
              end
            end
          else
            # Fallback: Whitespace-basiertes Splitting (alte Logik)
            names = line.split(/\s{2,}/).map(&:strip).reject(&:blank?).reject { |n| n =~ /^[\-]+$/ }
            
            names.each_with_index do |name, col_index|
              group_no = col_index + 1
              clean_name = name.gsub(/^[\-]+/, '').strip
              group_names[group_no] << clean_name if group_names[group_no] && clean_name.present?
            end
          end
        end
      end
    end
    
    # Wenn Namen-Format: Konvertiere Namen zu Positionen
    if group_names.any?(&:present?) && extracted_players.present?
      Rails.logger.info "===== extract_groups ===== Namen-basiertes Format erkannt"
      group_names.each do |group_no, names|
        next unless names.present?
        
        names.each do |name|
          # Suche Spieler in extracted_players
          # Tolerant matching: "Schmid-W" matched "Schmid" oder "Schmid, Werner"
          # Entferne Bindestriche und vergleiche nur den Hauptteil
          name_base = name.split(/[\-\/]/).first.strip.upcase
          
          player = extracted_players.find do |p|
            p[:lastname].upcase == name.upcase ||           # Exakter Match
            p[:lastname].upcase == name_base ||             # Match ohne Suffix (Schmid-W -> Schmid)
            p[:lastname].upcase.start_with?(name_base)      # Prefix-Match
          end
          
          if player
            group_data[group_no] << player[:position]
          else
            Rails.logger.warn "===== extract_groups ===== Spieler '#{name}' nicht in Setzliste gefunden"
          end
        end
      end
    end
    
    # Nur zurückgeben wenn plausibel
    if group_data.any? && group_data.values.flatten.sort == (1..player_count).to_a.sort
      Rails.logger.info "===== extract_groups ===== Gruppenbildung gefunden: #{group_data.inspect}"
      group_data
    else
      Rails.logger.info "===== extract_groups ===== Keine valide Gruppenbildung gefunden (erwartet: #{(1..player_count).to_a}, gefunden: #{group_data.values.flatten.sort})"
      nil
    end
  rescue => e
    Rails.logger.error "===== extract_groups ===== Error: #{e.message}\n#{e.backtrace&.join("\n")}"
    nil
  end
  
  # Matched Spieler aus der Datenbank mit der extrahierten Liste
  # Strategie: Seedings existieren bereits aus Meldeliste-Scraping
  # → Matche extrahierte Namen PRIORITÄR mit vorhandenen Seeding-Spielern
  def self.match_with_database(extracted_players, tournament)
    matched = []
    unmatched = []
    
    # Hole alle Seeding-Spieler des Turniers (diese sind bereits korrekt aus Meldeliste)
    seeding_players = tournament.seedings.joins(:player).includes(:player).map(&:player)
    
    extracted_players.each do |ep|
      player = nil
      confidence = nil
      match_method = nil
      
      # Strategie 1: Exakter Match mit Seeding-Spieler (Nachname exakt, Vorname exakt)
      player = seeding_players.find do |p|
        p.lastname.to_s.downcase == ep[:lastname].to_s.strip.downcase &&
        p.firstname.to_s.downcase == ep[:firstname].to_s.strip.downcase
      end
      if player
        confidence = :high
        match_method = "Exakt (Name)"
      end
      
      # Strategie 2: Nachname exakt, Vorname enthält extrahierten Namen
      # Z.B. extrahiert "Gernot" matched "Dr. Gernot"
      unless player
        player = seeding_players.find do |p|
          p.lastname.to_s.downcase == ep[:lastname].to_s.strip.downcase &&
          p.firstname.to_s.downcase.include?(ep[:firstname].to_s.strip.downcase)
        end
        if player
          confidence = :high
          match_method = "Exakt (Nachname), enthält (Vorname)"
        end
      end
      
      # Strategie 3: Extrahierter Vorname enthält DB-Vorname
      # Z.B. extrahiert "Dr. Gernot" matched "Gernot"
      unless player
        player = seeding_players.find do |p|
          p.lastname.to_s.downcase == ep[:lastname].to_s.strip.downcase &&
          ep[:firstname].to_s.downcase.include?(p.firstname.to_s.downcase)
        end
        if player
          confidence = :high
          match_method = "Exakt (Nachname), extrahiert enthält DB-Vorname"
        end
      end
      
      # Strategie 4: Fuzzy Match nur bei Nachname (Nachname enthält, Vorname exakt)
      unless player
        player = seeding_players.find do |p|
          p.lastname.to_s.downcase.include?(ep[:lastname].to_s.strip.downcase) &&
          p.firstname.to_s.downcase == ep[:firstname].to_s.strip.downcase
        end
        if player
          confidence = :medium
          match_method = "Fuzzy (Nachname enthält), exakt (Vorname)"
        end
      end
      
      # Strategie 5: Suche in ALLEN Spielern der Region (Fallback)
      # Nur wenn in Seedings nicht gefunden
      unless player
        player = Player.where(type: nil, region_id: tournament.region_id)
                       .where("LOWER(lastname) = LOWER(?) AND LOWER(firstname) = LOWER(?)", 
                              ep[:lastname].strip, ep[:firstname].strip)
                       .first
        if player
          confidence = :medium
          match_method = "Exakt (aus Region, nicht in Seedings!)"
        end
      end
      
      if player
        Rails.logger.info "===== match ===== '#{ep[:full_name]}' → Player #{player.id} (#{player.lastname}, #{player.firstname}) via #{match_method}"
        matched << {
          position: ep[:position],
          player: player,
          extracted_name: ep[:full_name],
          balls_goal: ep[:balls_goal],  # Vorgabe mitgeben
          confidence: confidence,
          suggestion: (confidence != :high)
        }
      else
        Rails.logger.warn "===== match ===== '#{ep[:full_name]}' → NICHT GEFUNDEN"
        unmatched << ep
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
    # Wichtig: AND statt OR - beide Namen müssen matchen!
    # Sonst werden falsche Spieler zugeordnet (z.B. "Unger, Jörg" -> "Winterstein, Jörg")
    Player.where("lastname ILIKE ? AND firstname ILIKE ?", 
                 "%#{lastname}%", "%#{firstname}%").first
  end
end

