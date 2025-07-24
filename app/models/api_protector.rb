# frozen_string_literal: true

# Module: ApiProtector
#
# This module is intended to prevent ActiveRecord classes created in the API server on local Server.
#
# Usage:
#    class SomeModel < ActiveRecord::Base
#        include ApiProtector
#        ...
#    end
#
# Key Features:
# 1. Adds an attribute accessor :unprotected which can be used to access and modify the unprotected instance variable.
# 2. When included in a class, it enables version tracking feature if carambus_api_url configuration exists
# in the application's configuration and also if the Rails environment currently is not production.
# 3. It adds after_save and after_destroy callbacks to the class, which refers
# to a method called :disallow_saving_local_
# records, that restricts saving or destroying local records.
# (This method must be defined in the class).
#
# Note: The module makes use of ActiveSupport::Concern, thus it must be included in
# classes to be used. The methods/attributes would not be available via inheritance.
# module ApiProtector
module ApiProtector
  extend ActiveSupport::Concern
  included do
    attr_accessor :unprotected

    # existence of carambus_api_url implies a local server
    has_paper_trail if Carambus.config.carambus_api_url.present? # && Rails.env != "production"
    after_save :disallow_saving_local_records
    after_destroy :disallow_saving_local_records

    def disallow_saving_local_records
      raise ActiveRecord::Rollback if (new_record? || id > Seeding::MIN_ID) && !ApplicationRecord.local_server? && !unprotected

      true
    end
  end
end
