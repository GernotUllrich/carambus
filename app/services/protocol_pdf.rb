# frozen_string_literal: true

require 'prawn'
require 'prawn/table'

class ProtocolPdf
  def initialize(table_monitor, history, location)
    # Hide m17n warning for built-in fonts
    Prawn::Fonts::AFM.hide_m17n_warning = true
    
    @table_monitor = table_monitor
    @history = history
    @location = location
    @player_a = history[:player_a]
    @player_b = history[:player_b]
    # Get HS and GD from table_monitor data
    @player_a_hs = table_monitor.data.dig('playera', 'hs').to_i
    @player_a_gd = sanitize_text((table_monitor.data.dig('playera', 'gd') || '0.00').to_s)
    @player_b_hs = table_monitor.data.dig('playerb', 'hs').to_i
    @player_b_gd = sanitize_text((table_monitor.data.dig('playerb', 'gd') || '0.00').to_s)
  end

  def render
    Prawn::Document.new(page_size: 'A4', page_layout: :landscape, margin: [5]) do |pdf|
      # Generate 3 protocol sheets side by side on ONE page
      # A4 landscape is 842 points wide, minus margins = 832 points
      # Divide by 3 = 277 points per sheet (about 9.8cm)
      available_width = pdf.bounds.width
      sheet_width = available_width / 3
      sheet_height = 19 * 28.35 # 539 points (~19cm)
      
      3.times do |sheet_index|
        sheet_x = sheet_index * sheet_width
        
        pdf.bounding_box([sheet_x, pdf.bounds.height], width: sheet_width, height: sheet_height) do
          draw_protocol_sheet(pdf)
        end
      end
    end.render
  end

  private

  def draw_protocol_sheet(pdf)
    # Draw border around entire sheet (9.5cm x 19cm)
    pdf.stroke_bounds
    
    # Header section (3.5cm high = 99 points)
    header_height = 3.5 * 28.35
    
    # Location name and address (2 lines)
    pdf.bounding_box([2, pdf.bounds.height - 2], width: pdf.bounds.width - 4, height: 20) do
      pdf.text sanitize_text(@location.name), size: 7, style: :bold, align: :center
      pdf.text sanitize_text(@location.address), size: 5, align: :center
    end
    
    # Horizontal line after address
    pdf.stroke_horizontal_line 0, pdf.bounds.width, at: pdf.bounds.height - 22
    
    # Game info line (Disziplin | Partie-Laenge | Partie-Nr. | Datum)
    pdf.bounding_box([2, pdf.bounds.height - 24], width: pdf.bounds.width - 4, height: 12) do
      discipline = sanitize_text(@table_monitor.discipline || 'Freie Partie')
      goal = @table_monitor.data.dig('playera', 'balls_goal').to_i > 0 ? "#{@table_monitor.data.dig('playera', 'balls_goal')}" : "unendlich"
      partie_nr = ""
      date = Time.current.strftime("%d/%m/%Y")
      
      pdf.text "#{discipline} | Partie-Laenge #{goal} | #{partie_nr} | #{date}", size: 4, align: :center
    end
    
    # Horizontal line after game info
    pdf.stroke_horizontal_line 0, pdf.bounds.width, at: pdf.bounds.height - 36
    
    # Player names line
    player_a_name = sanitize_text((@player_a[:shortname] || @player_a[:name]).to_s)[0..20]
    player_b_name = sanitize_text((@player_b[:shortname] || @player_b[:name]).to_s)[0..20]
    
    pdf.bounding_box([2, pdf.bounds.height - 38], width: pdf.bounds.width - 4, height: 12) do
      pdf.text_box player_a_name, at: [0, 10], size: 5, width: (pdf.bounds.width / 2) - 2
      pdf.text_box player_b_name, at: [(pdf.bounds.width / 2) + 2, 10], size: 5, width: (pdf.bounds.width / 2) - 2
    end
    
    # Horizontal line after player names
    pdf.stroke_horizontal_line 0, pdf.bounds.width, at: pdf.bounds.height - 50
    
    # Table section (13.5cm high = 383 points) with 26 rows
    table_y = pdf.bounds.height - 52
    draw_protocol_table(pdf, table_y)
    
    # Footer section (2cm high = 57 points) with 4 lines
    draw_footer(pdf)
  end

  def draw_protocol_table(pdf, start_y)
    # Table with exactly 26 rows (numbered 1-25 and 26-50)
    # Layout: Serie A | Gesamt A | Aufn.(1-25) | Serie A | Gesamt A | Aufn.(26-50) | Serie B | Gesamt B
    # Wait, the original shows: Serie | Gesamt | Serie | Gesamt | Aufn. (middle columns)
    # But based on image: Player A left, Player B right, Aufnahmen in the middle
    
    table_data = []
    
    # Header row
    table_data << [
      { content: "Serie", size: 4, font_style: :bold },
      { content: "Gesamt", size: 4, font_style: :bold },
      { content: "Serie", size: 4, font_style: :bold },
      { content: "Gesamt", size: 4, font_style: :bold },
      { content: "Aufn.", size: 4, font_style: :bold },
      { content: "Serie", size: 4, font_style: :bold },
      { content: "Gesamt", size: 4, font_style: :bold },
      { content: "Serie", size: 4, font_style: :bold },
      { content: "Gesamt", size: 4, font_style: :bold },
      { content: "Aufn.", size: 4, font_style: :bold }
    ]
    
    # 25 data rows (for innings 1-25 and 26-50)
    25.times do |i|
      inning_left = i  # 0-24 (display as 1-25)
      inning_right = i + 25  # 25-49 (display as 26-50)
      
      serie_a_left = @player_a[:innings][inning_left] || ''
      gesamt_a_left = @player_a[:totals][inning_left] || ''
      serie_b_left = @player_b[:innings][inning_left] || ''
      gesamt_b_left = @player_b[:totals][inning_left] || ''
      
      serie_a_right = @player_a[:innings][inning_right] || ''
      gesamt_a_right = @player_a[:totals][inning_right] || ''
      serie_b_right = @player_b[:innings][inning_right] || ''
      gesamt_b_right = @player_b[:totals][inning_right] || ''
      
      table_data << [
        { content: serie_a_left.to_s, size: 4 },
        { content: gesamt_a_left.to_s, size: 4 },
        { content: serie_b_left.to_s, size: 4 },
        { content: gesamt_b_left.to_s, size: 4 },
        { content: (inning_left + 1).to_s, size: 4, font_style: :bold },
        { content: serie_a_right.to_s, size: 4 },
        { content: gesamt_a_right.to_s, size: 4 },
        { content: serie_b_right.to_s, size: 4 },
        { content: gesamt_b_right.to_s, size: 4 },
        { content: (inning_right + 1).to_s, size: 4, font_style: :bold }
      ]
    end
    
    # Draw table at specified position
    # 13.5cm = 382.7 points for 26 rows (1 header + 25 data)
    # row_height = 382.7 / 26 = ~14.7 points per row
    # padding + text = 14.7, with size 4, padding should be ~5 points top/bottom
    table_height = 13.5 * 28.35
    
    pdf.bounding_box([1, start_y], width: pdf.bounds.width - 2, height: table_height) do
      pdf.table(table_data,
                width: pdf.bounds.width,
                cell_style: {
                  size: 4,
                  padding: [5, 1],  # Increased vertical padding to fill space
                  borders: [:left, :right, :top, :bottom],
                  border_width: 0.2,
                  align: :center,
                  overflow: :shrink_to_fit
                }) do |t|
        # Set equal height for all rows
        (0...26).each do |i|
          t.row(i).height = table_height / 26
        end
      end
    end
  end
  
  def draw_footer(pdf)
    # Footer section (2cm high) at bottom of sheet
    footer_y = 2 * 28.35
    
    pdf.bounding_box([2, footer_y], width: pdf.bounds.width - 4, height: (2 * 28.35) - 2) do
      # Horizontal line at top of footer
      pdf.stroke_horizontal_line 0, pdf.bounds.width, at: pdf.bounds.height
      
      # Right-aligned labels
      y_pos = pdf.bounds.height - 5
      line_height = 10
      
      pdf.text_box "Anzahl der Baelle", at: [pdf.bounds.width - 80, y_pos], size: 4, align: :right, width: 75
      y_pos -= line_height
      pdf.text_box "Anzahl der Aufnahmen", at: [pdf.bounds.width - 80, y_pos], size: 4, align: :right, width: 75
      y_pos -= line_height
      pdf.text_box "Durchschnitt", at: [pdf.bounds.width - 80, y_pos], size: 4, align: :right, width: 75
      y_pos -= line_height
      pdf.text_box "Hoechstserie", at: [pdf.bounds.width - 80, y_pos], size: 4, align: :right, width: 75
    end
  end
  
  private
  
  def sanitize_text(text)
    # Replace German umlauts and special characters with ASCII equivalents
    text.to_s
        .gsub('ä', 'ae').gsub('Ä', 'Ae')
        .gsub('ö', 'oe').gsub('Ö', 'Oe')
        .gsub('ü', 'ue').gsub('Ü', 'Ue')
        .gsub('ß', 'ss')
        .gsub('€', 'EUR')
        .encode('Windows-1252', invalid: :replace, undef: :replace, replace: '?')
  end
end

