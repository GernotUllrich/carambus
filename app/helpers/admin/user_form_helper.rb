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
    # Vereine OHNE Namen ausschliessen: der Mirror enthaelt leere Stub-Records
    # (kein name/shortname/cc_id; ~30 in NBV), die via order(:name) vor die echten
    # sortieren und im Dropdown als Leerzeilen erscheinen. Sie haben keine Spielorte
    # (verifiziert) → der Location-Select bleibt unberuehrt.
    def region_clubs
      return [] unless server_region
      server_region.clubs.where.not(name: [nil, ""]).order(:name).to_a
    end

    # 2026-06-20: Region-Auswahloptionen fuer Server OHNE festen Region-Context (carambus.de,
    # Authority). Nur Regionen MIT benannten Vereinen (sonst leere/irrelevante Eintraege).
    #   [["NBV – Niedersächsischer Billard-Verband", id], ...]
    def region_picker_options
      Region.where(id: Club.where.not(name: [nil, ""]).select(:region_id))
        .where.not(shortname: [nil, ""])
        .order(:shortname)
        .map { |r| [[r.shortname, r.name].reject(&:blank?).join(" – "), r.id] }
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
