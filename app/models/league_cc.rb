# == Schema Information
#
# Table name: league_ccs
#
#  id           :bigint           not null, primary key
#  context      :string
#  name         :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  cc_id        :integer
#  season_cc_id :integer
#
class LeagueCc < ApplicationRecord
  belongs_to :season_cc
  belongs_to :league
end
