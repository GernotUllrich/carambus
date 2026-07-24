# frozen_string_literal: true

module RegionServer
  # Plan 32-08: Nimmt SPIEL-ERGEBNISZEILEN vom Location Server entgegen und legt sie als LOKALE
  # Games am lokalen Turnier ab.
  #
  # WARUM DER REGION SERVER SIE HAELT: Er ist der ClubCloud-Ersatz. Im CC-Weg haelt die ClubCloud
  # die Ergebniszeilen, bis die Authority sie scrapt; CC-los uebernimmt der Region Server diese
  # Rolle. Die endgueltigen GLOBALEN Games entstehen erst beim Authority-Pull (Plan 32-10) — hier
  # entsteht ausschliesslich das lokale Zwischenlager.
  #
  # NAMENSRAUM (Betreiber-Klarstellung 2026-07-24): Wie bei der CC gibt die Source vor, welche
  # Spielnamen erlaubt sind. Das Turniermanagement arbeitet mit einer feineren Namensgebung aus den
  # ExecutorParams (`group1:2-3`, `hf1`, `p<3-4>`), die fuer die Uebermittlung VEREINFACHT wird
  # ("Gruppe A", "Halbfinale", "Spiel um Platz 3").
  #
  # DESHALB IST (gname, seqno) DER SCHLUESSEL, NICHT gname ALLEIN: die Vereinfachung ist
  # viele-zu-eins — `hf1` und `hf2` werden beide zu "Halbfinale". Genau so traegt es die CC-Zeile:
  # `Gruppe;Partie` (tournament_monitor/result_processor.rb:559). Ohne seqno im Schluessel wuerde
  # das zweite Halbfinale das erste still ueberschreiben.
  class GameResultIngest
    Result = Struct.new(:accepted, :updated, :unresolved, :error, keyword_init: true)

    def initialize(tournament:, games:, tournament_plan_id: nil)
      @tournament = tournament
      @games = games
      @tournament_plan_id = tournament_plan_id
    end

    def call
      result = Result.new(accepted: 0, updated: 0, unresolved: [])

      conflict = apply_tournament_plan!
      if conflict.present?
        result.error = conflict
        return result
      end

      allowed = allowed_group_names

      @games.each do |row|
        ingest_row(row, allowed, result)
      end

      result
    end

    private

    # Die Location meldet, fuer welchen Plan sie sich entschieden hat (D2: sie entscheidet, der
    # Region Server schlaegt hoechstens vor). Daraus leitet sich der erlaubte Namensraum ab.
    # TournamentPlans sind GLOBALE Records — die ID traegt ueber Instanzgrenzen, ohne Uebersetzung.
    #
    # Ein Wechsel des Plans mitten im Turnier ist kein Ergebnis-, sondern ein Ablauf-Ereignis und
    # braucht eine eigene Betrachtung — hier wird er gemeldet, nicht stillschweigend uebernommen.
    def apply_tournament_plan!
      return nil if @tournament_plan_id.blank?

      current = @tournament.tournament_plan_id
      if current.blank?
        @tournament.update_column(:tournament_plan_id, @tournament_plan_id)
        return nil
      end

      return nil if current.to_i == @tournament_plan_id.to_i

      "Turnierplan weicht ab: lokal #{current}, gemeldet #{@tournament_plan_id}"
    end

    # Der SELEKTOR — das CC-Pendant ist `tournament_cc.group_cc.data["positions"]`.
    #
    # Quelle sind die ExecutorParams-Schluessel des Plans: sie fuehren nicht nur die Gruppen
    # ("g1", "g2"), sondern auch KO- und Platzierungsspiele ("hf1", "fin", "p<9-10>") — siehe den
    # Kommentar an TournamentPlan#rounds_count. Jeder Schluessel wird durch dieselbe Vereinfachung
    # geschickt, die der Sender benutzt; das Ergebnis ist der erlaubte Namensraum.
    #
    # FAIL-OPEN: Laesst sich kein Namensraum ableiten (Plan fehlt oder ohne ExecutorParams), wird
    # NICHT geprueft. Ein Turnier ohne ableitbaren Plan darf keine gueltigen Ergebnisse verlieren —
    # die Pruefung ist eine Absicherung gegen Tippfehler, kein Zugangsschutz.
    def allowed_group_names
      plan = @tournament.tournament_plan
      return nil if plan.nil?

      names = executor_param_keys(plan).filter_map do |key|
        Setting.map_game_gname_to_cc_group_name(normalize_plan_key(key))
      end.to_set

      if names.empty?
        Rails.logger.warn(
          "[GameResultIngest] Kein Namensraum aus TournamentPlan[#{plan.id}] ableitbar — " \
          "Spielnamen werden nicht geprüft"
        )
        return nil
      end

      names
    end

    # Nur Schluessel, deren Wert ein Hash ist — "RK" (Rangliste) und Skalare wie "GK" sind keine
    # Spiele. Dieselbe Abgrenzung trifft TournamentPlan#rounds_count.
    def executor_param_keys(plan)
      return [] if plan.executor_params.blank?

      JSON.parse(plan.executor_params).filter_map do |key, value|
        key if key != "RK" && value.is_a?(Hash)
      end
    rescue JSON::ParserError => e
      Rails.logger.warn "[GameResultIngest] ExecutorParams von TournamentPlan[#{plan.id}] unlesbar: #{e.message}"
      []
    end

    # ExecutorParams fuehren Gruppen als "g1", `game.gname` schreibt "group1:2-3" —
    # map_game_gname_to_cc_group_name kennt nur die zweite Form. KO- und Platzierungsschluessel
    # ("hf1", "fin", "p<9-10>") stimmen dagegen bereits ueberein.
    def normalize_plan_key(key)
      /\Ag(\d+)\z/.match?(key) ? "group#{key[1..]}:" : key
    end

    def ingest_row(row, allowed, result)
      group = row["group"].to_s.strip
      seqno = row["seqno"]

      if group.blank? || seqno.blank?
        result.unresolved << "#{row_label(row)} — group oder seqno fehlt"
        return
      end

      if allowed.present? && !allowed.include?(group)
        result.unresolved << "#{row_label(row)} — Spielname '#{group}' ist für diesen Turnierplan nicht vorgesehen"
        return
      end

      resolved = resolve_players(row)
      if resolved.nil?
        result.unresolved << row_label(row)
        return
      end

      game = @tournament.games.find_by(gname: group, seqno: seqno)
      existing = game.present?
      game ||= @tournament.games.new

      game.assign_attributes(gname: group, seqno: seqno, ended_at: row["ended_at"])
      game.region_id = @tournament.region_id
      game.save!

      resolved.each { |participation_row, player| upsert_participation(game, participation_row, player, group) }

      existing ? result.updated += 1 : result.accepted += 1
    end

    # Spieler werden ueber `dbu_nr` aufgeloest — IDs sind je Instanz verschieden und taugen nicht
    # ueber Instanzgrenzen. NIEMALS einen Player anlegen (Grundsatz aus Plan 28-01): eine gemeldete
    # Luecke ist besser als eine erfundene Zuordnung.
    #
    # Alles-oder-nichts je Zeile: ein Spiel mit nur einem aufloesbaren Spieler waere ein halbes
    # Ergebnis und im Ranking schaedlicher als gar keines.
    def resolve_players(row)
      participations = row["participations"]
      return nil unless participations.is_a?(Array) && participations.size == 2

      pairs = participations.map do |participation|
        [participation, Player.find_by(dbu_nr: participation["dbu_nr"].to_s)]
      end
      return nil if pairs.any? { |_participation, player| player.nil? }

      pairs
    end

    def upsert_participation(game, participation_row, player, group)
      role = participation_row["role"].to_s
      gp = game.game_participations.find_by(role: role) || game.game_participations.new(role: role)

      gp.assign_attributes(
        player_id: player.id,
        result: participation_row["result"],
        innings: participation_row["innings"],
        gd: participation_row["gd"],
        hs: participation_row["hs"],
        data: {
          "results" => {
            "Gr." => group,
            "Ergebnis" => participation_row["result"],
            "Aufnahme" => participation_row["innings"],
            "GD" => participation_row["gd"],
            "HS" => participation_row["hs"]
          }.compact
        }
      )
      gp.region_id = @tournament.region_id
      gp.save!
    end

    def row_label(row)
      group = row["group"].presence || "(ohne Gruppe)"
      seqno = row["seqno"].presence || "?"
      numbers = Array(row["participations"]).map { |p| p["dbu_nr"].presence || "fehlt" }.join(" vs ")
      "#{group} / Partie #{seqno} (DBU #{numbers})"
    end
  end
end
