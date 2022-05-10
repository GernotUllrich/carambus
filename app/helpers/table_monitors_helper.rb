module TableMonitorsHelper
  def ranking_table(hash, opts = {})
    rankings = TournamentMonitor.ranking(hash, opts)
    rankings = rankings.reverse if opts[:reverse]
    lines = rankings.map do |player, results|
      "<tr>" + "#{"<td>#{results["rank"]}</td>" if opts[:order].include?(:rank)}" + "<td>#{Player[player].andand.lastname} #{Player[player].andand.firstname[0]}.</td><td>#{results["points"]}</td><td>#{results["result"]}</td><td>#{results["innings"]}</td><td>#{results["hs"]}</td><td>#{results["gd"]}</td><td>#{results["bed"]}</td>
</tr>"
    end.join("\n")
    return ("
      <div class=\"flex space-x-20 p-4 bg-white dark:bg-black\"><table><thead><tr>" + "#{"<th>Rank</th>" if opts[:order].include?(:rank)}" + "<th>Name</th><th>Punke</th><th>Bälle</th><th>Aufn.</th><th>HS</th><th>GD</th><th>BED</th></tr></thead><tbody></tbody>#{lines.html_safe}</table></div>").html_safe
  end

end
