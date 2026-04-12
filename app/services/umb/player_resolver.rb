# frozen_string_literal: true

# Spieler-Lookup und -Erstellung aus UMB-PDF-Daten.
# Konsolidiert V1 (find_or_create_international_player) und V2 (find_player_by_caps_and_mixed).
#
# V2's caps+mixed Strategie ist die primäre Lookup-Methode, da sie beide Namensreihenfolgen
# (westlich und asiatisch) unterstützt.
#
# ApplicationService gemäß D-03 — hat DB-Seiteneffekte (erstellt Player-Datensätze).
class Umb::PlayerResolver
  # Sucht einen bestehenden Spieler oder erstellt einen neuen.
  #
  # @param caps_name [String]  Name in Großbuchstaben (z.B. "SMITH" oder "JASPERS")
  # @param mixed_name [String] Name in gemischter Schreibweise (z.B. "John" oder "Dick")
  # @param nationality [String] 2-Buchstaben ISO-Ländercode (z.B. "GB", "NL")
  # @param umb_player_id [Integer, nil] UMB-interne Spieler-ID für Cross-Referenz
  # @return [Player, nil] Gefundener oder erstellter Spieler, nil bei Fehler
  def resolve(caps_name, mixed_name, nationality: nil, umb_player_id: nil)
    return nil if caps_name.blank? && mixed_name.blank?

    # Strategie 1: Suche via umb_player_id (schnellste, zuverlässigste Methode)
    if umb_player_id.present? && umb_player_id.to_i > 0
      player = Player.find_by(umb_player_id: umb_player_id.to_i)
      return player if player
    end

    # Strategie 2: caps+mixed Namenssuche (V2-Strategie — unterstützt westliche + asiatische Reihenfolge)
    player = find_by_caps_and_mixed(caps_name, mixed_name)
    if player
      # Fehlende Felder ergänzen falls vorhanden
      player.umb_player_id ||= umb_player_id.to_i if umb_player_id.present? && umb_player_id.to_i > 0
      player.nationality ||= nationality
      player.international_player = true
      player.save if player.changed?
      return player
    end

    # Strategie 3: Neuen internationalen Spieler erstellen
    create_international_player(caps_name, mixed_name, nationality: nationality, umb_player_id: umb_player_id)
  end

  # Sucht Spieler anhand von caps_name und mixed_name in allen Namensreihenfolgen.
  # Öffentlich — wird auch direkt von Scrapers verwendet.
  #
  # @return [Player, nil]
  def find_by_caps_and_mixed(caps_name, mixed_name)
    return nil if caps_name.blank? || mixed_name.blank?

    # Versuch 1: caps=Nachname, mixed=Vorname (häufigste westliche Reihenfolge)
    player = find_player_by_name(mixed_name, caps_name)
    return player if player

    # Versuch 2: caps=Vorname, mixed=Nachname (kommt bei manchen asiatischen Namen vor)
    player = find_player_by_name(caps_name, mixed_name)
    return player if player

    # Versuch 3: Teilübereinstimmung auf vollständigen Namen
    full_name = "#{caps_name} #{mixed_name}"
    Player.where(
      "LOWER(firstname || ' ' || lastname) = ? OR LOWER(lastname || ' ' || firstname) = ?",
      full_name.downcase,
      full_name.downcase
    ).first
  end

  private

  # Sucht Spieler nach Vor- und Nachname (beide Reihenfolgen).
  def find_player_by_name(firstname, lastname)
    return nil if firstname.blank? || lastname.blank?

    # Direkte Übereinstimmung
    player = Player.where(
      "LOWER(firstname) = ? AND LOWER(lastname) = ?",
      firstname.downcase,
      lastname.downcase
    ).first
    return player if player

    # Vertauscht (UMB tauscht manchmal die Namensreihenfolge zwischen PDFs)
    Player.where(
      "LOWER(firstname) = ? AND LOWER(lastname) = ?",
      lastname.downcase,
      firstname.downcase
    ).first
  end

  # Erstellt einen neuen internationalen Spieler aus UMB-Daten.
  # Abgeleitet aus V1 find_or_create_international_player (Zeile 1772).
  def create_international_player(caps_name, mixed_name, nationality:, umb_player_id:)
    # Vorname/Nachname aus caps+mixed ableiten: caps ist meist der Nachname
    firstname = mixed_name.to_s.strip
    lastname = caps_name.to_s.capitalize

    fl_name = "#{firstname} #{lastname}".strip

    player = Player.new(
      firstname: firstname,
      lastname: lastname,
      fl_name: fl_name,
      nationality: nationality,
      umb_player_id: (umb_player_id.to_i > 0 ? umb_player_id.to_i : nil),
      international_player: true
    )

    if player.save
      player
    else
      Rails.logger.error "[Umb::PlayerResolver] Spieler konnte nicht gespeichert werden #{fl_name}: #{player.errors.full_messages}"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "[Umb::PlayerResolver] Fehler beim Erstellen von Spieler #{caps_name}/#{mixed_name}: #{e.message}"
    nil
  end
end
