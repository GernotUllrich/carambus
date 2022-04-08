# == Schema Information
#
# Table name: tournament_locals
#
#  id                        :bigint           not null, primary key
#  admin_controlled          :boolean
#  allow_follow_up           :boolean          default(TRUE), not null
#  color_remains_with_set    :boolean          default(TRUE), not null
#  fixed_display_left        :string
#  gd_has_prio               :boolean
#  kickoff_switches_with_set :boolean          default(TRUE), not null
#  sets_to_play              :integer          default(1), not null
#  sets_to_win               :integer          default(1), not null
#  team_size                 :integer          default(1), not null
#  timeout                   :integer
#  timeouts                  :integer
#  tournament_id             :integer
#
class TournamentLocal < ApplicationRecord
  belongs_to :tournament
end
