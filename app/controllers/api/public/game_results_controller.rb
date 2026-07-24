# frozen_string_literal: true

module Api
  module Public
    # Plan 32-10: Liefert die SPIELERGEBNISSE einer Region/Saison als JSON aus — die Quelle, aus
    # der die Authority die globalen Games baut.
    #
    # OEFFENTLICH, OHNE TOKEN (Betreiber-Entscheidung D9, 2026-07-24): Beim CC-Scrape wurde der
    # Admin-Account aufgegeben, weil das oeffentliche CC genug Information trug. Der Region Server
    # ist der CC-Ersatz und zeigt Turniere ohnehin oeffentlich (`tournaments_controller` hat fuer
    # show/index keine Authentifizierung). Ein authentifizierter Leseweg holte sich also durch eine
    # verschlossene Tuer, was daneben offen steht — und erkaufte das mit einer Credential-Kette, die
    # produktiv bereits ausgefallen ist (DB-Rebuild loescht den Service-Account → 401).
    #
    # EIGENER NAMESPACE MIT ABSICHT: Der Schreibweg (`Api::GameResultsController`, Plan 32-08)
    # bleibt authentifiziert — er ist die "Adminschnittstelle" im CC-Sinn. Ein
    # `skip_before_action :authenticate_user!, only: [:index]` dort haette diese Trennung in einer
    # Zeile versteckt, die beim naechsten Umbau leicht verlorengeht. Als Namespace ist sie an der
    # Dateistruktur ablesbar.
    #
    # DER SCOPE IST DER SCHUTZ, NICHT DAS TOKEN: `region` und `season` sind Pflicht. Es gibt keinen
    # ungescopeten Abzug — das waere die eine Form, in der "oeffentlich" zu weit ginge.
    class GameResultsController < ApplicationController
      skip_forgery_protection

      # GET /api/public/game_results?region=TBV&season=2026/2027
      #
      # Response (200):
      #   { "schema": "carambus.game_result/v1",
      #     "region": {"shortname": "TBV"}, "season": {"name": "2026/2027"},
      #     "tournaments": [ {"source_tournament_id": 50000021, "tournament_plan_id": 42,
      #       "games": [ {"group": "Gruppe A", "seqno": 7, "ended_at": "...",
      #                   "participations": [{"dbu_nr": "12345", "role": "playera",
      #                                       "result": 100, "innings": 24, "hs": 16, "gd": 4.17}]} ]} ] }
      #
      # Errors: 400 (region oder season fehlt) / 404 (Region oder Saison unbekannt)
      def index
        if params[:region].blank? || params[:season].blank?
          return render(json: {error: "region and season are required"}, status: :bad_request)
        end

        # Case-insensitive wie in entry_lists_controller.rb:30 — dieselbe Falle wurde beim
        # Region-Filter schon einmal behoben (c9a91510).
        region = ::Region.find_by("UPPER(shortname) = ?", params[:region].to_s.upcase)
        return render(json: {error: "Region not found"}, status: :not_found) if region.nil?

        season = ::Season.find_by(name: params[:season].to_s)
        return render(json: {error: "Season not found"}, status: :not_found) if season.nil?

        render json: {
          schema: "carambus.game_result/v1",
          region: {shortname: region.shortname},
          season: {name: season.name},
          tournaments: tournaments_for(region, season).filter_map { |t| tournament_payload(t) }
        }
      end

      private

      # NUR HIER LOKAL ANGELEGTE Turniere (id >= MIN_ID) — dieselbe Abgrenzung, die
      # Api::EntryListsController#tournaments_for trifft und dort mit einem Live-Vorfall belegt ist:
      # ein globales Turnier traegt auf der Authority seine eigene Provenienz, der Importer faende
      # kein source_url-Match und legte einen Duplikat-Zwilling an.
      def tournaments_for(region, season)
        ::Tournament
          .where(season_id: season.id, organizer_type: "Region", organizer_id: region.id)
          .where(::Tournament.arel_table[:id].gteq(::ApplicationRecord::MIN_ID))
          .without_drafts
          .order(:date)
      end

      # Was aus der ClubCloud stammt, gehoert der ClubCloud — sie zurueckzuspielen waere
      # bestenfalls ueberfluessig und schlimmstenfalls eine Ueberschreibung fremder Daten
      # (derselbe Grundsatz, den ResultReporter fuer Ranglisten anwendet).
      #
      # Der Diskriminator ist `tournament_cc`, NICHT `region.region_cc`: ein CC-loses Turnier in
      # einer CC-Region ist CC-los, und genau so entscheidet auch der Sender (Plan 32-09).
      #
      # Turniere ohne lokale Spiele liefern nichts — ein Ergebnis-Dokument, das leere Turniere
      # auffuehrt, waere nur Ballast.
      def tournament_payload(tournament)
        return nil if tournament.tournament_cc.present?

        games = local_games(tournament)
        return nil if games.empty?

        {
          "source_tournament_id" => tournament.id,
          "tournament_plan_id" => tournament.tournament_plan_id,
          "games" => games.map { |game| game_payload(game) }
        }
      end

      def local_games(tournament)
        tournament.games
          .where(::Game.arel_table[:id].gteq(::ApplicationRecord::MIN_ID))
          .includes(game_participations: :player)
          .order(:gname, :seqno)
      end

      # `gname` traegt auf dem Region Server bereits den VEREINFACHTEN Namen — der Sender hat ihn
      # abgebildet (Plan 32-09), der Ingest hat ihn gegen den Namensraum geprueft (Plan 32-08).
      # Push und Pull teilen sich damit dieselbe Zeilenform: ein Format, zwei Richtungen.
      def game_payload(game)
        {
          "group" => game.gname,
          "seqno" => game.seqno,
          "ended_at" => game.ended_at,
          "participations" => game.game_participations.filter_map { |gp| participation_payload(gp) }
        }
      end

      def participation_payload(game_participation)
        dbu_nr = game_participation.player&.dbu_nr
        return nil if dbu_nr.blank?

        {
          "dbu_nr" => dbu_nr.to_s,
          "role" => game_participation.role,
          "result" => game_participation.result,
          "innings" => game_participation.innings,
          "hs" => game_participation.hs,
          "gd" => game_participation.gd
        }
      end
    end
  end
end
