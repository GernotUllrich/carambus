# frozen_string_literal: true

module Admin
  # Pflege der lokalen Kontaktdaten. Der Zugriffsschutz kommt aus
  # `Admin::ApplicationController` (nur `system_admin?`).
  class PlayerLocalsController < Admin::ApplicationController
    # Nach Spielername sortiert statt nach id — die Liste wird gelesen, nicht durchnummeriert.
    def scoped_resource
      PlayerLocal.joins(:player).order(Player.sort_key_sql)
    end
  end
end
