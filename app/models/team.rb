# == Schema Information
#
# Table name: players
#
#  id            :bigint           not null, primary key
#  data          :text
#  dbu_nr        :integer
#  dbu_pass_nr   :integer
#  firstname     :string
#  fl_name       :string
#  guest         :boolean          default(FALSE), not null
#  lastname      :string
#  nickname      :string
#  nrw_nr        :integer
#  pin4          :string
#  source_url    :string
#  sync_date     :datetime
#  title         :string
#  type          :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  ba_id         :integer
#  cc_id         :integer
#  club_id       :integer
#  tournament_id :integer
#
# Indexes
#
#  index_players_on_ba_id    (ba_id) UNIQUE
#  index_players_on_club_id  (club_id)
#
class Team < Player
  belongs_to :tournament, optional: true
  before_save :order_players

  # for teams:
  #  data ordered by ba_id  then first player's data are copied into resp. fields of player record
  # data:

  def deep_merge_data!(hash)
    h = data.dup
    h.deep_merge!(hash)
    data_will_change!
    self.data = JSON.parse(h.to_json)
    # save!
  end

  def order_players
    if data["players"].present?
      data["players"]&.sort_by! { |h| h["ba_id]"] }
      self.firstname = data["players"][0]["firstname"]
      self.lastname = data["players"][0]["lastname"]
    else
      data["players"] = []
    end
  end

  def fullname
    data["players"]&.map { |h| h["lastname"] }&.join(" | ")
  end
end
