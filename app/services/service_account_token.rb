# frozen_string_literal: true

# Plan 29-05: Holt ein JWT bei einer anderen Carambus-Instanz (devise-jwt, Long-Lived 90d).
#
# Extrahiert aus `LocationServer::ResultReporter#token_for` (Plan 29-03), weil der
# Meldelisten-Ingest der Authority (`RegionServer::EntryListImporter`) exakt dieselbe Anmeldung
# gegen denselben Region Server braucht. Zwei Kopien derselben Anmeldung waeren zwei Orte, an
# denen ein geaendertes Login-Verhalten repariert werden muesste.
#
# TOP-LEVEL NAMESPACE MIT ABSICHT: der Baustein traegt in BEIDE Richtungen — Location→Region und
# Authority→Region. Ein `LocationServer::`- oder `RegionServer::`-Namespace waere in je einer
# Richtung irrefuehrend; `Carambus::` ist durch das Modul in config/application.rb belegt.
#
# KENNT KEINE KONFIGURATION: die Zugangsdaten werden uebergeben (aufzuloesen ist Sache von
# `Carambus.region_server_credentials`). Sonst waere der Baustein in Tests nicht isolierbar.
#
# KEIN CACHE: die Anmeldung geschieht einmal je Turnier-Meldung bzw. je Ingest-Lauf — ein Cache
# waere unnoetige Zustandshaltung.
class ServiceAccountToken
  # Gibt den reinen Bearer-Wert zurueck (ohne "Bearer "-Praefix).
  #
  # ⚠️ `Accept: application/json` ist NICHT optional: `SessionsController` skippt den
  # CSRF-Schutz nur `if: -> { request.format.json? }` (sessions_controller.rb:22), und
  # `request.format` kommt vom ACCEPT-Header — nicht vom Content-Type. Ohne ihn greift
  # `protect_from_forgery with: :exception` und der Login antwortet mit **HTTP 422 ohne
  # Body**; genau dieser Fall ist im SessionsController seit Plan 13-06.3 beschrieben und
  # ist am 2026-07-22 gegen nbv.carambus.de live aufgetreten.
  def self.fetch(base_url:, username:, password:)
    uri = URI("#{base_url}/login")
    request = Net::HTTP::Post.new(uri,
      "Content-Type" => "application/json", "Accept" => "application/json")
    request.body = {user: {email: username, password: password}}.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(request)
    end
    raise "Anmeldung am Region Server fehlgeschlagen (HTTP #{response.code}): #{uri}" unless response.is_a?(Net::HTTPSuccess)

    response["Authorization"].to_s.sub(/\ABearer /, "").presence ||
      raise("Region Server lieferte kein Authorization-Header bei der Anmeldung")
  end
end
