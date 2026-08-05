# frozen_string_literal: true

module RegionServer
  # Plan 35-01: Geteilte Datenschicht des MELDENS — die Bausteine, aus denen sowohl der alte
  # CC-Fluss (`define_participants`) als auch der neue CC-lose Meldelisten-Fluss ihre Meldungen
  # bauen. Extrahiert aus TournamentsController#players_by_club und #add_player_by_dbu.
  #
  # WARUM GETEILT UND NICHT DUPLIZIERT: Beide Flüsse lösen dieselbe Frage — "welcher Spieler
  # gehört zu diesem Verein in dieser Saison" und "wie wird aus einer DBU-Nummer eine Meldung".
  # Zwei Kopien driften auseinander, sobald einer der beiden Wege eine Regel nachzieht.
  #
  # WAS HIER NICHT HINEINGEHÖRT: Redirects, Flash-Texte, i18n. Der Service liefert strukturierte
  # Daten; die Formulierung macht der jeweilige Controller — der alte in seinen gewachsenen
  # Wortlauten, der neue über i18n.
  #
  # Abweichung von der ApplicationService-Konvention (`#call`): Das hier ist eine Helferschicht mit
  # zwei unabhängigen Operationen (Lesen + Schreiben), kein Command-Objekt mit einem Ergebnis.
  # Klassenmethoden statt `.new(...).call` halten die Aufrufstellen lesbar.
  class PlayerRegistration
    # Ergebnis von .register_by_dbu — die drei Sammel-Arrays des Ursprungscodes, strukturiert.
    # added/already_exists tragen {player:, dbu_nr:, position:}, not_found die rohen Eingaben.
    Result = Struct.new(:added, :already_exists, :not_found, keyword_init: true)

    class << self
      # Spieler eines Vereins zur Auswahl — ohne die bereits gemeldeten.
      # Rückgabe: [{id:, label:, dbu_nr:}], nach label sortiert.
      def selectable_players(tournament:, club_id:)
        return [] if club_id.blank?

        already_seeded = tournament.effective_seedings.pluck(:player_id).compact.to_set

        SeasonParticipation
          .where(club_id: club_id, season_id: season_id_for(tournament))
          .includes(:player)
          .filter_map do |sp|
            player = sp.player
            next if player.nil? || player.fullname.blank?
            next if already_seeded.include?(player.id)

            {id: player.id, label: player.fullname, dbu_nr: player.dbu_nr}
          end
          .uniq { |h| h[:id] }
          .sort_by { |h| h[:label].to_s }
      end

      # Meldet eine oder mehrere (kommaseparierte) DBU-Nummern auf das Turnier.
      # Legt lokale Seedings an; der Seeding-Initialzustand ist "registered" (AASM, seeding.rb:29)
      # — also genau eine MELDUNG, keine Teilnahme.
      def register_by_dbu(tournament:, dbu_input:, acting_user:)
        result = Result.new(added: [], already_exists: [], not_found: [])
        return result if dbu_input.blank?

        dbu_numbers(dbu_input).each do |dbu_nr|
          player = Player.find_by(dbu_nr: dbu_nr)

          unless player
            result.not_found << dbu_nr
            next
          end

          existing_seeding = tournament.effective_seedings.where(player_id: player.id).first

          if existing_seeding
            result.already_exists << {player: player, dbu_nr: dbu_nr, position: existing_seeding.position}
            next
          end

          # Plan 36-05: Die bestehende Liste MUSS lokal sein, bevor angehängt wird — sonst macht
          # das erste Anhängen alle bisherigen unsichtbar. Idempotent, siehe dort.
          materialize_effective_seedings!(tournament)

          # Position fortlaufend INNERHALB der Schleife bestimmen, damit mehrere Nummern in einer
          # Eingabe aufeinanderfolgende Plätze bekommen (Verhalten des Ursprungscodes).
          position = (tournament.effective_seedings.maximum(:position) || 0) + 1
          tournament.seedings.create!(player_id: player.id, position: position)

          # Plan 44-02: kurzfristige Nachmeldung atomar in die CC pushen. `enqueue_for` ist ohne
          # `tournament_cc` ein no-op — für CC-lose Turniere also folgenlos, für CC-Turniere
          # weiterhin nötig (ohne das landet die Nachmeldung lokal, aber NICHT in der CC).
          PushAccreditationToCcJob.enqueue_for(
            tournament: tournament, player: player,
            target: :ensure_participant, acting_user: acting_user
          )

          result.added << {player: player, dbu_nr: dbu_nr, position: position}
        end

        # Plan 36-02: das CC-lose GEGENSTÜCK zum Push oben. Ohne diesen Anstoß blieb eine Meldung
        # nach der Freigabe auf dem Region Server liegen: `EntryListSyncJob.enqueue_for` wurde
        # bisher NUR beim Freigeben gerufen (tournaments_controller.rb:696), einen Authority-Cron
        # dafür gibt es nicht (29-06 AC-6 deferiert), und der On-demand-Button verlangt eine
        # `source_url`, die das lokal angelegte Original nicht hat.
        # LIVE BELEGT (2026-07-29, tbv): drei Meldungen lagen wochenlang unbemerkt fest — der
        # Ingest-Dry-Run auf der Authority meldete `seedings_created=3, players_unresolved=[]`.
        #
        # NACH der Schleife, nicht darin: sonst löste eine Eingabe mit zehn Nummern zehn
        # Roundtrips aus, deren jeder die ganze Region/Saison einliest.
        EntryListSyncJob.enqueue_for(tournament: tournament) if result.added.any?

        result
      end

      # Plan 36-05: Macht die effektive Liste LOKAL, bevor jemand sie verändert.
      #
      # WARUM: `Tournament#effective_seedings` ist ein Entweder-oder (tournament.rb:609) — sobald
      # EIN lokales Seeding existiert, zaehlen nur noch die lokalen. Ein Anhaengen ohne
      # Materialisierung liess deshalb die gesamte bisherige Liste unsichtbar werden: der neu
      # gemeldete Spieler stand allein da. Live gesehen 2026-08-05 (ebc, Turnier 18614) und am
      # CC-Turnier 18612 reproduziert — der Fehler ist NICHT CC-los-spezifisch.
      #
      # DIESELBE MECHANIK WIE DER WIZARD-SCHRITT "Meldeliste uebernehmen"
      # (TournamentsController#use_clubcloud_as_participants), nur ausgeloest durch die erste
      # Aenderung statt durch den Knopf. Wer ueber einen der Direktlinks in die Teilnehmerliste
      # kommt (show.html.erb:173, _admin_tournament_info.html.erb:105, Hilfetext von Schritt 3),
      # ueberspringt den Knopf — und genau dann greift das hier.
      #
      # `position` REIST MIT (anders als beim Wizard-Knopf, der anschliessend neu sortiert): hier
      # wird nur ergaenzt oder gestrichen, die bestehende Reihenfolge darf sich dabei nicht aendern.
      #
      # GESTRICHENE REISEN ALS `no_show` MIT (Betreiber-Entscheidung 2026-08-05, nach dem Test auf
      # bcw). Sie duerfen nicht als regulaere Teilnehmer zurueckkehren — aber sie ganz wegzulassen
      # waere die andere Uebertreibung: dann verschwinden sie aus der Liste und lassen sich nur
      # ueber die Spielereingabe zurueckholen. Als `no_show` kopiert stehen sie mit leerem Haken da
      # und sind mit einem Klick wieder dabei (set_participation setzt den Zustand zurueck).
      #
      # NUR `no_show` wird uebernommen, jeder andere Zustand startet bei "registered": eine frische
      # Arbeitsliste soll nicht `participated` aus einem frueheren Lauf erben.
      #
      # IDEMPOTENT: liegt schon eine lokale Liste vor, passiert nichts. Damit ist der gesamte
      # Wizard-Fluss unberuehrt — dort ist die Liste beim ersten Klick bereits lokal.
      def materialize_effective_seedings!(tournament)
        return if tournament.has_local_seedings?

        tournament.effective_seedings.order(:position).each do |seeding|
          attrs = {
            player_id: seeding.player_id,
            balls_goal: seeding.balls_goal,
            position: seeding.position
          }
          attrs[:state] = "no_show" if seeding.state == "no_show"
          tournament.seedings.create!(attrs)
        end
      end

      # Teilnehmer-Haken in der Teilnehmerliste. Aufgerufen aus TournamentReflex#change_seeding —
      # dort extrahiert, damit das Verhalten ohne StimulusReflex-Infrastruktur pruefbar ist
      # (dieselbe Begruendung wie bei register_by_dbu, Plan 35-01).
      #
      # VERHALTENSERHALT (Betreiber 2026-08-05): Loeschen ueber den Haken und Wiederhinzufuegen
      # funktionieren im Wizard-Fluss und bleiben unveraendert — dort ist die Liste bereits lokal,
      # die Materialisierung ist ein no-op, und Suche/Anlage/Loeschung treffen dieselben Records
      # wie zuvor.
      #
      # NEU (Betreiber 2026-08-05): Ein `no_show` wird beim Anhaken ZURUECKGESETZT. Bisher fand der
      # checked-Zweig das vorhandene Seeding, gab es unveraendert zurueck und tat nichts — ein
      # gestrichener Spieler liess sich nicht wieder aufnehmen (live gesehen an "Schroeder,
      # Hans-Joerg", Turnier 18612).
      def set_participation(tournament:, player:, participating:)
        materialize_effective_seedings!(tournament)
        seeding = local_seeding_for(tournament, player)

        if participating
          # Kein lokales Seeding: entweder war der Spieler gar nicht gemeldet, oder er war als
          # `no_show` von der Materialisierung ausgenommen. Beides fuehrt zur selben Handlung.
          return tournament.seedings.create(player_id: player.id) if seeding.nil?

          seeding.reset_seeding_state! if seeding.state == "no_show"
          seeding
        else
          # NUR lokale Seedings loeschen: ein globales wuerde LocalProtector ohnehin still
          # zurueckrollen (local_protector.rb:27). Im all-lokalen Wizard-Fall ist das dieselbe
          # Menge wie zuvor — das Verhalten dort aendert sich nicht.
          tournament.seedings.where("seedings.id >= ?", Seeding::MIN_ID)
            .where(player_id: player.id).destroy_all
          nil
        end
      end

      # Zieht eine Meldung zurück. Nur LOKALE Seedings (id >= MIN_ID) dürfen fallen — globale
      # gehören der Authority und kämen beim nächsten Sync ohnehin zurück.
      # Rückgabe: der entfernte Spieler oder nil, wenn nichts (Zulässiges) zu entfernen war.
      def withdraw(tournament:, seeding_id:)
        seeding = tournament.seedings.where(id: seeding_id).first
        return nil if seeding.nil? || seeding.id < Seeding::MIN_ID

        player = seeding.player
        seeding.destroy!

        # Plan 36-02: wie beim Melden — auch ein Rückzug muss oben ankommen, sonst bliebe der
        # zurückgezogene Spieler global gemeldet. Erst hier, nach dem tatsächlichen Entfernen:
        # die beiden `return nil` oben (globales oder unbekanntes Seeding) haben nichts geändert
        # und dürfen deshalb auch nichts anstoßen.
        EntryListSyncJob.enqueue_for(tournament: tournament)

        player
      end

      private

      # Nach der Materialisierung ist die effektive Liste immer die lokale — die Suche darf
      # deshalb nicht auf das globale Original treffen (das waere nicht schreibbar).
      def local_seeding_for(tournament, player)
        tournament.seedings.where("seedings.id >= ?", Seeding::MIN_ID)
          .find_by(player_id: player.id)
      end

      # Saison des TURNIERS, nicht die laufende: Meldungen gehören zur Turniersaison. Bei einem
      # Turnier der Vorsaison zeigte `Season.current_season` sonst die falschen Spieler — und sie
      # ist nicht immer gesetzt (in der Testumgebung nil, wenn die Saison noch nicht angelegt ist).
      def season_id_for(tournament)
        tournament.season_id || Season.current_season&.id
      end

      def dbu_numbers(dbu_input)
        dbu_input.to_s.split(",").map(&:strip).reject(&:blank?)
      end
    end
  end
end
