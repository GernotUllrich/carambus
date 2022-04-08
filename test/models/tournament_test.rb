# == Schema Information
#
# Table name: tournaments
#
#  id                             :bigint           not null, primary key
#  accredation_end                :datetime
#  admin_controlled               :boolean          default(FALSE), not null
#  age_restriction                :string
#  allow_follow_up                :boolean          default(TRUE), not null
#  ba_state                       :string
#  balls_goal                     :integer
#  color_remains_with_set         :boolean          default(TRUE), not null
#  data                           :text
#  date                           :datetime
#  end_date                       :datetime
#  fixed_display_left             :string
#  gd_has_prio                    :boolean          default(FALSE), not null
#  handicap_tournier              :boolean
#  innings_goal                   :integer
#  kickoff_switches_with_set      :boolean          default(TRUE), not null
#  last_ba_sync_date              :datetime
#  location                       :text
#  manual_assignment              :boolean          default(FALSE)
#  modus                          :string
#  organizer_type                 :string
#  plan_or_show                   :string
#  player_class                   :string
#  sets_to_play                   :integer          default(1), not null
#  sets_to_win                    :integer          default(1), not null
#  shortname                      :string
#  single_or_league               :string
#  state                          :string
#  team_size                      :integer          default(1), not null
#  time_out_warm_up_first_min     :integer          default(5)
#  time_out_warm_up_follow_up_min :integer          default(3)
#  timeout                        :integer          default(45)
#  timeouts                       :integer          default(0), not null
#  title                          :string
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  ba_id                          :integer
#  discipline_id                  :integer
#  league_id                      :integer
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
