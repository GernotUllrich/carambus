# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

# Rails.application.configure do
#   config.content_security_policy do |policy|
#     policy.default_src :self, :https
#     policy.font_src    :self, :https, :data
#     policy.img_src     :self, :https, :data
#     policy.object_src  :none
#     policy.script_src  :self, :https
#     policy.style_src   :self, :https
#     # Specify URI for violation reports
#     # policy.report_uri "/csp-violation-report-endpoint"
#   end
#
#   # Generate session nonces for permitted importmap, inline scripts, and inline styles.
#   config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
#   config.content_security_policy_nonce_directives = %w(script-src style-src)
#
#   # Report violations without enforcing the policy.
#   # config.content_security_policy_report_only = true
# end

Rails.application.config.content_security_policy do |policy|
  if Rails.env.development?
    # Development policy with nonces
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data
    policy.object_src  :none
    policy.script_src  :self, :https,
      "https://cdn.jsdelivr.net",
      "https://unpkg.com"
    policy.style_src   :self, "https://rsms.me", 
      "'sha256-N1w/IunAmcmGA9bmhwczywYKXhI6/OPxe8mLaECWK0I='", # First Turbo style
      "'sha256-5j81gpq0UivmDYXTlXpL6OlaOpmQRgb3uGSvE4a8Pmk='", # Second style
      "'sha256-8MKR4j8B1z6srQu4Pe0OATJdQlWy3zdKFo4UYI2nqWw='", # Third style
      :unsafe_hashes,  # Allow hashes to work with style attributes and event handlers
      :unsafe_inline   # Temporarily allow all inline styles in development
    policy.connect_src :self, :https, "ws://localhost:3000", "wss://localhost:3000"
  else
    # Production policy with strict nonces
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data
    policy.object_src  :none
    policy.script_src  :self, :https, "https://cdn.jsdelivr.net", "https://newapi.carambus.de"
    policy.style_src   :self, :https, "https://rsms.me",
      "'sha256-N1w/IunAmcmGA9bmhwczywYKXhI6/OPxe8mLaECWK0I='", # First Turbo style
      "'sha256-5j81gpq0UivmDYXTlXpL6OlaOpmQRgb3uGSvE4a8Pmk='", # Second style
      "'sha256-8MKR4j8B1z6srQu4Pe0OATJdQlWy3zdKFo4UYI2nqWw='",  # Third style
      :unsafe_hashes   # Allow hashes to work with style attributes and event handlers
    policy.connect_src :self, :https, "wss://#{Carambus.config.carambus_domain}"
  end

  # Generate session nonces for permitted importmap, inline scripts, and inline styles
  Rails.application.config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  Rails.application.config.content_security_policy_nonce_directives = %w(script-src style-src)
end

# Report CSP violations in production
if Rails.env.production?
  Rails.application.config.content_security_policy_report_only = false
end
