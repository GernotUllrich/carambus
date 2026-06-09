# frozen_string_literal: true

module ExternalTournament
  # Plan 17-06 (Vision C/D): Batch-Player-Reconcile gegen Carambus-lokal.
  #
  # Duenner Wrapper um PlayerMatcher (D-17-vision-2 / D-17-06-C): die App schickt ihre
  # Teilnehmerliste, Carambus matcht region-scoped (region+cc_id -> dbu_nr -> name+club)
  # und gibt pro Eintrag die dbu_nr + den kanonischen Carambus-Datensatz zurueck.
  # Legt KEINE Player an (kein find_or_create) — nicht-matchbare Eintraege => matched:false.
  #
  # @example
  #   ExternalTournament::PlayerReconciler.new(region: Region.find_by(shortname: "NBV"))
  #     .call(participants: [{ref: "t1p1", cc_id: 9001, firstname: "Dick", lastname: "Jaspers"}])
  #   # => [{ref: "t1p1", matched: true, player: {id:, cc_id:, dbu_nr:, firstname:, lastname:, club:}}]
  class PlayerReconciler
    def initialize(region:)
      @region = region
      @matcher = PlayerMatcher.new(region: region)
    end

    # @param participants [Array<Hash>] je Eintrag {ref?, cc_id?, dbu_nr?, firstname?, lastname?, club_cc_id?}
    # @return [Array<Hash>] je Eintrag {ref, matched, player|nil}
    def call(participants:)
      Array(participants).map do |p|
        attrs = p.is_a?(Hash) ? p.symbolize_keys : {}
        player = @matcher.match(attrs)
        {
          ref: attrs[:ref],
          matched: player.present?,
          player: serialize(player)
        }
      end
    end

    private

    def serialize(player)
      return nil unless player
      club = player.clubs.first
      {
        id: player.id,
        cc_id: player.cc_id,
        dbu_nr: player.dbu_nr&.to_s,
        firstname: player.firstname,
        lastname: player.lastname,
        club: club ? {cc_id: club.cc_id, shortname: club.shortname} : nil
      }
    end
  end
end
