require "administrate/base_dashboard"

# Phase 37-03: Admin-UI fuer Turnierleiter-Zuordnungen (UserTournament, role "turnier_leiter").
# Local-Server-Aufgabe (ApiProtector). `tournament` ist nur fuers Form-Permitting als BelongsTo
# gelistet; angezeigt wird `tournament_label` (String) -> KEIN TournamentDashboard noetig
# (das existiert nicht und wuerde die Show/Index-Seite 500en, vgl. LocationDashboard-Fall).
class UserTournamentDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    user: Field::BelongsTo,
    tournament: Field::BelongsTo,
    tournament_label: Field::String,
    role: Field::Select.with_options(collection: UserTournament::ROLES),
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[id user tournament_label role].freeze
  SHOW_PAGE_ATTRIBUTES = %i[id user tournament_label role created_at updated_at].freeze
  FORM_ATTRIBUTES = %i[user tournament role].freeze
  COLLECTION_FILTERS = {}.freeze

  def display_resource(user_tournament)
    "#{user_tournament.user&.email} – #{user_tournament.tournament_label} (#{user_tournament.role})"
  end
end
