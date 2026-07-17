# frozen_string_literal: true

module Admin
  # Phase 37-03: Turnierleiter-Zuordnungen (UserTournament) im Admin verwalten.
  # Erbt Administrate-CRUD (index/show/new/create/destroy).
  #
  # ⚠️ Admin::ApplicationController#authenticate_admin ist aktuell ein No-Op ->
  # eigene system_admin?-Pruefung Pflicht (sonst koennte jeder authentifizierte
  # User TL-Zuordnungen anlegen/loeschen).
  # ⚠️ Administrate erbt NICHT vom App-ApplicationController -> Helper-Auto-Include
  # greift nicht -> UserTournamentFormHelper explizit einbinden (sonst undefined im Form).
  class UserTournamentsController < Admin::ApplicationController
    before_action :require_system_admin
    helper Admin::UserTournamentFormHelper

    private

    def require_system_admin
      head :forbidden unless current_user&.system_admin?
    end
  end
end
