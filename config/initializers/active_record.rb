# config/initializers/active_record.rb
# class << ActiveRecord::Base
#   alias_method :[], :find_new
# end
#
ActiveRecord::Base.class_eval do
  def self.[](*ids)
    where(id: ids).first
  end
end

module ActiveRecord
  class Base
    def top_class
      clasz = self.class
      until clasz.superclass == ActiveRecord::Base
        clasz = clasz.superclass
      end
      clasz
    end
  end
end
