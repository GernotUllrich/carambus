# frozen_string_literal: true

module Tournaments
  # Plan 35-01: Der MELDELISTEN-Fluss für CC-lose Turniere auf dem Region Server.
  #
  # WARUM EIGENER CONTROLLER: Der Region Server ist der LSW-Verwaltungsplatz (ClubCloud-Ersatz) —
  # er macht KEIN Turniermanagement (Betreiber 2026-07-25). `define_participants` ist dafür
  # ungeeignet: es ist zur Hälfte Modus-Findung (Turnierplan-Vorschlag, NBV-Gruppenbildung,
  # Alternativpläne) und trägt CC-Bausteine. Diese Seite ist deshalb keine Kopie davon, sondern
  # eine echte Teilmenge: melden, zurückziehen, freigeben.
  #
  # MELDUNG ≠ TEILNAHME: Hier entstehen Seedings im AASM-Zustand "registered" (seeding.rb:29).
  # Der Übergang nach "seeded"/"participated" ist Teilnehmerlisten-Semantik und passiert am
  # Spielort — nicht hier.
  #
  # ABGRENZUNG ZUM CC-STACK: Dieser Controller ruft weder `use_clubcloud_as_participants` noch
  # `mark_effective_seedings!` und berechnet keine Turnierpläne. Der CC-Stack bleibt unbeschnitten.
  class EntryListsController < ApplicationController
    before_action :set_tournament
    before_action :ensure_local_server
    before_action :ensure_cc_less
    before_action :authorize_manage_teilnehmerliste, only: %i[create destroy]

    # GET /tournaments/:tournament_id/entry_list
    def show
      @seedings = registered_seedings
      @clubs = selectable_clubs
    end

    # POST /tournaments/:tournament_id/entry_list
    #
    # Trägt BEIDE Meldewege: den Verein→Spieler-Picker (der seine Auswahl als `dbu_nr` übergibt)
    # und die direkte Eingabe einer oder mehrerer DBU-Nummern. Beide laufen über dieselbe
    # Datenschicht, damit die Auflösung nicht in zwei Varianten zerfällt.
    def create
      result = RegionServer::PlayerRegistration.register_by_dbu(
        tournament: @tournament, dbu_input: params[:dbu_nr], acting_user: current_user
      )

      if result.added.empty? && result.already_exists.empty? && result.not_found.empty?
        return redirect_to tournament_entry_list_path(@tournament),
          alert: t("tournaments.entry_list.flash.nothing_given")
      end

      redirect_to tournament_entry_list_path(@tournament), flash_key(result) => flash_message(result)
    end

    # DELETE /tournaments/:tournament_id/entry_list/:id
    def destroy
      player = RegionServer::PlayerRegistration.withdraw(
        tournament: @tournament, seeding_id: params[:id]
      )

      if player.nil?
        redirect_to tournament_entry_list_path(@tournament),
          alert: t("tournaments.entry_list.flash.withdraw_failed")
      else
        redirect_to tournament_entry_list_path(@tournament),
          notice: t("tournaments.entry_list.flash.withdrawn", player: player.fullname)
      end
    end

    # GET /tournaments/:tournament_id/entry_list/players_by_club?club_id=N (JSON)
    def players_by_club
      render json: RegionServer::PlayerRegistration.selectable_players(
        tournament: @tournament, club_id: params[:club_id]
      )
    end

    private

    def set_tournament
      @tournament = Tournament.find(params[:tournament_id])
    end

    # Meldungen in Reihenfolge. `no_show` bleibt draußen — abgemeldet ist nicht gemeldet.
    # `Player#club` ist eine METHODE über season_participations (player.rb:201), keine
    # Assoziation — deshalb wird der Weg dorthin vorgeladen, nicht `:club` direkt.
    def registered_seedings
      @tournament.seedings
        .where.not(state: "no_show")
        .includes(player: {season_participations: :club})
        .order(:position)
    end

    # Vereine der Turnierregion für den Picker. Fällt auf alle Vereine zurück, wenn das Turnier
    # keiner Region zugeordnet ist (der Picker wäre sonst leer und der LSW ohne Weg).
    def selectable_clubs
      region = @tournament.organizer.is_a?(Region) ? @tournament.organizer : @tournament.region
      scope = region.present? ? Club.where(region_id: region.id) : Club.all
      scope.order(:shortname)
    end

    # Wie im Bestand (add_player_by_dbu): erfolgreiche Meldungen führen zur Erfolgsmeldung,
    # sonst schlägt ein reiner Nicht-gefunden-Lauf als Warnung durch.
    def flash_key(result)
      return :alert if result.added.empty? && result.not_found.any?

      :notice
    end

    def flash_message(result)
      parts = []
      if result.added.any?
        parts << t("tournaments.entry_list.flash.added", count: result.added.size,
          players: result.added.map { |e| e[:player].fullname }.join(", "))
      end
      if result.already_exists.any?
        parts << t("tournaments.entry_list.flash.already", count: result.already_exists.size,
          players: result.already_exists.map { |e| e[:player].fullname }.join(", "))
      end
      if result.not_found.any?
        parts << t("tournaments.entry_list.flash.not_found", count: result.not_found.size,
          numbers: result.not_found.join(", "))
      end
      parts.join(" | ")
    end

    # Wie im Bestand (TournamentsController): Turnierverwaltung nur auf lokalen Servern.
    # Der dortige `has_clubcloud_results?`-Zweig entfällt hier — CC-lose Turniere haben
    # per Definition keine ClubCloud-Ergebnisse (ensure_cc_less filtert davor).
    def ensure_local_server
      return if local_server?

      flash[:alert] = t("tournaments.entry_list.flash.local_server_only")
      redirect_to tournaments_path
    end

    # Diese Seite ist der CC-LOSE Weg. CC-Turniere behalten ihren gewachsenen Fluss
    # (define_participants + ClubCloud-Übernahme) — die beiden dürfen sich nicht vermischen.
    def ensure_cc_less
      return if helpers.wizard_cc_less?(@tournament)

      redirect_to tournament_path(@tournament),
        alert: t("tournaments.entry_list.flash.cc_tournament")
    end

    # Plan 32-07: dasselbe Schreib-Gate wie die bestehenden Meldelisten-Actions
    # (TL / Sportwart im Wirkbereich / Admin). Bewusst NICHT strenger — ein `admin?`-Gate
    # würde TL und Sportwart aussperren, die genau hier arbeiten sollen.
    def authorize_manage_teilnehmerliste
      authorize @tournament, :manage_teilnehmerliste?
    rescue Pundit::NotAuthorizedError
      flash[:alert] = I18n.t("tournaments.errors.manage_teilnehmerliste_denied")
      redirect_to(@tournament)
    end
  end
end
