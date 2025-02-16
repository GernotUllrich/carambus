module SourceHandler
  extend ActiveSupport::Concern
  included do
    after_save :remember_sync_date

    def remember_sync_date
      return unless saved_changes? && source_url.present?

      update_columns(
        sync_date: Time.now
      )
    end
  end
end
