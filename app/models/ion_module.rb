# == Schema Information
#
# Table name: ion_modules
#
#  id             :bigint           not null, primary key
#  data           :text
#  html           :text
#  module_type    :string
#  position       :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  ion_content_id :integer
#  module_id      :string
#
class IonModule < ApplicationRecord
  belongs_to :ion_content

  serialize :data, coder: JSON, type: Hash

  def deep_merge_data!(hash)
    h = data.dup
    h.deep_merge!(hash)
    self.data = JSON.parse(h.to_json)
    # save!
  end

  def self.list_module_types
    balls = IonModule.all.to_a
    most_idx = nil

    groups = balls.each_with_object({}) do |ball, hsh|
      hsh[ball.module_type] = [] if hsh[ball.module_type].nil?
      hsh[ball.module_type] << ball

      most_idx = ball.module_type if hsh[most_idx].nil? || hsh[ball.module_type].size > hsh[most_idx].size
    end

    groups.keys.map { |k| "#{k} (#{groups[k].count})" }
  end
end
