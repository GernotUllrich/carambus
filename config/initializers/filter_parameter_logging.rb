# frozen_string_literal: true

# Plan 13-06.3 / D-13-06.3-B: Robust password/secret filter via Lambda.
# Catches nested params at any depth (z.B. params[:error][:user][:password] aus
# 500-Re-Dispatch via exceptions_app = routes), nicht nur Top-Level.
#
# Reason: Eine 500 auf POST /login schickte den Original-Body via exceptions_app
# erneut durch die Routes; der ErrorsController-Pfad loggt params re-verschachtelt
# unter [:error]-Key. Symbol-basiertes filter_parameters greift nur auf den
# bereits gemounteten Hash-Pfad, nicht rekursiv tiefe Keys mit anderem Pfad.
# Lambda-Form maskiert *jeden* Key-Hit unabhängig von der Pfad-Tiefe.
Rails.application.config.filter_parameters << lambda do |key, value|
  next unless value.is_a?(String)
  if /password|passwd|secret|token|api[_-]?key|encryption[_-]?key|salt|crypt|otp|cvv|cvc/i =~ key.to_s
    value.replace("[FILTERED]")
  end
end
