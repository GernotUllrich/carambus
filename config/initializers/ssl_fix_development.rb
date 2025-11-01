# Temporary SSL fix for development environment
# This patches Net::HTTP to disable SSL certificate verification for external scraping
# NEVER use this in production!

if Rails.env.development?
  require 'net/http'
  require 'openssl'
  
  # Global OpenSSL context configuration
  OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:verify_mode] = OpenSSL::SSL::VERIFY_NONE
  
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
      
      # Also patch the class methods that create HTTP objects internally
      class << self
        alias_method :original_get, :get
        
        def get(uri_or_host, path = nil, port = nil)
          if uri_or_host.is_a?(URI::Generic)
            uri = uri_or_host
            start(uri.hostname, uri.port, :use_ssl => uri.scheme == 'https', :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
              return http.request_get(uri.request_uri).body
            end
          else
            original_get(uri_or_host, path, port)
          end
        end
      end
    end
  end
  
  puts "=" * 80
  puts "⚠️  SSL CERTIFICATE VERIFICATION DISABLED FOR DEVELOPMENT"
  puts "This is only for testing scraping in development!"
  puts "=" * 80
end

