# == Schema Information
#
# Table name: uploads
#
#  id         :bigint           not null, primary key
#  filename   :string
#  position   :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :integer
#
class Upload < ApplicationRecord
  # Broadcast changes in realtime with Hotwire
  after_create_commit -> { broadcast_prepend_later_to :uploads, partial: "uploads/index", locals: { upload: self } }
  after_update_commit -> { broadcast_replace_later_to self }
  after_destroy_commit -> { broadcast_remove_to :uploads, target: dom_id(self, :index) }
end
