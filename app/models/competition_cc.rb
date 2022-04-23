# == Schema Information
#
# Table name: competition_ccs
#
#  id            :bigint           not null, primary key
#  context       :string
#  name          :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  branch_cc_id  :integer
#  cc_id         :integer
#  discipline_id :integer
#
class CompetitionCc < ApplicationRecord
  belongs_to :branch_cc
  belongs_to :discipline
end
