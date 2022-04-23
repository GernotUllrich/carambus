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
class BranchCc < ApplicationRecord
end
