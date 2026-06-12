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

  validates :role, inclusion: {in: ROLES}
  validates :user_id, uniqueness: {scope: [:tournament_id, :role]}
end
