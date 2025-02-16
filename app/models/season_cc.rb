# == Schema Information
#
# Table name: season_ccs
#
#  id                :bigint           not null, primary key
#  context           :string
#  name              :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  cc_id             :integer
#  competition_cc_id :integer
#  season_id         :integer
#
# Indexes
#
#  index_season_ccs_on_competition_cc_id_and_cc_id_and_context  (competition_cc_id,cc_id,context) UNIQUE
#
class SeasonCc < ApplicationRecord
  include LocalProtector

  belongs_to :competition_cc
  belongs_to :season
  has_many :league_ccs
  has_many :registration_list_ccs

  delegate :fedId, :branchId, :subBranchId, :region_cc, :branch_cc, to: :competition_cc
  alias_attribute :seasonId, :cc_id

  before_save :set_paper_trail_whodunnit
end
