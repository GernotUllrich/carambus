module LocalProtector
  extend ActiveSupport::Concern
  included do
    attr_accessor :unprotected

    # Configure PaperTrail - but don't ignore columns, instead skip versions when only timestamps change
    # This ensures all columns are included in versions (needed for sync) but prevents
    # unnecessary version records during scraping operations
    has_paper_trail(
      skip: lambda { |obj|
        # Skip creating a version if only updated_at and/or sync_date changed
        return false unless obj.saved_changes.present?
        
        changed_attrs = obj.saved_changes.keys.map(&:to_s)
        ignorable_attrs = ['updated_at']
        ignorable_attrs << 'sync_date' if obj.class.column_names.include?('sync_date')
        
        # Only skip if ALL changes are ignorable (i.e., no substantive changes)
        (changed_attrs - ignorable_attrs).empty?
      }
    ) unless Carambus.config.carambus_api_url.present?
    after_save :disallow_saving_global_records
    before_destroy :disallow_saving_global_records

    # def local_server?
    #   Carambus.config.carambus_api_url.present?
    # end
    def disallow_saving_global_records
      # Skip protection in test environment
      return true if Rails.env.test?
      
      if id < 50_000_000 && ApplicationRecord.local_server? && !unprotected
        Rails.logger.warn("LocalProtector: Blocking save of global #{self.class.name}[#{id}], unprotected=#{unprotected.inspect}")
        raise ActiveRecord::Rollback
      end

      true
    end

    def disallow_saving_local_records
      raise ActiveRecord::Rollback if !ApplicationRecord.local_server? && !unprotected && !(Carambus.config.no_local_protection == 'true')

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
