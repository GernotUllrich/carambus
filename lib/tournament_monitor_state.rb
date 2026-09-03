# frozen_string_literal: true

module TournamentMonitorState
  # Entscheidet, ob die Runde weiterschalten darf (Gate in
  # TournamentMonitor::ResultProcessor#advance_round_after_match_close).
  #
  # Plan 06-01 (2026-09-03): Die Frage gilt den SPIELEN der Runde, nicht dem Zustand der
  # Tische. Die frueher alleinige Tisch-Pruefung (unten, jetzt Fallback) hat drei
  # Blindstellen, auf denen Tische "fertig" aussehen, obwohl Spiele offen sind:
  #
  #   1. `finalize_round` setzt nach `close_match!` `game_id: nil`, laesst den State aber
  #      stehen; das `joins(:game)` (INNER JOIN) blendet solche Tische aus. Genau das stand
  #      nach dem Vorfall vom 2026-09-03 in der DB: drei Tische in state="playing" ohne Spiel.
  #   2. `do_placement` bricht bei Tischmangel ab — das Spiel der Runde ist unbeendet, liegt
  #      aber auf keinem Tisch.
  #   3. Im continuous_placements-Pfad wird ein laufendes Spiel vom Tisch verdraengt und in
  #      `tmp_results` geparkt; auch dieses Spiel ist offen, der Tisch sieht frei aus.
  #
  # ⚠️ Der Fallback ist keine Bequemlichkeit, sondern Pflicht: `round_no` ist nur bei
  # Spielen gesetzt, die ueber `do_placement` laufen (Datenstand 2026-09-03: 55 von 2497
  # lokalen Live-Games; innerhalb von TournamentMonitor-Turnieren dagegen lueckenlos).
  # Ohne Spiele der aktuellen Runde waere die Spiel-Pruefung eine leere Menge — `none?`
  # traefe trivial zu und die Runde schaltete BEDINGUNGSLOS weiter. Deshalb greift sie nur,
  # wenn es fuer diese Runde ueberhaupt Spiele gibt; sonst entscheidet weiterhin der Tisch.
  def all_table_monitors_finished?
    round_games = live_games.where(round_no: current_round)
    return round_games.where(ended_at: nil).none? if round_games.exists?

    !(table_monitors.joins(:game).map(&:state) & %w[warmup warmup_a warmup_b
                                                    match_shootout playing final_set_score set_over]).present?
  end

  def finalize_round
    # TableMonitor e.g.
    # {
    #   "playera": {
    #     "result": 21,
    #     "innings": [1,0,3,2,2,0,13]
    #     "innings_count": 7,
    #     "hs": 10,
    #     "gd": "3.00",
    #     "balls_goal": 11,
    #     "innings_goal": 20
    #   },
    #   "playerb": {
    #     "result": 30,
    #     "innings": [10,0,3,2,2,0,13]
    #     "innings_count": 7,
    #     "hs": 20,
    #     "gd": "4.29",
    #     "balls_goal": 80,
    #     "innings_goal": 20
    #   },
    #   "current_inning": {
    #     "active_player": "playera",
    #     "balls": 0
    #   },
    # }
    # finalize gameParticipation data
    #
    # "results": {
    #     "Gr.": "Satz 1",
    #     "Ergebnis": 50,
    #     "Aufnahme": 32,
    #     "GD": 1.56,
    #     "HS": 6
    # }
    table_monitors.joins(:game).each do |tabmon|
      game = tabmon.game
      # Plan 06-01 (2026-09-03, Checkpoint-Befund): `game.data.present?` ist der falsche
      # Test. `data` wird nur als NEBENEFFEKT gefuellt — `tmp_results`, wenn ein Folgespiel
      # das Spiel vom Tisch verdraengt (do_placement), oder `tiebreak_required` bei einem
      # Tiebreak. Das jeweils LETZTE Spiel auf einem Tisch wird nie verdraengt und hat ohne
      # Tiebreak leeres `data`; es wurde hier uebersprungen, `game_id` blieb am Tisch
      # stehen. Folge im Betrieb: die Ergebnistabelle zeigt fuer diese Spiele weiterhin
      # Eingabefelder (`editable_game = game.table_monitor.present?`), obwohl das Turnier
      # abgeschlossen ist — beobachtet am "1. Vorgabepokal" bei den Spielen um Platz 3/4,
      # 5/6 und 7/8. Entscheidend ist, ob das Spiel BEENDET ist; `data` bleibt als
      # zusaetzliches Kriterium erhalten, damit bespielte Spiele ohne `ended_at` weiterhin
      # abgeraeumt werden.
      next unless game.present? && (game.data.present? || game.ended_at.present?)

      # NOTE: update_game_participations wurde bereits in finalize_game_result aufgerufen!
      # Hier nochmal aufzurufen würde Race-Conditions verursachen, weil populate_tables
      # die TableMonitors zu neuen Games reassignen könnte.
      # update_game_participations(tabmon)

      # noinspection RubyResolve
      tabmon.close_match!
      tabmon.update(game_id: nil)
    end
    accumulate_results
  end

  # Plan 41-02: die lokalen SPIELBAREN Spiele dieses Turniers — ohne die Archiv-Zeilen, die
  # carambus_app per tournament_result pusht (bewusst nach JEDER Runde, also waehrend hier
  # noch gezaehlt wird).
  #
  # ⚠️ NICHT `where.not(type: "ArchivedGame")`: bei STI ist `type` fuer gewoehnliche Games
  # NULL, und `NOT (type = 'x')` ist in SQL bei NULL nicht wahr — die Live-Games fielen mit
  # heraus und beide Zaehler waeren 0 (also faelschlich "fertig"). Deshalb der explizite
  # IS-NULL-Zweig. `InternationalGame` bleibt absichtlich drin: ausgeschlossen wird nur das
  # Archiv, nicht jede Unterklasse.
  def live_games
    tournament.games
      .where("games.id >= #{Game::MIN_ID}")
      .where("games.type IS NULL OR games.type != ?", "ArchivedGame")
  end

  def group_phase_finished?
    n_group_games = live_games.where("gname ilike 'group%'").count
    n_group_games_done = live_games.where("gname ilike 'group%'").where.not(ended_at: nil).count
    n_group_games == n_group_games_done
  end

  # Der kritische Fall fuer das Archiv: bei gesetztem `GK` ist `n_games` ein FESTER Sollwert,
  # waehrend Archiv-Games mit `ended_at` nur `n_games_done` erhoehen wuerden. Die Gleichheit
  # traefe dann nie zu und das Turnier koennte seine Endphase nicht abschliessen.
  def finals_finished?
    executor_params = JSON.parse(tournament.tournament_plan.executor_params)
    n_games = executor_params["GK"] || live_games.count
    n_games_done = live_games.where.not(ended_at: nil).count
    n_games == n_games_done
  end

  def table_monitors_ready?
    Tournament.logger.info "[tmon-table_monitors_ready]..."
    # noinspection RubyResolve
    res = table_monitors.inject(true) do |memo, tm|
      memo = memo && tm.ready? || tm.ready_for_new_match? || tm.playing?
      memo.presence
    end
    Tournament.logger.info "returns #{res}...[tmon-table_monitors_ready]"
    res
  end
end
