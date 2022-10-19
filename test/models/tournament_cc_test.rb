# == Schema Information
#
# Table name: tournament_ccs
#
#  id                      :bigint           not null, primary key
#  context                 :string
#  description             :text
#  entry_fee               :decimal(6, 2)
#  flowchart               :string
#  league_climber_quote    :integer
#  location_text           :string
#  max_players             :integer
#  name                    :string
#  poster                  :string
#  ranking_list            :string
#  registration_rule       :integer
#  season                  :string
#  shortname               :string
#  starting_at             :time
#  status                  :string
#  successor_list          :string
#  tender                  :string
#  tournament_end          :datetime
#  tournament_start        :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  branch_cc_id            :integer
#  category_cc_id          :integer
#  cc_id                   :integer
#  championship_type_cc_id :integer
#  discipline_id           :integer
#  group_cc_id             :integer
#  location_id             :integer
#  registration_list_cc_id :integer
#  tournament_id           :integer
#  tournament_series_cc_id :integer
#
require "test_helper"

class TournamentCcTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
