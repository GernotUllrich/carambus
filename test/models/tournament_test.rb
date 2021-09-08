# == Schema Information
#
# Table name: tournaments
#
#  id                             :bigint           not null, primary key
#  accredation_end                :datetime
#  admin_controlled               :boolean          default(FALSE), not null
#  age_restriction                :string
#  ba_state                       :string
#  balls_goal                     :integer
#  data                           :text
#  date                           :datetime
#  end_date                       :datetime
#  handicap_tournier              :boolean
#  innings_goal                   :integer
#  last_ba_sync_date              :datetime
#  location                       :text
#  manual_assignment              :boolean          default(FALSE)
#  modus                          :string
#  organizer_type                 :string
#  plan_or_show                   :string
#  player_class                   :string
#  shortname                      :string
#  single_or_league               :string
#  state                          :string
#  time_out_warm_up_first_min     :integer          default(5)
#  time_out_warm_up_follow_up_min :integer          default(3)
#  timeout                        :integer          default(45)
#  timeouts                       :integer          default(0), not null
#  title                          :string
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  ba_id                          :integer
#  discipline_id                  :integer
#  location_id                    :integer
#  organizer_id                   :integer
#  region_id                      :integer
#  season_id                      :integer
#  tournament_plan_id             :integer
#
# Indexes
#
#  index_tournaments_on_ba_id         (ba_id) UNIQUE
#  index_tournaments_on_foreign_keys  (title,season_id,region_id)
#
require 'test_helper'

class TournamentTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
