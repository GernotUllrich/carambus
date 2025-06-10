# frozen_string_literal: true

# == Schema Information
#
# Table name: region_taggings
#
#  id            :bigint           not null, primary key
#  taggable_type :string           not null
#  taggable_id   :bigint           not null
#  region_id     :bigint           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_region_taggings_on_region_id                                (region_id)
#  index_region_taggings_on_taggable_and_region                      (taggable_type,taggable_id,region_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (region_id => regions.id)
#
class RegionTagging < ApplicationRecord
  belongs_to :taggable, polymorphic: true
  belongs_to :region

  validates :taggable_type, :taggable_id, :region_id, presence: true
  validates :region_id, uniqueness: { scope: [:taggable_type, :taggable_id] }
end 