# frozen_string_literal: true

# all carambus models inherit from here
class ApplicationRecord < ActiveRecord::Base
  include CableReady::Updatable

  include CableReady::Broadcaster
  include ActionView::RecordIdentifier

  MIN_ID = 50_000_000

  DEBUG = Rails.env != "production"

  before_save :check

  primary_abstract_class

  include ActionView::RecordIdentifier

  def check
    return unless changes.except("sync_date").present?

    Rails.logger.info "+-+-+-+-+-+-+-+#{self.class.name} #{changes.inspect}" if DEBUG
  end

  # Orders results by column and direction
  def self.sort_by_params(column, direction)
    sortable_column = column.presence_in(sortable_columns) || "created_at"
    order(sortable_column => direction)
  end

  def self.sort_column(sort, default: "created_at")
    sort.presence_in(klass.sortable_columns) || default
  end

  def self.sort_direction(direction, default: "asc")
    direction.presence_in(%w[asc desc]) || default
  end

  # Returns an array of sortable columns on the model
  # Used with the Sortable controller concern
  #
  # Override this method to add/remove sortable columns
  def self.sortable_columns
    @sortable_columns ||= columns.map(&:name)
  end

  def disallow_saving_global_records
    raise ActiveRecord::Rollback if id < MIN_ID && ApplicationRecord.local_server? && !unprotected

    true
  end

  def self.local_server?
    Carambus.config.carambus_api_url.present?
  end

  def set_paper_trail_whodunnit
    # Use connection's current_user in reflex context, fallback to regular current_user
    PaperTrail.request.whodunnit = respond_to?(:connection) ? connection.current_user&.id : Current.user&.id
  end

  def hash_diff(first, second)
    first
      .dup
      .delete_if { |k,v| second[k] == v }
      .merge!(second.dup.delete_if { |k, _v| first.key?(k) })
  end

  def last_changes(last_n = 1)
    versions.order(id: :desc).limit(last_n).reverse.map do |version|
      h = version.changeset
      h.each_key do |k|
        v = h[k]
        h[k] = v[1].is_a?(Hash) ? [hash_diff(v[0], v[1]), hash_diff(v[1], v[0])] : v
      end
      { version.id => [version.whodunnit, h] }
    end
  end
end
