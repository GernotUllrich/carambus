# frozen_string_literal: true

module McpServer
  # Plan 39-02 (D-39-2 / D-39-3 / D-39-6): Klassifiziert die effektive CC-Identität für einen
  # Tool-Call. REINE DB-/Modell-Logik — KEINE CC-/HTTP-Calls (unit-testbar ohne ClubCloud).
  #
  # Auflösungskette:
  #   1. User hat eigene CC-Creds (cc_credentials_present?)                      → :own
  #   2. sonst: User ist TL für DIESES Turnier via UserTournament(role:
  #      "turnier_leiter") UND dessen granted_by hat eigene Creds                → :tl_inherited
  #      (erbt turnierspezifisch die Creds des einsetzenden Sportwarts, D-39-3)
  #   3. sonst                                                                   → :none
  #      (D-39-6: KEIN shared_fallback. Deckt ab: Granter ohne Creds, Legacy-
  #       UserTournament ohne granted_by, nur globaler turnier_leiter_user_id,
  #       User ohne CC-Account. Der harte Block erfolgt in 39-03.)
  #       KEINE fuzzy Sportwart-via-Scope-Ableitung (deterministisch, billiger).
  #
  # Der CcSession-Cache-Key ist login_username (der CC-Account, dem die PHPSESSID gehört) —
  # zwei TL desselben Granters teilen damit eine Session. acting_user_id / granted_by_user_id
  # tragen die zweischichtige Audit-Info (CC kennt nur den Login-Account; Carambus den echten
  # Akteur). Die AuditTrail-/Tool-Verdrahtung ist 39-03.
  module CcAccountResolver
    # Kleines Value-Objekt. ACHTUNG: `password` NUR durchreichen — NIE loggen/inspecten.
    CcAccount = Struct.new(:login_username, :password, :source, :acting_user_id, :granted_by_user_id, keyword_init: true) do
      def resolved?
        source != :none
      end
    end

    module_function

    # user: das handelnde Carambus-User-Objekt (Caller löst es aus server_context[:user_id], D-39-7).
    # tournament: das Ziel-Tournament (für die TL-Vererbung); nil → nur :own/:none möglich.
    def resolve(user:, tournament: nil)
      return none(nil) if user.nil?

      if user.cc_credentials_present?
        return CcAccount.new(
          login_username: user.cc_username,
          password: user.cc_password,
          source: :own,
          acting_user_id: user.id
        )
      end

      if tournament
        ut = UserTournament.find_by(user_id: user.id, tournament_id: tournament.id, role: "turnier_leiter")
        granter = ut&.granted_by
        if granter&.cc_credentials_present?
          return CcAccount.new(
            login_username: granter.cc_username,
            password: granter.cc_password,
            source: :tl_inherited,
            acting_user_id: user.id,
            granted_by_user_id: granter.id
          )
        end
      end

      none(user)
    rescue => e
      Rails.logger.warn "[CcAccountResolver.resolve] #{e.class}: #{e.message}"
      none(user)
    end

    # :none-Account (resolved? == false). acting_user_id für die spätere Audit-Schicht erhalten.
    def none(user)
      CcAccount.new(source: :none, acting_user_id: user&.id)
    end
  end
end
