// Turnieruebersicht (sb_state=tournament_scores): Die Seite rendert Teaser-Frames nur fuer Tische
// MIT Spiel, und der Kanal wendet ein Update nur an, wenn sein Selektor schon im DOM steht. Ein
// Tisch, der im laufenden Turnier erstmals belegt wird, hat keinen Frame — sein Update fiel still
// weg, und er erschien erst nach Neuladen (Betreiber, 22.10.2026). Umgekehrt blieb ein frei
// gewordener oder geloester Tisch als Kachel stehen.
//
// Die Teaser gehen ueber den gemeinsamen table-monitor-stream an jede Seite, auch fuer Training und
// fremde Turniere — ein unbekannter Teaser allein ist also kein Grund. Neu geladen wird nur, wenn
// sich die Menge der angezeigten Tische DIESES Turniers aendert. Seite und Teaser tragen dafuer
// data-Attribute (scoreboard_tournament_scores.html.erb, table_monitors/_teaser.html.erb).

// page: { tournamentMonitorIds: Set<string>, activeIds: Set<string> }
// op:   CableReady-Operation (selector "#teaser_<id>", html = gerenderter Teaser)
export function teaserChangesTournamentScores(op, page) {
  const m = /^#teaser_(\d+)$/.exec(op?.selector || "")
  if (!m || typeof op.html !== "string") return false
  const tmId = /data-tournament-monitor-id="(\d*)"/.exec(op.html)?.[1] || ""
  const hasGame = /data-has-game="true"/.test(op.html)
  const belongs = tmId !== "" && page.tournamentMonitorIds.has(tmId)
  const shown = page.activeIds.has(m[1])
  if (!shown) return belongs && hasGame
  return !belongs || !hasGame
}

export function tournamentScoresPage(doc = document) {
  const frames = [...doc.querySelectorAll("turbo-frame#teasers")]
  const ids = attr => new Set(frames.flatMap(f => (f.dataset[attr] || "").split(",").filter(Boolean)))
  return { tournamentMonitorIds: ids("tournamentMonitorId"), activeIds: ids("activeIds") }
}

let reloadScheduled = false
// Mehrere Jobs (teaser, table_scores, Spielstart beider Tische) kommen kurz hintereinander —
// einmal neu laden, nicht je Nachricht.
export function scheduleTournamentScoresReload(delayMs = 1500) {
  if (reloadScheduled) return
  reloadScheduled = true
  setTimeout(() => window.location.reload(), delayMs)
}
