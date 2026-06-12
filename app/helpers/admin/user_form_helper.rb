# frozen_string_literal: true

module Admin
  # Phase 37-01: Helfer fuers Admin-User-Formular (Sportwart-Persona-Setup).
  # Region wird IMMER aus Carambus.config.context (carambus.yml) abgeleitet — region-agnostisch
  # (nbv->NBV, bcw->..., phat->...), KEIN hartes "NBV".
  module UserFormHelper
    # Server-Region aus der Scenario-Config (Carambus.config.context). nil wenn nicht gesetzt.
    def server_region
      ctx = (Carambus.config.context.to_s if Carambus.config.respond_to?(:context))
      return nil if ctx.blank?
      Region.find_by("UPPER(shortname) = ?", ctx.upcase)
    rescue
      nil
    end

    # Die 4 Branch-Wurzeln (STI-Subklassen von Discipline: Pool/Snooker/Karambol/Kegel), alphabetisch.
    # Kinder werden im rekursiven Partial via discipline.sub_disciplines geholt.
    def discipline_tree_roots
      Branch.order(:name)
    end

    # Clubs der Server-Region (fuer den Club-Select der Player-Cascade).
    def region_clubs
      server_region&.clubs&.order(:name)&.to_a || []
    end

    # Locations der Server-Region, gruppiert nach Club — fuer grouped_options_for_select:
    #   [[club_name, [[location_name, location_id], ...]], ...]
    # Eine Location kann (M:N) mehreren Clubs gehoeren und so unter mehreren Gruppen auftauchen — ok.
    def region_locations_grouped_options
      region_clubs.map { |club|
        locs = club.locations.order(:name).map { |l| [l.name, l.id] }
        [club.name, locs]
      }.reject { |_name, locs| locs.empty? }
    end
  end
end
