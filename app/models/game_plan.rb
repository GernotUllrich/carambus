# == Schema Information
#
# Table name: game_plans
#
#  id         :bigint           not null, primary key
#  data       :text
#  footprint  :string
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class GamePlan < ApplicationRecord
  include LocalProtector
  include RegionTaggable
  before_save :set_paper_trail_whodunnit
  before_save :update_footprint

  # # Broadcast changes in realtime with Hotwire
  # after_create_commit  -> { broadcast_prepend_later_to :game_plans, partial: "game_plans/index", locals: { game_plan: self } }
  # after_update_commit  -> { broadcast_replace_later_to self }
  # after_destroy_commit -> { broadcast_remove_to :game_plans, target: dom_id(self, :index) }

  has_many :leagues, dependent: :nullify
  serialize :data, coder: JSON, type: Hash

  self.ignored_columns = ["region_ids"]

  belongs_to :discipline, optional: true

  def update_footprint
    game_plan = data.sort.to_h
    self.footprint = Digest::MD5.hexdigest(game_plan.inspect)
  end

  #### minimum number of tables
  def tables
    # TODO: implementation
  end
end
