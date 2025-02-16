class TableMonitorJob < ApplicationJob
  include CableReady::Broadcaster
  queue_as :default

  def perform(*args)
    debug = true # Rails.env != 'production'
    table_monitor = args[0]
    info = "perf +++++++!!!! C: PERFORM JOB #{Time.now} TM[#{table_monitor.id}]"
    Rails.logger.info info if debug
    case args[1]
    when "party_monitor_scores"
      row = table_monitor.data["row"]
      r_no = table_monitor.game.andand.round_no
      row_nr = table_monitor.data["row_nr"]
      t_no = table_monitor.data["t_no"] + 1
      party_monitor = table_monitor.tournament_monitor
      party = party_monitor.party
      league = party.league
      assigned_players_a_ids = party_monitor.data["assigned_players_a_ids"]
      assigned_players_b_ids = party_monitor.data["assigned_players_b_ids"]

      available_fitting_table_ids = party.location.andand.tables.andand.joins(table_kind: :disciplines).andand.where(disciplines: { id: league.discipline_id }).andand.order("name").andand.map(&:id).to_a

      players = GameParticipation.joins(:game).joins("left outer join parties on parties.id = games.tournament_id")
                                 .where(games: { tournament_id: party.id, tournament_type: "Party" }).map(&:player).uniq
      players_hash = players.each_with_object({}) do |player, memo|
        memo[player.id] = player
      end
      table_ids = Array(party_monitor.data[:table_ids].andand[r_no - 1])
      cable_ready["table-monitor-stream"].inner_html(
        selector: "#party_monitor_scores_#{row_nr}",
        html: ApplicationController.render(
          partial: "party_monitors/game_row",
          locals: {
            rendered_from: "TableMonitorJob",
            row: row,
            r_no: r_no,
            row_nr: row_nr,
            t_no: t_no,
            table_ids: table_ids,
            players_hash: players_hash,
            party_monitor: party_monitor,
            assigned_players_a_ids: assigned_players_a_ids,
            assigned_players_b_ids: assigned_players_b_ids,
            available_fitting_table_ids: available_fitting_table_ids
          }
        )
      )
      # cable_ready.broadcast
    when "teaser"
      cable_ready["table-monitor-stream"].inner_html(
        selector: "#teaser_#{table_monitor.id}",
        html: ApplicationController.render(
          partial: "table_monitors/teaser",
          locals: { table_monitor: table_monitor }
        )
      )
      # cable_ready.broadcast
    when "table_scores"
      cable_ready["table-monitor-stream"].inner_html(
        selector: "#table_scores",
        html: ApplicationController.render(
          partial: "locations/table_scores",
          locals: { table_monitor: table_monitor, table_kinds: table_monitor.table.location.table_kinds }
        )
      )
    else
      show = case table_monitor.data["free_game_form"]
             when "pool"
               "_pool"
             when "snooker"
               "_snooker"
             else
               ""
             end

      full_screen_html = ApplicationController.render(
        partial: "table_monitors/show#{show}",
        locals: { table_monitor: table_monitor, full_screen: true }
      )
      Rails.logger.info " ########### table_monitor#show id: #{table_monitor.andand.id} ###########" if debug

      cable_ready["table-monitor-stream"].inner_html(
        selector: "#full_screen_table_monitor_#{table_monitor.id}",
        html: full_screen_html
      )
      if table_monitor.tournament_monitor.present? && false
        html_current_games = ApplicationController.render(
          partial: "tournament_monitors/current_games",
          locals: { tournament_monitor: table_monitor.tournament_monitor }
        )
        cable_ready["table-monitor-stream"].inner_html(
          selector: "#tournament_monitor_current_games_#{table_monitor.tournament_monitor.id}",
          html: html_current_games
        )
        html = ApplicationController.render(
          partial: "table_monitors/show#{show}",
          locals: { table_monitor: table_monitor, full_screen: false }
        )
        cable_ready["table-monitor-stream"].inner_html(
          selector: "#table_monitor_#{table_monitor.id}",
          html: html
        )

      end
    end
    cable_ready.broadcast
  end
end
