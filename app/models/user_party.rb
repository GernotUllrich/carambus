# frozen_string_literal: true

# Plan 20-02: Lokale, ApiProtector-geschuetzte Relation User x Party — der Begegnungsleiter.
# Vorbild UserTournament (Turnierleiter): der zustaendige Sportwart setzt ihn ein
# (PartyPolicy#assign_leiter?), granted_by haelt fest, wer.
class UserParty < ApplicationRecord
  include ApiProtector

  ROLES = %w[party_leiter].freeze

  belongs_to :user
  belongs_to :party
  belongs_to :granted_by, class_name: "User", foreign_key: :granted_by_user_id, optional: true

  validates :role, inclusion: {in: ROLES}
  validates :user_id, uniqueness: {scope: [:party_id, :role]}
end
