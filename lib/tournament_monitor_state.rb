# frozen_string_literal: true

module TournamentMonitorState
  def all_table_monitors_finished?
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
      next unless game.present? && game.data.present?

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
