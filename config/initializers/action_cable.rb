# frozen_string_literal: true

# Temporarily enable ActionCable logging for StimulusReflex debugging
# ActionCable.server.config.logger = Logger.new(nil)
ActionCable.server.config.logger = Rails.logger
