# frozen_string_literal: true

module Api
  # Plan 28-01: Liefert die MELDELISTE einer Region/Saison als JSON aus.
  #
  # Laeuft auf dem REGION SERVER, wo der Sportwart die Meldungen pflegt (Phase 26). Die AUTHORITY
  # holt sich das Dokument ab (Pull, analog CC-Scrape) und legt daraus globale Records an —
  # die lokalen IDs dieser Instanz werden dabei uebersetzt (RegionServer::EntryListImporter).
  #
  # Abgrenzung Meldeliste vs. Teilnehmerliste: Die Meldeliste sagt, WER GEMELDET ist; die
  # Teilnehmerliste entsteht spaeter auf dem Location Server aus den global eingetroffenen Seedings
  # (`use_clubcloud_as_participants`, id < MIN_ID -> id >= MIN_ID). Dieser Endpunkt liefert nur die
  # Meldung — keine Ergebnisse, keine Spiele.
  #
  # Auth: devise-jwt + Service-Account je Region (Muster aus ExternalTournamentsController).
  class EntryListsController < ApplicationController
    before_action :authenticate_user!
    skip_forgery_protection

    # GET /api/entry_lists?region=NBV&season=2026/2027
    #
    # Response (200):
    #   { "schema": "carambus.entry_list/v1",
    #     "region": {"shortname": "NBV"},
    #     "season": {"name": "2026/2027"},
    #     "tournaments": [ {..., "entries": [{"dbu_nr":…, "lastname":…, "firstname":…, "club":…}] } ] }
    #
    # Errors: 401 (Auth) / 404 (Region oder Saison unbekannt)
    def index
      region = Region.find_by("UPPER(shortname) = ?", params[:region].to_s.upcase)
      return render(json: {error: "Region not found"}, status: :not_found) if region.nil?

      season = Season.find_by(name: params[:season].to_s)
      return render(json: {error: "Season not found"}, status: :not_found) if season.nil?

      render json: {
        schema: "carambus.entry_list/v1",
        region: {shortname: region.shortname},
        season: {name: season.name},
        tournaments: tournaments_for(region, season).map { |t| tournament_payload(t) }
      }
    end

    private

    # Einzelmeisterschaften dieser Region/Saison — OHNE Entwuerfe: eine Saison-Kopie (Plan 27-01)
    # ist noch nicht vom Sportwart freigegeben und darf nicht global werden.
    # NUR HIER LOKAL ANGELEGTE Turniere (id >= MIN_ID). Ein Turnier mit globaler ID ist per Sync
    # von der Authority eingetroffen — meist aus der ClubCloud gescrapt. Es zurueckzuliefern waere
    # nicht bloss ueberfluessig: der Importer keyt ueber
    # `source_url = "<region-base>/tournaments/<lokale-id>"`, das globale Original traegt auf der
    # Authority aber seine eigene Provenienz (CC-source_url). Kein Treffer ⇒ er legte einen
    # DUPLIKAT-Zwilling desselben Wettbewerbs an.
    #
    # Live aufgefallen (2026-07-22): der erste Probelauf gegen nbv meldete "Turniere neu: 1" fuer
    # ein aus der CC gesynctes Test-Turnier.
    #
    # Entwuerfe bleiben ebenfalls aussen vor: eine Saison-Kopie (Plan 27-01) ist nicht freigegeben.
    def tournaments_for(region, season)
      ::Tournament
        .where(season_id: season.id, organizer_type: "Region", organizer_id: region.id)
        .where(::Tournament.arel_table[:id].gteq(::ApplicationRecord::MIN_ID))
        .without_drafts
        .order(:date)
    end

    def tournament_payload(tournament)
      attrs = tournament.attributes.slice(*::Tournament::SeasonCopier::STRUCTURE_ATTRIBUTES)

      attrs.merge(
        # Stabile Quell-Kennung: daraus baut die Authority ihr source_url-Keying. Die lokale ID ist
        # NUR hier sichtbar — auf der Authority entsteht eine eigene globale ID.
        "source_tournament_id" => tournament.id,
        "date" => tournament.date,
        "end_date" => tournament.end_date,
        "entries" => entries_for(tournament)
      )
    end

    # Gemeldete Spieler. dbu_nr ist der Aufloesungsschluessel auf der Authority (global eindeutig);
    # Name und Verein reisen als Gegenprobe mit, damit unaufloesbare Meldungen benennbar sind.
    def entries_for(tournament)
      seedings = tournament.seedings.includes(:player).order(:position)

      seedings.filter_map do |seeding|
        player = seeding.player
        next if player.nil?

        entry = {
          "dbu_nr" => player.dbu_nr,
          "lastname" => player.lastname,
          "firstname" => player.firstname,
          "club" => club_name_for(player, tournament),
          "position" => seeding.position,
          "balls_goal" => seeding.balls_goal
        }

        # Plan 29-03: Liegt ein Ergebnis vor, reist es mit — so erreicht der Abschluss die Authority
        # ueber denselben Pull, der die Meldung holt. NUR wenn vorhanden: fuer Turniere ohne Ergebnis
        # bleibt das Dokument byte-gleich zu dem, was Plan 28-01 ausgeliefert hat.
        ranking = seeding.data.is_a?(Hash) ? seeding.data.dig("result", "Gesamtrangliste") : nil
        entry["Gesamtrangliste"] = ranking if ranking.present?

        entry
      end
    end

    def club_name_for(player, tournament)
      ::SeasonParticipation
        .where(player_id: player.id, season_id: tournament.season_id)
        .includes(:club).first&.club&.name
    end
  end
end
