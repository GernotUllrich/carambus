# frozen_string_literal: true

module LocationServer
  # Plan 32-09: Meldet EIN abgeschlossenes Spiel vom LOCATION SERVER an den REGION SERVER.
  #
  # Der Weg ist derselbe wie beim Turnier-Abschluss (Plan 29-03), nur mit anderer Kadenz:
  #   Location Server (hier) → Region Server → Authority-Pull (32-10) → Sync → alle Instanzen
  # Ein direkter Push an die Authority waere kuerzer, wuerde sie aber fuer Schreibzugriffe von
  # aussen oeffnen. Die Betreiber-Entscheidung (2026-07-21) haelt sie geschlossen.
  #
  # WARUM JE SPIEL UND AUTOMATISCH: Betreiber-Entscheidungen D4/D5 — Ergebnisse reisen waehrend
  # des Turniers, ohne Handgriff. Der Anstoss sitzt deshalb an derselben Stelle, an der der CC-Weg
  # hochlaedt (`TournamentMonitor::ResultProcessor#finalize_game_result`).
  #
  # DER NAME WIRD VEREINFACHT: Das Turniermanagement arbeitet mit feinen Namen aus den
  # ExecutorParams (`group1:2-3`, `hf1`, `p<3-4>`); uebermittelt wird der veroeffentlichte Name
  # ("Gruppe A", "Halbfinale", "Spiel um Platz 3"). Wie bei der CC gibt die Source den erlaubten
  # Namensraum vor — der Region Server prueft dagegen (Plan 32-08).
  #
  # ZIELABLEITUNG OHNE NEUE DATENHALTUNG: Das Turnier liegt hier als GLOBALER Record (per Sync
  # eingetroffen) und traegt `source_url = "<region-base>/tournaments/<lokale-id>"` — gesetzt vom
  # Ingest in Plan 28-01. Daraus liest dieser Service beides: wohin gemeldet wird und woran es
  # dort haengt. Keine Migration, keine Konfiguration.
  class GameResultReporter
    Result = Struct.new(:reported, :skipped_no_source_url, :skipped_unmappable_name,
      :skipped_incomplete, :response, keyword_init: true)

    def initialize(game:, armed: false, token: nil)
      @game = game
      @tournament = game.tournament
      @armed = armed
      @token = token
    end

    def call
      result = Result.new(reported: 0, skipped_no_source_url: 0, skipped_unmappable_name: 0,
        skipped_incomplete: 0)

      target = target_from_source_url
      if target.nil?
        # Kein source_url: aus der ClubCloud gescrapt oder nie ueber den Ingest gelaufen. Dann gibt
        # es keinen Region Server, der dieses Turnier als Arbeitsexemplar fuehrt.
        result.skipped_no_source_url += 1
        return result
      end

      group = simplified_group_name
      if group.blank?
        result.skipped_unmappable_name += 1
        return result
      end

      row = build_row(group)
      if row.nil?
        result.skipped_incomplete += 1
        return result
      end

      result.reported = 1
      return result unless @armed

      result.response = post(target, row)
      result
    end

    private

    # "<region-base>/tournaments/<lokale-id>" -> {base:, source_tournament_id:}
    def target_from_source_url
      url = @tournament&.source_url.to_s
      match = url.match(%r{\A(?<base>https?://[^/]+)/tournaments/(?<id>\d+)\z})
      return nil if match.nil?

      {base: match[:base], source_tournament_id: match[:id].to_i}
    end

    # Bewusst DIESELBE Funktion, die der CC-Upload benutzt: ihr Name traegt "cc", ihre Logik ist
    # es nicht — sie bildet Ausfuehrungsnamen auf veroeffentlichte Namen ab und gilt fuer jede
    # Source. Umbenennen waere hier out of scope, sie haengt am produktiven CC-Weg.
    #
    # KEIN FALLBACK AUF DEN ROHEN gname: der Region Server wuerde einen Namen ausserhalb des
    # Namensraums ohnehin abweisen (32-08), und ein stiller Fallback verschleierte den Fehler.
    def simplified_group_name
      group = Setting.map_game_gname_to_cc_group_name(@game.gname)
      if group.blank?
        Rails.logger.warn(
          "[GameResultReporter] game[#{@game.id}] gname '#{@game.gname}' ist nicht auf einen " \
          "veröffentlichten Spielnamen abbildbar — nicht gemeldet"
        )
      end
      group
    end

    # Die Spieler-Kennung ist `dbu_nr` — IDs sind je Instanz verschieden und taugen nicht ueber
    # Instanzgrenzen (derselbe Grundsatz wie im Meldelisten-Ingest, Plan 28-01).
    #
    # Alles-oder-nichts: ein halb gemeldetes Spiel waere im Ranking schaedlicher als keines.
    def build_row(group)
      participations = @game.game_participations.includes(:player).to_a
      return nil unless participations.size == 2
      return nil if participations.any? { |gp| gp.player&.dbu_nr.blank? }

      {
        "group" => group,
        "seqno" => @game.seqno,
        "ended_at" => @game.ended_at,
        "participations" => participations.map { |gp| participation_row(gp) }
      }
    end

    def participation_row(game_participation)
      {
        "dbu_nr" => game_participation.player.dbu_nr.to_s,
        "role" => game_participation.role,
        "result" => game_participation.result,
        "innings" => game_participation.innings,
        "hs" => game_participation.hs,
        "gd" => game_participation.gd
      }
    end

    # Anmeldung an `ServiceAccountToken` delegiert (geteilt mit dem Meldelisten-Ingest der
    # Authority, Plan 29-05); Zugangsdaten an `Carambus.region_server_credentials`.
    #
    # Bewusst als Kopie aus `ResultReporter#token_for`: dieser Plan laesst den produktiven
    # 29-03-Weg unberuehrt. Eine gemeinsame Extraktion waere ein eigener, kleiner Nachtrag.
    def token_for(base)
      return @token if @token.present?

      credentials = Carambus.region_server_credentials(@tournament.region&.shortname)
      if credentials.nil?
        raise "Kein Zugang zum Region Server konfiguriert — `region_server.<region>.username/password` " \
              "in den Rails-Credentials (ueber carambus_data/secrets.yml + " \
              "`rake scenario:generate_credentials`) oder `region_server_user`/`region_server_password` " \
              "in config/carambus.yml setzen (Service-Account je Region, siehe " \
              "`rake service_accounts:create_carambus_app[<REGION>]`)"
      end

      ServiceAccountToken.fetch(base_url: base, **credentials)
    end

    # `tournament_plan_id` reist mit, damit der Region Server den erlaubten Namensraum ableiten
    # kann (32-08). TournamentPlans sind GLOBALE Records — die ID traegt ueber Instanzgrenzen,
    # ohne Uebersetzung. Das ist die Gegenrichtung zum deferierten Vorschlagsweg: die Location
    # meldet, wofuer sie sich entschieden hat.
    def post(target, row)
      token = token_for(target[:base])

      uri = URI("#{target[:base]}/api/game_results")
      request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
      request["Authorization"] = "Bearer #{token}"
      request.body = {
        "schema" => "carambus.game_result/v1",
        "target_type" => "Tournament",
        "source_tournament_id" => target[:source_tournament_id],
        "tournament_plan_id" => @tournament.tournament_plan_id,
        "games" => [row]
      }.to_json

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end
      raise "Region Server antwortet HTTP #{response.code}: #{uri}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end
  end
end
