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
    # Development policy with unsafe-inline
    policy.style_src :self, :unsafe_inline, "https://rsms.me", "https://cdnjs.cloudflare.com"
    policy.font_src :self, :https, :data, "https://cdnjs.cloudflare.com"
    policy.script_src :self, :unsafe_inline, :unsafe_eval,
      "https://cdn.jsdelivr.net",
      "https://unpkg.com"
  else
    # Initial production policy - more permissive
    policy.default_src :self
    policy.font_src :self, :https, :data
    policy.img_src :self, :https, :data
    policy.object_src :none
    policy.script_src :self, :unsafe_inline, :unsafe_eval,
      "https://cdn.jsdelivr.net",
      "https://unpkg.com"
    policy.style_src :self, :unsafe_inline, "https://rsms.me", "https://cdnjs.cloudflare.com"
    policy.connect_src :self, :https, :http
    policy.frame_src :self
    policy.media_src :self
  end
end

# Nonce generation only in production
if Rails.env.production?
  Rails.application.config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  Rails.application.config.content_security_policy_nonce_directives = %w(script-src style-src)
  # Start in report-only mode to catch issues without breaking functionality
  Rails.application.config.content_security_policy_report_only = true
end
