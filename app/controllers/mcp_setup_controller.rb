# frozen_string_literal: true

class McpSetupController < ApplicationController
  before_action :authenticate_user!

  # Plan 14-G.8 / AC-2: Renew-Hinweis-Threshold (sanft, kein Hard-Stop).
  RENEW_THRESHOLD_DAYS = 14

  def show
    response.headers["Cache-Control"] = "no-store"
    response.headers["Pragma"] = "no-cache"

    @token, payload = Warden::JWTAuth::UserEncoder.new.call(current_user, :user, nil)

    # Plan 14-G.8 / AC-1: Dynamische Per-Region-URL via request.base_url.
    # carambus.de → "https://carambus.de"; nbv.carambus.de → "https://nbv.carambus.de".
    # request.base_url enthält scheme + host + non-default-port; Production-tauglich.
    base_url = request.base_url

    @setup_json = {
      type: "http",
      url: "#{base_url}/mcp?stateless=1",
      headers: {
        "Authorization" => "Bearer #{@token}",
        "Accept" => "application/json, text/event-stream"
      }
    }.to_json

    @setup_command = "claude mcp add-json --scope user carambus-remote '#{@setup_json}'"

    # Plan 14-G.8 / AC-2: Token-Restlaufzeit aus JWT-exp-Field.
    # Payload-Hash kommt direkt aus dem Encoder (kein zweiter Decode-Roundtrip nötig).
    # Defensive: falls payload nil/exp fehlt → days_remaining = nil (View rendert dann ohne Banner).
    @days_remaining = compute_days_remaining(payload)
    @total_lifetime_days = total_lifetime_days
    @renew_threshold_days = RENEW_THRESHOLD_DAYS
    @renew_recommended = @days_remaining.is_a?(Integer) && @days_remaining < RENEW_THRESHOLD_DAYS
  end

  private

  def compute_days_remaining(payload)
    return nil unless payload.is_a?(Hash) && payload["exp"].is_a?(Numeric)
    ((Time.zone.at(payload["exp"]) - Time.current) / 1.day).floor
  end

  def total_lifetime_days
    if Carambus.config.respond_to?(:jwt_expiration_days) && Carambus.config.jwt_expiration_days.present?
      Carambus.config.jwt_expiration_days.to_i
    else
      90
    end
  end
end
