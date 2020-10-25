module TableMonitorsHelper

  def ranking_table(hash, opts = {})
    lines = TournamentMonitor.ranking(hash, opts).map do |player, results|
      "<tr><td>#{Player[player].lastname}</td><td>#{results["points"]}</td><td>#{results["result"]}</td><td>#{results["innings"]}</td><td>#{results["hs"]}</td><td>#{results["gd"]}</td><td>#{results["bed"]}</td>
</tr>"
    end.join("\n")
    return "<table><thead><tr><td>Name</td><td>Points</td><td>Result</td><td>Innings</td><td>HS</td><td>GD</td><td>BED</td></tr></thead><tbody></tbody>#{lines.html_safe}</table>".html_safe
  end
end