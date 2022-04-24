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
  belongs_to :discipline
  belongs_to :region_cc
end
