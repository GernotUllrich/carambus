# frozen_string_literal: true

module Admin
  # Pflege der lokalen Kontaktdaten. Der Zugriffsschutz kommt aus
  # `Admin::ApplicationController` (nur `system_admin?`).
  class PlayerLocalsController < Admin::ApplicationController
    # Nach Spielername sortiert statt nach id — die Liste wird gelesen, nicht durchnummeriert.
    def scoped_resource
      PlayerLocal.joins(:player).order(Player.sort_key_sql)
    end

    # Nach dem Speichern zurueck zur Liste statt auf die Detailseite (Betreiber-Abnahme
    # 2026-08-30, Plan 02.1-01).
    #
    # ⚠️ Administrate leitet von Haus aus auf die SHOW-Seite. Das passt hier nicht: die
    # Kontaktdaten werden reihenweise gepflegt — man legt einen Datensatz an und will zum
    # naechsten Mitglied, nicht auf eine Detailseite, die ohnehin nur dasselbe zeigt.
    # Dieselbe Linie wie beim `destroy` in Admin::TrainingConceptsController.
    def after_resource_created_path(_requested_resource)
      admin_player_locals_path
    end

    def after_resource_updated_path(_requested_resource)
      admin_player_locals_path
    end
  end
end
