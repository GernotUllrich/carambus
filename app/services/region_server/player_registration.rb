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

        result
      end

      # Zieht eine Meldung zurück. Nur LOKALE Seedings (id >= MIN_ID) dürfen fallen — globale
      # gehören der Authority und kämen beim nächsten Sync ohnehin zurück.
      # Rückgabe: der entfernte Spieler oder nil, wenn nichts (Zulässiges) zu entfernen war.
      def withdraw(tournament:, seeding_id:)
        seeding = tournament.seedings.where(id: seeding_id).first
        return nil if seeding.nil? || seeding.id < Seeding::MIN_ID

        player = seeding.player
        seeding.destroy!
        player
      end

      private

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
