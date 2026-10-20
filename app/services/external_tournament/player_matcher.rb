# frozen_string_literal: true

module ExternalTournament
  # Plan 15-02: Player-Matcher mit Fallback-Kette für External-Tournament-Bridge.
  #
  # Wird in 15-03 (Round-Start) verwendet, wenn App-übergebene Player-Daten
  # (cc_id, dbu_nr, firstname, lastname, club_cc_id) auf Carambus-Player
  # gemappt werden müssen. 15-02 (Seeding-Read) nutzt bereits Carambus-Players
  # direkt aus Seedings — kein Mapping nötig.
  #
  # Fallback-Kette (Betreiber 2026-10-20: die DBU-Nummer entscheidet — Spieler sind teils in
  # mehreren Vereinen/Landesverbaenden Mitglied, die cc_id ist nur je Region eindeutig):
  #   1. dbu_nr (cross-region; DBU-Mitgliedschaft bundesweit eindeutig)
  #   2. region+cc_id (nur wenn die dbu_nr nichts liefert; Treffer mit widersprechender
  #      dbu_nr zaehlt nicht)
  #   3. firstname+lastname [+club_cc_id falls vorhanden]
  #
  # @example
  #   matcher = ExternalTournament::PlayerMatcher.new(region: Region.find_by(shortname: "NBV"))
  #   player = matcher.match(cc_id: 9001, dbu_nr: "12001", firstname: "Hans", lastname: "Müller")
  #   # => Player oder nil
  class PlayerMatcher
    def initialize(region:)
      @region = region
    end

    # Versucht Player zu matchen anhand der drei Fallback-Pfade.
    # @param attrs [Hash] Player-Attribute aus 3BandMannschaftsTurnier-Spec
    # @option attrs [Integer] :cc_id Club-Cloud-User-ID
    # @option attrs [String,Integer] :dbu_nr DBU-Mitgliedsnummer (kann als String oder Int kommen)
    # @option attrs [String] :firstname
    # @option attrs [String] :lastname
    # @option attrs [Integer] :club_cc_id
    # @return [Player, nil] der gemachte Player oder nil
    def match(attrs)
      attrs = attrs.symbolize_keys
      match_by_dbu_nr(attrs) ||
        match_by_region_cc_id(attrs[:cc_id], attrs[:dbu_nr]) ||
        match_by_name_and_club(attrs)
    end

    private

    # Path 2: region+cc_id (cc_id region-scoped da NICHT global unique) — nur, wenn die dbu_nr
    # nichts liefert (keine mitgeschickt oder lokal unbekannt).
    # Ein Spieler aus einem fremden LV (DBU-Turnier) bringt die cc_id SEINER Region mit; in der
    # Region des Servers trägt sie womöglich ein anderer Mensch (GP Biathlon 2026-10-13: Andres/BVW
    # und Pusch/NBV teilen 10050). Widerspricht die dbu_nr des Treffers der mitgeschickten, gilt
    # der Treffer nicht — dann entscheidet der Name (Path 3).
    def match_by_region_cc_id(cc_id, dbu_nr)
      return nil if cc_id.blank?
      player = Player.where(region_id: @region.id, cc_id: cc_id.to_i).first
      return nil if player&.dbu_nr.present? && dbu_nr.present? && player.dbu_nr.to_i != dbu_nr.to_i
      player
    end

    # Path 1: dbu_nr (cross-region). Im Bestand gibt es doppelte Datensaetze je dbu_nr
    # (bcw 2026-10-20: 120 Nummern, meist dieselbe Person — Schreibvariante, Namensaenderung;
    # dazu Team-Datensaetze). Teams zaehlen nicht; bei mehreren Treffern entscheidet
    # region+cc_id, dann der Name, sonst der aelteste Datensatz.
    def match_by_dbu_nr(attrs)
      return nil if attrs[:dbu_nr].blank?

      candidates = Player.where(dbu_nr: attrs[:dbu_nr].to_i)
        .where("players.type IS NULL OR players.type <> 'Team'").order(:id).to_a
      return candidates.first if candidates.size <= 1

      by_cc = candidates.select { |p| attrs[:cc_id].present? && p.region_id == @region.id && p.cc_id == attrs[:cc_id].to_i }
      return by_cc.first if by_cc.size == 1

      by_name = candidates.select do |p|
        p.lastname.to_s.casecmp?(attrs[:lastname].to_s) && p.firstname.to_s.casecmp?(attrs[:firstname].to_s)
      end
      by_name.first || candidates.first
    end

    # Path 3: firstname+lastname [+ club_cc_id falls vorhanden]
    def match_by_name_and_club(attrs)
      return nil if attrs[:firstname].blank? || attrs[:lastname].blank?

      scope = Player.where(
        "lower(firstname) = ? AND lower(lastname) = ?",
        attrs[:firstname].to_s.downcase, attrs[:lastname].to_s.downcase
      )

      if attrs[:club_cc_id].present?
        club = Club.find_by(cc_id: attrs[:club_cc_id])
        scope = scope.joins(:clubs).where(clubs: {id: club.id}) if club
      end

      scope.first
    end
  end
end
