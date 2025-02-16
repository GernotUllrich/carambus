module LocalProtector
  extend ActiveSupport::Concern
  included do
    attr_accessor :unprotected

    has_paper_trail unless Carambus.config.carambus_api_url.present?
    after_save :disallow_saving_global_records
    before_destroy :disallow_saving_global_records

    # def local_server?
    #   Carambus.config.carambus_api_url.present?
    # end
    def disallow_saving_global_records
      raise ActiveRecord::Rollback if id < 50_000_000 && ApplicationRecord.local_server? && !unprotected

      true
    end

    def disallow_saving_local_records
      raise ActiveRecord::Rollback if !ApplicationRecord.local_server? && !unprotected

      true
    end

    def set_paper_trail_whodunnit
      return unless ::PaperTrail.request.enabled?

      ::PaperTrail.request.whodunnit = proc do
        caller.select { |c| c.starts_with? Rails.root.to_s }.join("\n")
      end
      true
    end

    def hash_diff(first, second)
      first
        .dup
        .delete_if { |k, v| second[k] == v }
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
end
