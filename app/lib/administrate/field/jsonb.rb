require "administrate/field/base"

module Administrate
  module Field
    class Jsonb < Administrate::Field::Base
      def to_s
        if data.nil? || data.empty?
          "{}"
        else
          data.to_json
        end
      end

      def self.permitted_attribute(attribute, _options = nil)
        { attribute => {} }
      end
      
      def formatted_data
        if data.nil? || data.empty?
          "{}"
        else
          JSON.pretty_generate(data)
        end
      rescue JSON::GeneratorError
        data.to_s
      end
    end
  end
end 