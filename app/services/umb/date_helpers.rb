# frozen_string_literal: true

# Gemeinsam genutzte Datums-Parsing-Hilfsmethoden für UMB-Scraper.
# Extrahiert aus UmbScraper (V1) — wird von FutureScraper und ArchiveScraper verwendet.
#
# Alle Methoden sind module_function, sodass sie als
#   Umb::DateHelpers.parse_date_range("18-21 Dec 2025")
# aufgerufen werden können.
module Umb::DateHelpers
  module_function

  # Parst einen Datumsbereich-String (z.B. "18-21 Dec 2025" oder "Feb 26 - Mar 1, 2026").
  # Gibt {:start_date, :end_date} zurück; beide nil wenn kein Parse möglich.
  def parse_date_range(date_str, year: Time.current.year)
    return { start_date: nil, end_date: nil } if date_str.blank?

    # Whitespace und Zeilenumbrüche normalisieren
    cleaned = date_str.strip.gsub(/\s+/, " ").gsub(/\n+/, " ")

    # Zu kurze Strings überspringen
    if cleaned.length < 3
      Rails.logger.debug "[Umb::DateHelpers] Date too short: '#{date_str}'"
      return { start_date: nil, end_date: nil }
    end

    # Monatsübergreifende Bereiche zuerst prüfen (spezifischer), dann gleicher-Monat
    result = parse_month_day_range(cleaned) ||
      parse_day_range_with_month(cleaned, year: year)

    if result
      Rails.logger.debug "[Umb::DateHelpers] Parsed '#{date_str}' → #{result[:start_date]} to #{result[:end_date]}"
      result
    else
      Rails.logger.info "[Umb::DateHelpers] Could not parse date: '#{date_str}' (cleaned: '#{cleaned}')"
      { start_date: nil, end_date: nil }
    end
  rescue StandardError => e
    Rails.logger.warn "[Umb::DateHelpers] Failed to parse date: #{date_str} - #{e.message}"
    { start_date: nil, end_date: nil }
  end

  # Parst ein einzelnes Datum wie "04-November-2024" oder "15 January 2025".
  def parse_single_date(date_str)
    return nil if date_str.blank?

    begin
      Date.parse(date_str)
    rescue ArgumentError, TypeError
      nil
    end
  end

  # Parst "18-21 Dec 2025", "18 - 21 Dec 2025" oder "December 18-21, 2025".
  def parse_day_range_with_month(str, year: Time.current.year)
    # Pattern: "18-21 Dec 2025" oder "18 - 21 Dec 2025"
    if (match = str.match(/(\d{1,2})\s*-\s*(\d{1,2})\s+([A-Za-z]+)[\s,]*(\d{4})?/))
      start_day = match[1].to_i
      end_day = match[2].to_i
      month_str = match[3]
      year_from_match = match[4]&.to_i || year

      month = parse_month_name(month_str)
      return nil unless month

      begin
        return {
          start_date: Date.new(year_from_match, month, start_day),
          end_date: Date.new(year_from_match, month, end_day)
        }
      rescue ArgumentError => e
        Rails.logger.warn "[Umb::DateHelpers] Invalid date: #{year_from_match}-#{month}-#{start_day} to #{end_day}: #{e.message}"
        return nil
      end
    end

    # Pattern: "December 18-21, 2025" oder "December 18 - 21, 2025"
    if (match = str.match(/([A-Za-z]+)\s+(\d{1,2})\s*-\s*(\d{1,2})[\s,]*(\d{4})?/))
      month_str = match[1]
      start_day = match[2].to_i
      end_day = match[3].to_i
      year_from_match = match[4]&.to_i || year

      month = parse_month_name(month_str)
      return nil unless month

      begin
        return {
          start_date: Date.new(year_from_match, month, start_day),
          end_date: Date.new(year_from_match, month, end_day)
        }
      rescue ArgumentError => e
        Rails.logger.warn "[Umb::DateHelpers] Invalid date: #{year_from_match}-#{month}-#{start_day} to #{end_day}: #{e.message}"
        return nil
      end
    end

    nil
  end

  # Parst monatsübergreifende Bereiche wie "Feb 26 - Mar 1, 2026" oder "28 January - 2 February 2025".
  def parse_month_day_range(str)
    # Pattern A: "Feb 26 - Mar 1, 2026" (Monat zuerst)
    if (match = str.match(/([A-Za-z]+)\s+(\d{1,2})\s*-\s*([A-Za-z]+)\s+(\d{1,2})[\s,]*(\d{4})/))
      start_month_str = match[1]
      start_day = match[2].to_i
      end_month_str = match[3]
      end_day = match[4].to_i
      year = match[5].to_i

      start_month = parse_month_name(start_month_str)
      end_month = parse_month_name(end_month_str)

      return nil unless start_month && end_month

      # Jahreswechsel behandeln (z.B. Dez 28 - Jan 3)
      end_year = year
      end_year += 1 if end_month < start_month

      return {
        start_date: Date.new(year, start_month, start_day),
        end_date: Date.new(end_year, end_month, end_day)
      }
    end

    # Pattern B: "28 January - 2 February 2025" (Tag zuerst)
    if (match = str.match(/(\d{1,2})\s+([A-Za-z]+)\s*-\s*(\d{1,2})\s+([A-Za-z]+)[\s,]*(\d{4})/))
      start_day = match[1].to_i
      start_month_str = match[2]
      end_day = match[3].to_i
      end_month_str = match[4]
      year = match[5].to_i

      start_month = parse_month_name(start_month_str)
      end_month = parse_month_name(end_month_str)

      return nil unless start_month && end_month

      # Jahreswechsel behandeln (z.B. 28 Dez - 3 Jan 2026)
      end_year = year
      end_year += 1 if end_month < start_month

      return {
        start_date: Date.new(year, start_month, start_day),
        end_date: Date.new(end_year, end_month, end_day)
      }
    end

    nil
  end

  # Parst ein Datum aus verschiedenen UMB-Formaten:
  #   "24-February-2025", "2025-02-24", "24/02/2025", "24.02.2025"
  def parse_date(date_string)
    return nil if date_string.blank?

    formats = [
      "%d-%B-%Y",   # 24-February-2025
      "%Y-%m-%d",   # 2025-02-24
      "%d/%m/%Y",   # 24/02/2025
      "%d.%m.%Y"    # 24.02.2025
    ]

    formats.each do |format|
      begin
        return Date.strptime(date_string, format)
      rescue ArgumentError
        next
      end
    end

    nil
  rescue StandardError
    nil
  end

  # Reichert einen Datums-String mit Monat/Jahr-Kontext an (z.B. "06 - 12" → "06 - 12 Jan 2025").
  def enhance_date_with_context(date_str, month, year)
    return date_str if date_str.blank? || month.nil? || year.nil?

    cleaned = date_str.strip.gsub(/\s+/, " ").gsub(/\n+/, " ")

    # Nur den Datumsteil extrahieren, falls weiterer Text vorhanden
    date_match = cleaned.match(/(\d{1,2}\s*-\s*\d{1,2})/)
    if date_match
      cleaned = date_match[1]
    end

    # Falls Datum nur "06 - 12" ist, Monatsnamen anhängen
    if cleaned.match?(/^\d{1,2}\s*-\s*\d{1,2}$/)
      month_abbr = Date::ABBR_MONTHNAMES[month]
      return "#{cleaned} #{month_abbr} #{year}"
    end

    # Unvollständige monatsübergreifende Daten überspringen
    if cleaned.match?(/^-?\s*\d{1,2}\s*-\s*$/) || cleaned.match?(/^-\s*\d{1,2}$/)
      return nil
    end

    date_str
  end

  # Wandelt einen Monatsnamen in eine Zahl um (1-12).
  def parse_month_name(name)
    return nil if name.blank?

    months = {
      "january" => 1, "jan" => 1,
      "february" => 2, "feb" => 2,
      "march" => 3, "mar" => 3,
      "april" => 4, "apr" => 4,
      "may" => 5,
      "june" => 6, "jun" => 6,
      "july" => 7, "jul" => 7,
      "august" => 8, "aug" => 8,
      "september" => 9, "sept" => 9, "sep" => 9,
      "october" => 10, "oct" => 10,
      "november" => 11, "nov" => 11,
      "december" => 12, "dec" => 12
    }

    months[name.downcase]
  end
end
