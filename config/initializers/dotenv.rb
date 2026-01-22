# Load .env file if it exists
if File.exist?(Rails.root.join('.env'))
  require 'dotenv'
  Dotenv.load(Rails.root.join('.env'))
end

