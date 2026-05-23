# frozen_string_literal: true

# Plan 19-01 (v0.6 F2): CORS fuer die externe Turnier-App-SPA.
#
# Die SPA wird ueber einen statischen Webserver (anderer Origin) ausgeliefert und ruft
# `/login` + `/api/external_tournament/*` cross-origin. Ohne CORS blockt der Browser.
#
# WICHTIG: `Authorization` muss EXPOSED werden — die App liest den JWT nach `POST /login`
# aus genau diesem Response-Header (cross-origin sonst unsichtbar -> Login scheitert "still").
#
# Eng begrenzt: NUR Bridge-API + Login. Default LAN-Origins; pro Szenario via ENV
# `EXTERNAL_APP_CORS_ORIGINS` (Komma-Liste) uebersteuerbar. Bearer-Auth -> keine Cookies,
# daher KEIN `credentials: true`.

LAN_ORIGIN_PATTERN = %r{
  \Ahttps?://(localhost|127\.0\.0\.1|192\.168\.\d{1,3}\.\d{1,3}|
    10\.\d{1,3}\.\d{1,3}\.\d{1,3}|172\.(1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3})(:\d+)?\z
}x

env_origins = ENV.fetch("EXTERNAL_APP_CORS_ORIGINS", "").split(",").map(&:strip).reject(&:empty?)
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
