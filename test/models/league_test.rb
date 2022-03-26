# == Schema Information
#
# Table name: leagues
#
#  id                 :bigint           not null, primary key
#  ba_id2             :integer
#  name               :string
#  organizer_type     :string
#  registration_until :date
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  ba_id              :integer
#  discipline_id      :integer
#  organizer_id       :integer
#  season_id          :integer
#
require 'test_helper'

class LeagueTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
