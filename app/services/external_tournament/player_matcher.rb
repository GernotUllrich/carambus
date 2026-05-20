# frozen_string_literal: true

module ExternalTournament
  # Plan 15-02: Player-Matcher mit Fallback-Kette für External-Tournament-Bridge.
  #
  # Wird in 15-03 (Round-Start) verwendet, wenn App-übergebene Player-Daten
  # (cc_id, dbu_nr, firstname, lastname, club_cc_id) auf Carambus-Player
  # gemappt werden müssen. 15-02 (Seeding-Read) nutzt bereits Carambus-Players
  # direkt aus Seedings — kein Mapping nötig.
  #
  # Fallback-Kette (D-14-02-B revised — cc_id Primary region-scoped, dbu_nr Cross-Region):
  #   1. region+cc_id (Player.cc_id ist NICHT global unique — Memory project_cc_id_not_unique)
  #   2. dbu_nr (cross-region; DBU-Mitgliedschaft global eindeutig)
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
      match_by_region_cc_id(attrs[:cc_id]) ||
        match_by_dbu_nr(attrs[:dbu_nr]) ||
        match_by_name_and_club(attrs)
    end

    private

    # Path 1: region+cc_id (cc_id region-scoped da NICHT global unique)
    def match_by_region_cc_id(cc_id)
      return nil if cc_id.blank?
      Player.where(region_id: @region.id, cc_id: cc_id.to_i).first
    end

    # Path 2: dbu_nr (cross-region; DBU-Mitgliedschaft ist national eindeutig)
    def match_by_dbu_nr(dbu_nr)
      return nil if dbu_nr.blank?
      Player.find_by(dbu_nr: dbu_nr.to_i)
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
