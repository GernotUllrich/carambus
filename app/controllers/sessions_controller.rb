# frozen_string_literal: true

# Plan 13-06.3 / D-13-06.3-A: Devise-SessionsController-Override mit JSON-Support
# fuer den Bearer-JWT-Login-Pfad (POST /login mit Accept: application/json).
#
# Devise's Default-SessionsController spricht nur HTML — daher 406 Not Acceptable
# bei JSON-Requests. Plan 13-06.2-Tests nutzten Warden::JWTAuth::UserEncoder direkt
# und sahen den 406-Pfad nicht. Production-Live-Verify auf carambus.de hat den
# Bug aufgedeckt.
#
# Die JWT-Token-Issue passiert via devise-jwt's `Warden::Manager.after_set_user`-Hook
# automatisch — wir brauchen hier nur Format-Routing.
class SessionsController < Devise::SessionsController
  respond_to :html, :json

  # Plan 13-06.3 / D-13-06.3-C: skip_forgery_protection nur fuer JSON-Requests.
  # Browser-Login (HTML) behaelt CSRF-Schutz; API-Login (JSON) braucht ihn nicht
  # weil JWT als Anti-CSRF-Mechanismus dient (Token = Authentication-Beweis).
  # Analog Plan 13-06.1 D-13-06.1-B (McpController-Pattern; ohne diesen Skip
  # liefert ein POST /login mit Content-Type: application/json einen 422 ohne
  # Body, weil ApplicationController#protect_from_forgery with: :exception greift).
  skip_forgery_protection if: -> { request.format.json? }

  private

  # JSON-Body-Layout fuer Login-Response (devise-jwt setzt Authorization-Header
  # parallel via Hook — Body-Resource ist optionaler Mehrwert fuer Clients).
  def respond_with(resource, _opts = {})
    if request.format.json?
      render json: {
        status: {code: 200, message: "Logged in successfully."},
        data: {id: resource.id, email: resource.email}
      }, status: :ok
    else
      super
    end
  end

  def respond_to_on_destroy
    if request.format.json?
      if current_user
        render json: {status: 200, message: "logged out successfully"}, status: :ok
      else
        render json: {status: 401, message: "Couldn't find an active session."}, status: :unauthorized
      end
    else
      super
    end
  end
end
