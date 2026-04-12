# frozen_string_literal: true

# Zuordnung von Turniernamen zu Discipline-Datenbankeinträgen.
# Konsolidiert die beiden duplizierten Methoden aus UmbScraper (V1):
#   - find_discipline_from_name (Zeile 1211) — detaillierte DB-ILIKE-Suche
#   - determine_discipline_from_name (Zeile 1468) — einfache String-Map als Fallback
#
# PORO gemäß D-03 (zustandsloser, reiner Algorithmus — keine Instanz nötig).
class Umb::DisciplineDetector
  # Erkennt die Disziplin aus einem Turniernamen.
  # Gibt einen Discipline-Datensatz zurück oder nil wenn keine Übereinstimmung.
  def self.detect(tournament_name)
    return nil if tournament_name.blank?

    # Strategie 1: Detaillierte DB-Suche (aus V1 find_discipline_from_name)
    result = detect_by_db_lookup(tournament_name)
    return result if result

    # Strategie 2: Einfache String-Map mit Fallback-DB-Lookup (aus V1 determine_discipline_from_name)
    detect_by_string_map(tournament_name)
  end

  # --- Private Implementierung ---

  def self.detect_by_db_lookup(name)
    name_lower = name.downcase

    # Cadre-Varianten zuerst prüfen (spezifischer als 3-Band)
    if name_lower.match?(/cadre|balkline/)
      return find_cadre_discipline(name_lower)
    end

    # 3-Kissen (Dreiband)
    if name_lower.match?(/3[\s\-]*cushion|three[\s\-]*cushion|dreiband|drei[\s\-]*band|3[\s\-]*bandes|3[\s\-]*banden/)
      # Internationale UMB-Turniere sind IMMER auf großen Tischen = "Dreiband groß"
      return Discipline.find_by("name ILIKE ?", "%dreiband%groß%") ||
        Discipline.find_by("name ILIKE ?", "%dreiband%gross%") ||
        Discipline.find_by("name ILIKE ?", "%three%cushion%") ||
        Discipline.find_by("name ILIKE ?", "%3%cushion%") ||
        Discipline.find_by("name ILIKE ?", "%dreiband%halb%") ||
        Discipline.find_by("name ILIKE ?", "%dreiband%") ||
        Discipline.find_by("name ILIKE ?", "Karambol")
    end

    # 5-Pin Billard
    if name_lower.match?(/5[\s\-]*pin/)
      return Discipline.find_by("name ILIKE ?", "%5%pin%") ||
        Discipline.find_by("name ILIKE ?", "%fünf%") ||
        Discipline.find_by("name ILIKE ?", "%five%")
    end

    # 1-Kissen (Einband)
    if name_lower.match?(/1[\s\-]*cushion|one[\s\-]*cushion|einband/)
      return Discipline.find_by("name ILIKE ?", "%einband%") ||
        Discipline.find_by("name ILIKE ?", "%1%cushion%")
    end

    # Artistique / Künstlerisch
    if name_lower.match?(/artistique|artistic|künstlerisch/)
      return Discipline.find_by("name ILIKE ?", "%artist%")
    end

    # Libre / Freie Partie
    if name_lower.match?(/libre|straight[\s\-]*rail|freie[\s\-]*partie/)
      return Discipline.find_by("name ILIKE ?", "%frei%parti%") ||
        Discipline.find_by("name ILIKE ?", "%libre%")
    end

    nil
  end
  private_class_method :detect_by_db_lookup

  def self.find_cadre_discipline(name_lower)
    if name_lower.match?(/47[\s\/\-]*2/)
      Discipline.find_by("name ILIKE ?", "%cadre%47%2%") ||
        Discipline.find_by("name ILIKE ?", "%47%2%")
    elsif name_lower.match?(/71[\s\/\-]*2/)
      Discipline.find_by("name ILIKE ?", "%cadre%71%2%") ||
        Discipline.find_by("name ILIKE ?", "%71%2%")
    elsif name_lower.match?(/57[\s\/\-]*2/)
      Discipline.find_by("name ILIKE ?", "%cadre%57%2%") ||
        Discipline.find_by("name ILIKE ?", "%57%2%")
    elsif name_lower.match?(/52[\s\/\-]*2/)
      Discipline.find_by("name ILIKE ?", "%cadre%52%2%") ||
        Discipline.find_by("name ILIKE ?", "%52%2%")
    elsif name_lower.match?(/35[\s\/\-]*2/)
      Discipline.find_by("name ILIKE ?", "%cadre%35%2%") ||
        Discipline.find_by("name ILIKE ?", "%35%2%")
    else
      # Generisches Cadre — Standard 47/2
      Discipline.find_by("name ILIKE ?", "%cadre%47%2%") ||
        Discipline.find_by("name ILIKE ?", "%cadre%")
    end
  end
  private_class_method :find_cadre_discipline

  # Einfache String-Map als Fallback (aus V1 determine_discipline_from_name).
  # Gibt nil zurück wenn kein Mapping passt (kein hartkodierter Default).
  def self.detect_by_string_map(name)
    mapped_name = map_name_to_discipline(name)
    return nil unless mapped_name

    Discipline.find_by(name: mapped_name)
  end
  private_class_method :detect_by_string_map

  def self.map_name_to_discipline(name)
    return "3-Cushion" if name =~ /3-cushion/i
    return "Cadre 47/2" if name =~ /cadre.*47.*2|47.*2.*cadre/i
    return "5-Pins" if name =~ /5-pins?/i
    return "Artistique" if name =~ /artistique/i
    return "Balkline" if name =~ /balkline/i

    nil
  end
  private_class_method :map_name_to_discipline
end
