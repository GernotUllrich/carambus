class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def self.sort_by_params(column, direction)
    sortable_column = sortable_columns.include?(column) ? column : "created_at"
    order(sortable_column => direction).where.not(sortable_column => nil)
  end

  # Override this method to add/remove sortable columns
  def self.sortable_columns
    @@sortable_columns ||= columns.map(&:name)
  end

  def set_paper_trail_whodunnit
    if ::PaperTrail.request.enabled?
      ::PaperTrail.request.whodunnit = proc do
        caller.select { |c| c.starts_with? Rails.root.to_s }.join("\n")
      end
      true
    end
  end

  def hash_diff(first, second)
    first.
      dup.
      delete_if { |k, v| second[k] == v }.
      merge!(second.dup.delete_if { |k, v| first.has_key?(k) })
  end

  def last_changes(n = 1)
    versions.all[-n..-1].map do |version|
      h = version.changeset;
      h.keys.each { |k| v = h[k]; h[k] = v[1].is_a?(Hash) ? [hash_diff(v[0], v[1]), hash_diff(v[1], v[0])] : v }
      h
    end
  end
end
