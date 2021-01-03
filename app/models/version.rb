# == Schema Information
#
# Table name: versions
#
#  id             :bigint           not null, primary key
#  event          :string
#  item_type      :string
#  object         :text
#  object_changes :text
#  whodunnit      :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  item_id        :bigint
#
# Indexes
#
#  index_versions_on_item_type_and_item_id  (item_type,item_id)
#
class Version < ApplicationRecord
end
