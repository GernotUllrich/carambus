# frozen_string_literal: true

# D-14-G4: Single-TL-pro-Turnier Sub-Authorization-Mechanismus.
#
# Gemixt in Tournament. Stellt zwei Prädikate bereit:
# - `leiter?(user)` — Identitäts-Check für TL-Authority (TournamentPolicy nutzt das)
# - `has_active_leiter?` — Prädikat für „diesem Turnier ist ein TL zugewiesen"
module TournamentLeiter
  extend ActiveSupport::Concern

  def leiter?(user)
    return false if user.nil?
    turnier_leiter_user_id.present? && turnier_leiter_user_id == user.id
  end

  def has_active_leiter?
    turnier_leiter_user_id.present?
  end
end
