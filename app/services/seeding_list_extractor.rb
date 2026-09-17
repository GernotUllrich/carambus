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
        next if line.strip.empty?
        # Kopfzeile der Tabelle
        next if line =~ /^\s*Setz\.?\s+GD\s+(?:Ballzahl\s+)?Name\s+Verein/i
        # Einleitungssatz ("Setzliste nach GD-Rangliste 2025/2026.")
        next if line =~ /Rangliste/i

        # CC-Format (seit September 2026), eine Zeile je Teilnehmer. Es gibt zwei Auspraegungen:
        #
        #   ohne Vorgabe (Meisterschaft, einheitliches Ausspielziel):
        #   "     1        1,51             Mustermann, Anton        TSV Beispiel"
        #    \_Setz._/     \_GD_/           \_Nachname, Vorname_/    \_Verein_/
        #
        #   mit Vorgabe (Vorgabeturnier, Ballzahl je Spieler):
        #   "     1        3,39     50      Mustermann, Dr. Anton    BC Beispiel"
        #    \_Setz._/     \_GD_/   \Ball/  \_Nachname, Vorname_/    \_Verein_/
        #
        # Die GD (Generaldurchschnitt aus der Rangliste) wird NICHT ausgewertet — sie ist
        # keine Vorgabe. Bis zum Formatwechsel stand an aehnlicher Stelle das Ballziel; eine
        # GD als Vorgabe einzutragen waere ein stiller Datenfehler (1,51 statt 50).
        # Die SPALTE "Ballzahl" dagegen IST die Vorgabe und wird als balls_goal uebernommen.
        # Sie fehlt bei Turnieren mit einheitlichem Ausspielziel — deshalb optional.
        #
        # Die GD kann "-" sein (Teilnehmer ohne Ranglistenwert).
        # Der Verein steht hinter mindestens zwei Leerzeichen — im Namen selbst kommen nur
        # einfache vor, auch bei mehrteiligen Nachnamen ("von der Gönna, Patrick") und
        # Titeln im Vornamen ("Ullrich, Dr. Gernot").
        cc_row = /^\s*(\d+)\s+(?:[\d.,]+|-)\s+(?:(\d+)\s+)?([^,]+?),\s*(\S(?:.*?\S)?)\s{2,}(.+?)\s*$/

        next unless (match = line.match(cc_row))

        spieler = {
          position: match[1].to_i,
          lastname: match[3].strip,
          firstname: match[4].strip,
          full_name: "#{match[3].strip}, #{match[4].strip}",
          club: match[5].strip
        }
        spieler[:balls_goal] = match[2].to_i if match[2]
        players << spieler
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
      # CC-Format (seit September 2026): "Ausspielziel:  40 Punkte / 20 Aufnahmen" —
      # die Zahl steht VOR der Einheit. Bis dahin stand sie dahinter ("Ballziel: 100").
      if (match = line.match(/(\d+)\s*(?:Punkte|Bälle|Pkt)\b/i))
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
      # CC-Format (seit September 2026): "Modus:  T7 - Jeder gegen jeden".
      # `Turniermodus:` bleibt mit abgedeckt, weil dieselbe Zeile im Fliesstext der
      # Beschreibung vorkommt ("Turniermodus T7 gemaess STO-BTK ...") — der Doppelpunkt
      # unterscheidet die Label-Zeile davon.
      if (match = line.match(/(?:Turnier)?Modus:\s*(.+)/i))
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
      
      # Normalisiere extrahierte Namen (ß → ss für Matching)
      extracted_lastname_normalized = ep[:lastname].to_s.strip.downcase.gsub('ß', 'ss')
      extracted_firstname_normalized = ep[:firstname].to_s.strip.downcase.gsub('ß', 'ss')
      
      # Strategie 1: Exakter Match mit Seeding-Spieler (Nachname exakt, Vorname exakt)
      # Berücksichtigt ß/ss Varianten
      player = seeding_players.find do |p|
        db_lastname_normalized = p.lastname.to_s.downcase.gsub('ß', 'ss')
        db_firstname_normalized = p.firstname.to_s.downcase.gsub('ß', 'ss')
        
        db_lastname_normalized == extracted_lastname_normalized &&
        db_firstname_normalized == extracted_firstname_normalized
      end
      if player
        confidence = :high
        match_method = "Exakt (Name)"
      end
      
      # Strategie 2: Nachname exakt, Vorname enthält extrahierten Namen
      # Z.B. extrahiert "Gernot" matched "Dr. Gernot"
      unless player
        player = seeding_players.find do |p|
          db_lastname_normalized = p.lastname.to_s.downcase.gsub('ß', 'ss')
          db_firstname_normalized = p.firstname.to_s.downcase.gsub('ß', 'ss')
          
          db_lastname_normalized == extracted_lastname_normalized &&
          db_firstname_normalized.include?(extracted_firstname_normalized)
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
          db_lastname_normalized = p.lastname.to_s.downcase.gsub('ß', 'ss')
          db_firstname_normalized = p.firstname.to_s.downcase.gsub('ß', 'ss')
          
          db_lastname_normalized == extracted_lastname_normalized &&
          extracted_firstname_normalized.include?(db_firstname_normalized)
        end
        if player
          confidence = :high
          match_method = "Exakt (Nachname), extrahiert enthält DB-Vorname"
        end
      end
      
      # Strategie 4: Fuzzy Match nur bei Nachname (Nachname enthält, Vorname exakt)
      unless player
        player = seeding_players.find do |p|
          db_lastname_normalized = p.lastname.to_s.downcase.gsub('ß', 'ss')
          db_firstname_normalized = p.firstname.to_s.downcase.gsub('ß', 'ss')
          
          db_lastname_normalized.include?(extracted_lastname_normalized) &&
          db_firstname_normalized == extracted_firstname_normalized
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

