# frozen_string_literal: true

class McpSetupController < ApplicationController
  before_action :authenticate_user!

  def show
    response.headers["Cache-Control"] = "no-store"
    response.headers["Pragma"] = "no-cache"

    @token, _payload = Warden::JWTAuth::UserEncoder.new.call(current_user, :user, nil)

    @setup_json = {
      type: "http",
      url: "https://carambus.de/mcp?stateless=1",
      headers: {
        "Authorization" => "Bearer #{@token}",
        "Accept" => "application/json, text/event-stream"
      }
    }.to_json

    @setup_command = "claude mcp add-json --scope user carambus-remote '#{@setup_json}'"
  end
end
