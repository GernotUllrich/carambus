# frozen_string_literal: true

# Plan 19-02: CORS fuer die externe Turnier-SPA.
#
# Die App (Multi-Schema-Turnier-App, eigenes Repo) wird ueber einen statischen
# Webserver ausgeliefert (ES-Module brauchen http://) und ist damit eine ANDERE
# Origin als der Carambus-Server. Ohne CORS-Header blockt der Browser die
# Cross-Origin-Aufrufe an /login + /api/external_tournament/*.
#
# Scope bewusst eng:
#   - nur /login + /api/external_tournament/* (NICHT die ganze App)
#   - Default-Origins: localhost + private LAN-Bereiche (RFC1918).
#     Per ENV uebersteuerbar: EXTERNAL_APP_CORS_ORIGINS="https://app.example,http://host:8123"
#   - credentials NICHT noetig (Auth ueber Bearer-Token im Header, kein Cookie).
#   - WICHTIG: Authorization-Response-Header MUSS exposed werden — die App liest
#     den JWT nach POST /login aus genau diesem Header. Cross-Origin ist er sonst
#     unsichtbar.
#
# Sicherheit: oeffnet ausschliesslich die externe Turnier-Bridge-API (devise-jwt
# authentifiziert) fuer LAN-Clients. Keine Cookies/Session betroffen.

LAN_ORIGIN_PATTERN = %r{
  \Ahttps?://(
    localhost |
    127\.0\.0\.1 |
    192\.168\.\d{1,3}\.\d{1,3} |
    10\.\d{1,3}\.\d{1,3}\.\d{1,3} |
    172\.(1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3}
  )(:\d+)?\z
}x

env_origins = ENV.fetch("EXTERNAL_APP_CORS_ORIGINS", "")
                 .split(",").map(&:strip).reject(&:empty?)
allowed_origins = env_origins.presence || [LAN_ORIGIN_PATTERN]

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*allowed_origins)

    resource "/api/external_tournament/*",
      headers: :any,
      methods: %i[get post options],
      expose: ["Authorization"],
      max_age: 600

    resource "/login",
      headers: :any,
      methods: %i[post options],
      expose: ["Authorization"],
      max_age: 600
  end
end
