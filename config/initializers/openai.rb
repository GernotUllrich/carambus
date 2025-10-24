# frozen_string_literal: true

# OpenAI Configuration
# 
# To add your OpenAI API key to credentials:
# 
# For development:
#   EDITOR="code --wait" rails credentials:edit --environment development
# 
# Then add:
#   openai:
#     api_key: sk-your-api-key-here
#

if Rails.application.credentials.dig(:openai, :api_key).present?
  OpenAI.configure do |config|
    config.access_token = Rails.application.credentials.dig(:openai, :api_key)
    config.request_timeout = 30 # 30 seconds timeout
    config.log_errors = Rails.env.development? # Log errors in development
  end
else
  Rails.logger.warn "⚠️  OpenAI API key not configured in credentials. AI search will not work." if Rails.env.development?
end

