# == Schema Information
#
# Table name: branch_ccs
#
#  id            :bigint           not null, primary key
#  context       :string
#  name          :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  cc_id         :integer
#  discipline_id :integer
#  region_cc_id  :integer
#
# Indexes
#
#  index_branch_ccs_on_region_cc_id_and_cc_id_and_context  (region_cc_id,cc_id,context) UNIQUE
#
class BranchCc < ApplicationRecord
  has_many :competition_ccs
  has_many :game_plan_ccs
  belongs_to :discipline
  belongs_to :region_cc
  delegate :fedId, to: :region_cc
  alias_attribute :branchId, :cc_id
  has_paper_trail
  before_save :set_paper_trail_whodunnit
end
