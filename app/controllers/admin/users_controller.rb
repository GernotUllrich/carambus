module Admin
  class UsersController < Admin::ApplicationController
    # Phase 37-01: Administrate-Controller erben NICHT vom App-ApplicationController →
    # App-Helper sind im View-Kontext nicht automatisch verfuegbar. Explizit einbinden.
    helper Admin::UserFormHelper

    # Overwrite any of the RESTful controller actions to implement custom behavior
    # For example, you may want to send an email after a foo is updated.
    #
    # def update
    #   super
    #   send_foo_updated_email(requested_resource)
    # end

    # Override this method to specify custom lookup behavior.
    # This will be used to set the resource for the `show`, `edit`, and `update`
    # actions.
    #
    # def find_resource(param)
    #   Foo.find_by!(slug: param)
    # end

    # The result of this lookup will be available as `requested_resource`

    # Override this if you have certain roles that require a subset
    # this will be used to set the records shown on the `index` action.
    #
    # def scoped_resource
    #   if current_user&.super_admin?
    #     resource_class
    #   else
    #     resource_class.with_less_stuff
    #   end
    # end
    def update
      super
    end

    # Phase 37-01: JSON-Endpoint fuer den gestaffelten Player-Selektor im User-Formular.
    # Liefert die Spieler eines Clubs der AKTUELLEN Saison (SeasonParticipation).
    # ⚠️ Admin::ApplicationController#authenticate_admin ist aktuell ein No-Op → eigene
    # system_admin?-Pruefung Pflicht (kein ungeschuetzter Spieler-Listen-Leak).
    def players_by_club
      return head :forbidden unless current_user&.system_admin?

      club_id = params[:club_id]
      return render(json: []) if club_id.blank?

      season = Season.current_season
      rows = SeasonParticipation
        .where(club_id: club_id, season_id: season&.id)
        .includes(:player)
        .map { |sp| {id: sp.player_id, label: sp.player&.fullname} }
        .reject { |h| h[:id].nil? || h[:label].blank? }
        .uniq { |h| h[:id] }
        .sort_by { |h| h[:label].to_s }

      render json: rows
    end

    # 2026-06-20: Vereine einer Region — fuer die vorgeschaltete Region-Stufe der Player-Cascade
    # auf Servern OHNE festen Region-Context (carambus.de, Authority). Sonst ist die Region fix
    # (Carambus.config.context) und region_clubs rendert die Vereine direkt.
    def clubs_by_region
      return head :forbidden unless current_user&.system_admin?

      region_id = params[:region_id]
      return render(json: []) if region_id.blank?

      rows = Club.where(region_id: region_id).where.not(name: [nil, ""])
        .order(:name)
        .map { |c| {id: c.id, label: c.name} }

      render json: rows
    end

    # 2026-06-20: Spielorte einer Region, nach Verein gruppiert — fuer die vorgeschaltete
    # Region-Stufe der Sportwart-Spielort-Auswahl auf Servern OHNE festen Region-Context.
    # Spiegelt UserFormHelper#region_locations_grouped_options fuer eine beliebige region_id.
    def locations_by_region
      return head :forbidden unless current_user&.system_admin?

      region = Region.find_by(id: params[:region_id])
      return render(json: []) unless region

      groups = region.clubs.where.not(name: [nil, ""]).order(:name).map { |club|
        locs = club.locations.order(:name).map { |l| {id: l.id, name: l.name} }
        {club: club.name, locations: locs}
      }.reject { |g| g[:locations].empty? }

      render json: groups
    end

    # Override `resource_params` if you want to transform the submitted
    # data before it's persisted. For example, the following would turn all
    # empty values into nil values. It uses other APIs such as `resource_class`
    # and `dashboard`:
    #
    # def resource_params
    #   params.require(resource_class.model_name.param_key).
    #     permit(dashboard.permitted_attributes(action_name)).
    #     transform_values { |value| value == "" ? nil : value }
    # end

    # See https://administrate-demo.herokuapp.com/customizing_controller_actions
    # for more information
  end
end
