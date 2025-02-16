# == Schema Information
#
# Table name: leagues
#
#  id                 :bigint           not null, primary key
#  ba_id2             :integer
#  cc_id2             :integer
#  game_parameters    :text
#  game_plan_locked   :boolean          default(FALSE), not null
#  name               :string
#  organizer_type     :string
#  registration_until :date
#  shortname          :string
#  source_url         :string
#  staffel_text       :string
#  sync_date          :datetime
#  type               :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  ba_id              :integer
#  cc_id              :integer
#  discipline_id      :integer
#  game_plan_id       :integer
#  organizer_id       :integer
#  season_id          :integer
#
# Indexes
#
#  index_leagues_on_ba_id_and_ba_id2  (ba_id,ba_id2) UNIQUE
#
class Staffel < League
end
