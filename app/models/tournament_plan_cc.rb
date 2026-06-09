# frozen_string_literal: true

# == Schema Information
#
# Table name: tournament_plan_ccs
#
#  id         :bigint           not null, primary key
#  context    :string
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  cc_id      :integer
#
# Indexes
#
#  index_tournament_plan_ccs_on_context_and_cc_id  (context,cc_id)
#  index_tournament_plan_ccs_on_context_and_name   (context,name)
#

# Phase 21-03 (Slice A): CC-Schicht für ClubCloud-„Turnierpläne".
#
# Analog ChampionshipTypeCc/CategoryCc/GroupCc: flaches Modell (cc_id, name, context),
# region-scoped via `context`-String (kein region_id-FK, konsistent mit anderen *Cc-Modellen).
#
# Globales Modell (id < Carambus.MIN_ID auf Authority-Server intendiert; LocalProtector
# blockt versehentliche Writes auf Local-Servern).
#
# Lookup-Pattern für Syncer (T3):
#   - wenn cc_id bekannt:  find_or_initialize_by(cc_id:, context:)
#   - sonst name-basiert:  find_or_initialize_by(name:, context:)
#
# KEIN FK zum globalen `TournamentPlan`-Modell (D-21-03-DISC-B: pure CC-Sicht;
# Mapping zu TournamentPlan ist eine view-time-Heuristik, kein DB-Constraint).
class TournamentPlanCc < ApplicationRecord
  include LocalProtector

  has_many :tournament_ccs, dependent: :nullify

  validates :name, presence: true
end
