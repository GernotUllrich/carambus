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
    policy.style_src :self, :unsafe_inline, "https://rsms.me"
    policy.script_src :self, :unsafe_inline, :unsafe_eval,
      "https://cdn.jsdelivr.net",
      "https://unpkg.com"
  else
    # Production policy with strict nonces
    policy.style_src :self, 'https://rsms.me', :strict_dynamic
    policy.script_src :self, 'https://cdn.jsdelivr.net', :strict_dynamic
  end

  # Consider adding these for production as well (without unsafe_inline/unsafe_eval)
  # policy.style_src :self, "https://rsms.me"
  # policy.script_src :self, "https://unpkg.com"
end

# Nonce generation only in production
if Rails.env.production?
  Rails.application.config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  Rails.application.config.content_security_policy_nonce_directives = %w(script-src style-src)
end
