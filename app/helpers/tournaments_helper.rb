module TournamentsHelper
end

module TournamentsHelper
  def hash_diff(first, second)
    first
      .dup
      .delete_if { |k, v| second[k] == v }
      .merge!(second.dup.delete_if { |k, _v| first.has_key?(k) })
  end
end
