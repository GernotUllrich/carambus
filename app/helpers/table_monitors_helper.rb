module TableMonitorsHelper
  def ranking_table(tournament_monitor, hash, opts = {})
    rankings = TournamentMonitor.ranking(hash, opts)
    var = opts[:reverse]
    rankings = rankings.reverse if var
    bg = opts[:bg].presence || "bg-white dark:bg-black"
    lines = rankings.map do |player, results|
      "<tr>" + (if opts[:order].include?(:rank)
                  "<td>#{results["rank"]}</td>"
                end).to_s + "<td>#{Player[player].andand.shortname}</td><td>#{results["points"]}</td><td>#{results["result"]}#{if opts[:points_only].blank?
                                                                                                                                 "</td><td>#{results["innings"]}</td><td>#{results["hs"]}</td><td>#{results["gd"]}</td><td>#{results["bed"]}</td>#{if tournament_monitor.tournament.handicap_tournier?
                                                                                                                                                                                                                                                     "<td>#{results["balls_goal"]}</td><td>#{results["gd_pct"]}</td>"
                                                                                                                                                                                                                                                   end}"
                                                                                                                               end}
</tr>"
    end.join("\n")
    ("
      <div class=\"p-8 #{bg}\">#{if opts[:group].present?
                                   "#{opts[:group]}<br/>"
                                 end}<table class='w-full'><thead><tr>" + (if opts[:order].include?(:rank)
                                                              "<th>Rank</th>"
                                                            end).to_s + "<th>Name</th><th>Pkt</th><th>Res</th>#{if opts[:points_only].blank?
                                                                                                                  "<th>Aufn.</th><th>HS</th><th>GD</th><th>BED</th>#{if tournament_monitor.tournament.handicap_tournier?
                                                                                                                                                                       "<th>BG</th><th>GD_PCT</th>"
                                                                                                                                                                     end}"
                                                                                                                end}</tr></thead><tbody></tbody>#{lines.html_safe}</table></div>").html_safe
  end
end
