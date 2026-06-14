# frozen_string_literal: true

# D-34-5 (v1.0): Lokale, ApiProtector-geschuetzte Relation User x Tournament.
# Heimat fuer User<->Turnier-Zuordnungen auf dem Local-Server (Persona-/TL-Management).
# Vorbild: SportwartLocation/SportwartDiscipline (lokales Konzept, IDs >= Seeding::MIN_ID,
# auf der Authority via ApiProtector geblockt). Generisch via role-Spalte;
# v1.0 nutzt nur role "turnier_leiter".
#
# "Ist-TL?" ist UNION aus dieser Relation UND dem globalen Tournament.turnier_leiter_user_id
# (siehe UserPersonas#turnierleiter? + TournamentLeiter#leiter?).
class UserTournament < ApplicationRecord
  include ApiProtector

  ROLES = %w[turnier_leiter].freeze

  belongs_to :user
  belongs_to :tournament

  # D-39-3 (v1.1): Welcher Sportwart hat diesen TL eingesetzt? Quelle der CC-Credential-Vererbung
  # (TL ohne eigenen CC-Account erbt turnierspezifisch die Creds des einsetzenden Sportwarts).
  # optional: Legacy-Records + der globale turnier_leiter_user_id-Pfad haben keinen granter.
  # Spaltenname granted_by_user_id konsistent mit Tournament.turnier_leiter_user_id.
  belongs_to :granted_by, class_name: "User", foreign_key: :granted_by_user_id, optional: true

  validates :role, inclusion: {in: ROLES}
  validates :user_id, uniqueness: {scope: [:tournament_id, :role]}

  # Anzeige-Label fuers Admin-Dashboard (Collection/Show). Bewusst als String-Feld
  # statt tournament-BelongsTo, damit KEIN TournamentDashboard noetig ist (sonst 500).
  def tournament_label
    return "" unless tournament

    [tournament.title.presence, tournament.date&.strftime("%d.%m.%Y")].compact.join(" – ")
  end
end
