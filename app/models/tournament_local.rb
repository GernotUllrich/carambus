# == Schema Information
#
# Table name: tournament_locals
#
#  id               :bigint           not null, primary key
#  admin_controlled :boolean
#  gd_has_prio      :boolean
#  timeout          :integer
#  timeouts         :integer
#  tournament_id    :integer
#
class TournamentLocal < ApplicationRecord
  belongs_to :tournament
end
