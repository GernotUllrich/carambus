# frozen_string_literal: true

# == Schema Information
#
# Table name: season_participations
#
#  id         :bigint           not null, primary key
#  data       :text
#  source_url :string
#  status     :string
#  sync_date  :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  ba_id      :integer
#  club_id    :integer
#  player_id  :integer
#  season_id  :integer
#
# Indexes
#
#  index_season_participations_on_foreign_keys  (player_id,club_id,season_id) UNIQUE
#
class SeasonParticipation < ApplicationRecord
  include LocalProtector
  include RegionTaggable
  belongs_to :season
  belongs_to :player
  belongs_to :club

  REFLECTION_KEYS = %w[season player club].freeze
  COLUMN_NAMES = {
    "Season" => "seasons.name",
    "Name" => "players.lastname||', '||players.firstname",
    "Club" => "clubs.shortname",
    "Region" => "regions.shortname"
  }.freeze
  def self.search_hash(params)
    {
      model: SeasonParticipation,
      sort: params[:sort],
      direction: sort_direction(params[:direction]),
      search: [params[:sSearch], params[:search]].compact.join("&").to_s,
      column_names: SeasonParticipation::COLUMN_NAMES,
      raw_sql: "(players.lastname ilike :search)
or (players.nickname ilike :search)
or (players.firstname ilike :search)
or (clubs.name ilike :search)
or (clubs.shortname ilike :search)
or (seasons.name ilike :search)",
      joins: %i[season player club]
    }
  end
  # status:
  # "active" member
  # "passive" Membership
  # "guest" Player
end
