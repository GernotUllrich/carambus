# == Schema Information
#
# Table name: leagues
#
#  id                 :bigint           not null, primary key
#  ba_id2             :integer
#  name               :string
#  organizer_type     :string
#  registration_until :date
#  shortname          :string
#  staffel_text       :string
#  type               :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  ba_id              :integer
#  cc_id              :integer
#  discipline_id      :integer
#  organizer_id       :integer
#  season_id          :integer
#
# Indexes
#
#  index_leagues_on_ba_id_and_ba_id2  (ba_id,ba_id2) UNIQUE
#
require 'test_helper'

class LeagueTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
