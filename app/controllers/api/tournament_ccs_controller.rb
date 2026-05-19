# frozen_string_literal: true

module Api
  # Plan 14-G.14: Regional→API registration_list_link-Push (devise-jwt-authentifiziert)
  #
  # Erlaubt Regional-MCP-Server (carambus_nbv, carambus_bvbw, ...) admin-sourced
  # meldeliste_cc_id↔tournament_cc_id-Verknüpfungen in die zentrale Carambus-API
  # zurückzuspielen, ohne LocalProtector zu verletzen.
  #
  # Auth: devise-jwt (Bearer-Token aus POST /login eines Service-Account-Users
  # wie nbv-syncer@carambus.de; angelegt via `rake service_accounts:create[NBV]`).
  class TournamentCcsController < ApplicationController
    before_action :authenticate_user!
    skip_forgery_protection

    # PATCH /api/tournament_ccs/:id/registration_list_link
    #
    # Body (JSON):
    #   {
    #     "registration_list_link": {
    #       "meldeliste_cc_id": 1310,
    #       "registration_list_name": "NDM Endrunde Eurokegel",
    #       "region_shortname": "NBV",
    #       "branch_cc_id": 8,
    #       "season": "2025/2026",
    #       "discipline_id": 58,
    #       "category_cc_id": null
    #     }
    #   }
    #
    # Response (200):
    #   {
    #     "tournament_cc": { ... },
    #     "registration_list_cc": { ... },
    #     "version_id": 12345
    #   }
    #
    # Errors:
    #   - 401 — fehlende/ungültige/revoked JWT
    #   - 404 — tournament_cc_id existiert nicht
    #   - 422 — region_shortname passt nicht zur Tournament-Region, oder ungültige Params
    def link_registration_list
      tournament_cc = TournamentCc.find(params[:id])
      region = Region.find_by!(shortname: link_params[:region_shortname].to_s.upcase)

      # Region-Scope-Validation: Tournament muss zur ge-pushten Region passen
      if tournament_cc.tournament&.region_id != region.id
        return render json: {error: "Region mismatch"}, status: :unprocessable_entity
      end

      ActiveRecord::Base.transaction do
        season = Season.find_by(name: link_params[:season]) if link_params[:season].present?

        registration_list_cc = RegistrationListCc.find_or_create_by!(
          cc_id: link_params[:meldeliste_cc_id],
          context: region.shortname.downcase
        ) do |r|
          r.name = link_params[:registration_list_name]
          r.branch_cc_id = link_params[:branch_cc_id]
          r.season_id = season&.id
          r.discipline_id = link_params[:discipline_id]
          r.category_cc_id = link_params[:category_cc_id]
        end

        tournament_cc.update!(registration_list_cc_id: registration_list_cc.id)

        render json: {
          tournament_cc: tournament_cc.as_json,
          registration_list_cc: registration_list_cc.as_json,
          version_id: PaperTrail::Version.maximum(:id)
        }
      end
    rescue ActiveRecord::RecordNotFound => e
      render json: {error: e.message}, status: :not_found
    rescue ActiveRecord::RecordInvalid => e
      render json: {error: e.message}, status: :unprocessable_entity
    end

    private

    def link_params
      params.require(:registration_list_link).permit(
        :meldeliste_cc_id, :registration_list_name, :region_shortname,
        :branch_cc_id, :season, :discipline_id, :category_cc_id
      )
    end
  end
end
