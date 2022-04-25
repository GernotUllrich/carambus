# == Schema Information
#
# Table name: league_ccs
#
#  id               :bigint           not null, primary key
#  context          :string
#  name             :string
#  report_form      :string
#  report_form_data :string
#  shortname        :string
#  status           :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  cc_id            :integer
#  league_id        :integer
#  season_cc_id     :integer
#
class LeagueCc < ApplicationRecord
  belongs_to :season_cc
  belongs_to :league

  def self.create_from_ba(league)
    raise NotImplementedError, "league creation not yet implemented", caller
  end
end
