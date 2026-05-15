# frozen_string_literal: true

# McpController — HTTP-Mount für mcp-0.15.0 Streamable-HTTP-Transport (v0.3 Plan 13-03).
# Pattern B aus SPIKE-mcp-http.md Sektion 1.2: Per-Request Server-Init mit Devise-Auth + server_context.
# Stdio-Pfad (bin/mcp-server) bleibt parallel erhalten für technische-Stellvertretung-Persona (D-13-01-F).
#
# Auth: Devise-Cookie-Session (Redis-Session-Store per D-13-01-C-Override).
# Stateless-Optional-Flag via query-param `?stateless=1` für Cookie-freie Clients (Telegram v0.3+/v0.4 per D-13-01-F).
class McpController < ApplicationController
  # MCP-Protocol nutzt eigene Mcp-Session-Id-Header statt Rails-CSRF.
  # Plan 13-06.1 Empirical-Verify-Befund (2026-05-13): ApplicationController hat
  # `protect_from_forgery with: :exception` — `skip_before_action :verify_authenticity_token`
  # reicht NICHT, weil Rails 7+ die CSRF-Validation in einem zusätzlichen Pfad nullt die
  # Session für unverified POST-Requests → Devise sieht no current_user → 401 trotz valid Cookie.
  # `skip_forgery_protection` (Rails 5.2+ idiom) deaktiviert den kompletten CSRF-Layer für
  # diesen Controller — saubere API-Endpoint-Konvention.
  skip_forgery_protection
  before_action :authenticate_user!
  # D-14-G6: require_user_cc_region entfernt (users.cc_region gedroppt).
  # 14-G.2 etabliert Authority-Layer-Check via Sportwart-Wirkbereich + Carambus.config.region_id.

  def dispatch_request
    require "mcp"
    require_relative "../../lib/mcp_server/tool_registry"

    server = MCP::Server.new(
      name: "carambus_clubcloud_mcp",
      title: "Carambus ClubCloud MCP Server",
      version: "0.3.0",
      tools: McpServer::ToolRegistry.tool_classes_for(current_user),
      server_context: build_server_context
    )

    stateless = ActiveModel::Type::Boolean.new.cast(params[:stateless])
    transport = MCP::Server::Transports::StreamableHTTPTransport.new(server, stateless: stateless)

    status, headers, body = transport.handle_request(request)
    body_string = Array(body).join
    headers.each { |k, v| response.set_header(k, v) }
    render plain: body_string, status: status, content_type: headers["Content-Type"] || "application/json"
  end

  private

  def build_server_context
    # 14-G.1-Stub: server_context enthält nur user_id. 14-G.2 etabliert Authority-Layer
    # (Sportwart-Wirkbereich + TL-FK + Carambus.config.region_id).
    {
      user_id: current_user.id
    }
  end
end
