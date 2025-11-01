# Temporary SSL fix for development environment
# This patches Net::HTTP to disable SSL certificate verification for external scraping
# NEVER use this in production!

if Rails.env.development?
  require 'net/http'
  
  module Net
    class HTTP
      # Monkey patch to disable SSL verification in development
      alias_method :original_use_ssl=, :use_ssl=
      
      def use_ssl=(flag)
        self.original_use_ssl = flag
        if flag
          self.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
      end
    end
  end
  
  puts "=" * 80
  puts "⚠️  SSL CERTIFICATE VERIFICATION DISABLED FOR DEVELOPMENT"
  puts "This is only for testing scraping in development!"
  puts "=" * 80
end

