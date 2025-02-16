# == Schema Information
#
# Table name: tournament_series_ccs
#
#  id               :bigint           not null, primary key
#  currency         :string
#  data             :text
#  jackpot          :decimal(9, 2)
#  min_points       :integer
#  name             :string
#  no_tournaments   :integer
#  point_formula    :string
#  point_fraction   :integer
#  price_money      :decimal(9, 2)
#  season           :string
#  series_valuation :integer
#  show_jackpot     :integer
#  status           :string
#  valuation        :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  branch_cc_id     :integer
#  cc_id            :integer
#  club_id          :string
#
class TournamentSeriesCc < ApplicationRecord
  include LocalProtector
  has_many :tournament_ccs
end
