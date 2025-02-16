# == Schema Information
#
# Table name: championship_type_ccs
#
#  id           :bigint           not null, primary key
#  context      :string
#  name         :string
#  shortname    :string
#  status       :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  branch_cc_id :integer
#  cc_id        :integer
#
class ChampionshipTypeCc < ApplicationRecord
  include LocalProtector
  belongs_to :branch_cc
end
