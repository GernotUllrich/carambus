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
  include LocalProtector
  has_many :competition_ccs
  has_many :game_plan_ccs
  has_many :group_ccs
  has_many :registration_list_ccs
  belongs_to :discipline
  has_many :discipline_ccs
  belongs_to :region_cc
  has_many :category_ccs
  has_many :championship_type_ccs
  delegate :fedId, to: :region_cc
  alias_attribute :branchId, :cc_id
end
