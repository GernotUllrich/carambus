# == Schema Information
#
# Table name: sync_hashes
#
#  id         :bigint           not null, primary key
#  doc        :text
#  md5        :string
#  url        :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class SyncHash < ApplicationRecord
  # # Broadcast changes in realtime with Hotwire
  # after_create_commit  -> { broadcast_prepend_later_to :sync_hashes, partial: "sync_hashes/index", locals: { sync_hash: self } }
  # after_update_commit  -> { broadcast_replace_later_to self }
  # after_destroy_commit -> { broadcast_remove_to :sync_hashes, target: dom_id(self, :index) }

  def self.changed?(url, html_)
    html = html_.to_s.gsub(/ng=[0123456789abcdef]+/, "")
    md5 = Digest::MD5.hexdigest(html)
    @sync_hash = SyncHash.find_by_url(url)
    if @sync_hash.present?
      if @sync_hash.md5 == md5
        false
      else
        @sync_hash.update(md5: md5, doc: html)
        true
      end
    else
      @sync_hash = SyncHash.create(url: url, md5: md5, doc: html)
      true
    end
  end
end
