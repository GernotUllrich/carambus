# frozen_string_literal: true

module Admin
  # Phase 37-03: Helfer fuers UserTournament-Admin-Formular (TL-Zuordnung).
  # Region wird aus Carambus.config.context abgeleitet (region-agnostisch, kein hartes "NBV").
  module UserTournamentFormHelper
    # Wenige User -> einfaches Dropdown.
    def assignable_users
      User.order(:email)
    end

    # Turniere der AKTUELLEN Saison in der Server-Region (handhabbare Liste statt aller ~2300),
    # als [label, id]-Paare fuer options_for_select. Faellt auf Saison-only zurueck, wenn keine Region.
    def assignable_tournaments
      scope = Tournament.where(season_id: Season.current_season&.id)
      reg = tl_server_region
      scope = scope.where(region_id: reg.id) if reg
      scope.order(date: :desc).map { |t| [tl_tournament_label(t), t.id] }
    end

    def tl_tournament_label(tournament)
      [tournament.title.presence, tournament.date&.strftime("%d.%m.%Y")].compact.join(" – ")
    end

    def tl_server_region
      ctx = (Carambus.config.context.to_s if Carambus.config.respond_to?(:context))
      return nil if ctx.blank?
      Region.find_by("UPPER(shortname) = ?", ctx.upcase)
    rescue
      nil
    end
  end
end
