// ko-engine.js — generische KO-Engine für die Scheme-Registry (carambus.ko-plans/v1).
// Führt JEDEN Plan aus PoolSchemata aus: EKO (Einfach-KO), DKO (Doppel-KO inkl. Grand-Final-
// Reset) und DKO+EKO-Hybride (mit Auslosung). Reine Logik, kein DOM — testbar in Node und
// nutzbar im Browser (window.KO). Persistenz/Replay übernimmt das aufrufende Schema.
//
// Plan (aus schemes/ko/plans.json): { id, name, type, size, matches:[{nr,round,a,b,winnerRang?,loserRang?}] }
//   a/b ∈ { seed:N (+bye) } | { winnerOf:N } | { loserOf:N } | { lot:true }
//
// Spieler: Array nach Setzplatz (Index 0 = Setzplatz 1). Weniger als size ⇒ Rest = Freilos.
(function (root, factory) {
  const KO = factory();
  if (typeof module !== "undefined" && module.exports) module.exports = KO;
  if (typeof window !== "undefined") window.KO = KO;
})(this, function () {
  "use strict";
  const BYE = { __bye: true };
  const isBye = p => !!p && p.__bye === true;
  const isPlayer = p => !!p && !p.__bye;
  const pid = p => p && (p.pid ?? (p.cc_id != null ? "cc" + p.cc_id : "s" + p.seed));
  const defShuffle = a => { a = a.slice(); for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; };

  // Reset-Partie (Grand-Final-Reset): beide Slots aus DERSELBEN Partie K (Verlierer + Sieger).
  function resetSourceOf(m) {
    if (m.aRef && m.bRef && m.aRef.loserOf != null && m.bRef.winnerOf != null && m.aRef.loserOf === m.bRef.winnerOf) return m.aRef.loserOf;
    if (m.aRef && m.bRef && m.aRef.winnerOf != null && m.bRef.loserOf != null && m.aRef.winnerOf === m.bRef.loserOf) return m.aRef.winnerOf;
    return null;
  }

  function buildRun(plan, players, opts = {}) {
    const matches = new Map();
    for (const m of plan.matches) matches.set(m.nr, {
      nr: m.nr, round: m.round, aRef: m.a, bRef: m.b,
      winnerRang: m.winnerRang ?? null, loserRang: m.loserRang ?? null,
      a: null, b: null, winner: null, loser: null, loserPriorLosses: null,
      status: "pending", result: null, at: null, table: null
    });
    const run = {
      plan, players: players.slice(), matches, order: plan.matches.map(m => m.nr),
      lot: { ...(opts.lot || {}) }, losses: { ...(opts.losses || {}) }, shuffle: opts.shuffle || defShuffle
    };
    autoResolve(run);
    return run;
  }

  // Setzplatz N → realer Spieler oder Freilos (N > Spielerzahl). Eingebackene bye-Marker werden
  // bewusst ignoriert: Bye richtet sich nach der tatsächlichen Teilnehmerzahl (Standard-Setzung).
  function seedPlayer(run, n) { return (n >= 1 && n <= run.players.length) ? run.players[n - 1] : BYE; }

  function resolveRef(run, ref, nr, slot) {
    if (!ref) return null;
    if (ref.seed != null) return seedPlayer(run, ref.seed);
    if (ref.winnerOf != null) { const m = run.matches.get(ref.winnerOf); return m && (m.status === "done" || m.status === "bye") ? m.winner : null; }
    if (ref.loserOf != null) { const m = run.matches.get(ref.loserOf); return m && (m.status === "done" || m.status === "bye") ? m.loser : null; }
    if (ref.lot) return run.lot[nr + ":" + slot] || null;
    return null;
  }

  function lotSlots(run) {
    const s = [];
    for (const m of run.plan.matches) { if (m.a && m.a.lot) s.push(m.nr + ":a"); if (m.b && m.b.lot) s.push(m.nr + ":b"); }
    return s;
  }
  // Lot-Pool: Sieger von Partien, die NIRGENDS referenziert werden und keinen Sieger-Rang haben
  // (die „hängenden" Qualifikanten, die in die Auslosung gehen).
  function lotPoolMatches(run) {
    const referencedWinner = new Set();
    for (const m of run.plan.matches) for (const r of [m.a, m.b]) if (r && r.winnerOf != null) referencedWinner.add(r.winnerOf);
    return run.plan.matches.filter(m => !referencedWinner.has(m.nr) && m.winnerRang == null).map(m => m.nr);
  }
  function drawLotsIfReady(run) {
    const slots = lotSlots(run);
    if (!slots.length || slots.every(k => run.lot[k])) return;
    const pool = lotPoolMatches(run);
    if (!pool.every(nr => { const m = run.matches.get(nr); return m.status === "done" || m.status === "bye"; })) return;
    const winners = run.shuffle(pool.map(nr => run.matches.get(nr).winner).filter(isPlayer));
    slots.forEach((k, i) => { if (winners[i]) run.lot[k] = winners[i]; });
  }

  function setOutcome(run, m, winnerSlot, result, bye) {
    const loserSlot = winnerSlot === "a" ? "b" : "a";
    m.winner = m[winnerSlot]; m.loser = m[loserSlot];
    m.result = result || null;
    m.status = bye ? "bye" : "done";
    if (!bye && isPlayer(m.loser)) {
      const prev = run.losses[pid(m.loser)] || 0;
      m.loserPriorLosses = prev;
      run.losses[pid(m.loser)] = prev + 1;
    }
  }

  function autoResolve(run) {
    let changed = true;
    while (changed) {
      changed = false;
      drawLotsIfReady(run);
      for (const nr of run.order) {
        const m = run.matches.get(nr);
        if (m.status !== "pending") continue;
        // bedingte Reset-Partie: nur aktiv, wenn der Verlierer von K ungeschlagen war (0 Niederlagen)
        const rs = resetSourceOf(m);
        if (rs != null) {
          const k = run.matches.get(rs);
          if (!k || k.status !== "done") continue;
          if ((k.loserPriorLosses ?? 1) !== 0) { m.status = "skipped"; changed = true; continue; }
        }
        const a = resolveRef(run, m.aRef, nr, "a"), b = resolveRef(run, m.bRef, nr, "b");
        if (!a || !b) continue;
        m.a = a; m.b = b;
        const aB = isBye(a), bB = isBye(b);
        if (aB || bB) { setOutcome(run, m, (aB && !bB) ? "b" : "a", null, true); changed = true; }
        else { m.status = "ready"; changed = true; }
      }
    }
  }

  function readyMatches(run) { return run.order.map(nr => run.matches.get(nr)).filter(m => m.status === "ready"); }
  function runningMatches(run) { return run.order.map(nr => run.matches.get(nr)).filter(m => m.status === "running"); }

  function recordMatch(run, nr, winnerSlot, result) {
    const m = run.matches.get(nr);
    if (!m) throw new Error("Unbekannte Partie: " + nr);
    if (m.status !== "ready" && m.status !== "running") throw new Error("Partie nicht spielbereit: " + nr);
    if (winnerSlot !== "a" && winnerSlot !== "b") throw new Error("Ungültiger Sieger-Slot");
    m.at = m.at || Date.now();
    setOutcome(run, m, winnerSlot, result, false);
    autoResolve(run);
    return m;
  }
  // Sieger aus Ergebnis ableiten (mehr Bälle gewinnt; null bei Gleichstand → Schema entscheidet/los).
  function winnerFromResult(result) {
    if (!result) return null;
    const a = result.a && result.a.balls, b = result.b && result.b.balls;
    if (a == null || b == null) return null;
    return a > b ? "a" : b > a ? "b" : null;
  }

  // Endplatzierung: Rang aus dem Plan; spätere Partien (höhere nr) überschreiben provisorische Ränge.
  function placements(run) {
    const byPid = new Map();
    for (const nr of [...run.order].sort((x, y) => x - y)) {
      const m = run.matches.get(nr);
      if (m.status !== "done") continue;
      if (m.winnerRang != null && isPlayer(m.winner)) byPid.set(pid(m.winner), { player: m.winner, place: m.winnerRang });
      if (m.loserRang != null && isPlayer(m.loser)) byPid.set(pid(m.loser), { player: m.loser, place: m.loserRang });
    }
    return [...byPid.values()].sort((a, b) => a.place - b.place || (a.player.seed ?? 0) - (b.player.seed ?? 0));
  }

  function isFinished(run) {
    return run.order.every(nr => { const s = run.matches.get(nr).status; return s === "done" || s === "bye" || s === "skipped"; });
  }
  // Gespielte echte Partien (keine Freilose/Resets) in Plan-Reihenfolge — für Spiele-CSV / „Alle Spiele".
  function playedGames(run) {
    return run.order.map(nr => run.matches.get(nr)).filter(m => m.status === "done" && isPlayer(m.a) && isPlayer(m.b));
  }

  return { BYE, isBye, isPlayer, pid, buildRun, autoResolve, resolveRef, readyMatches, runningMatches, recordMatch, winnerFromResult, placements, isFinished, playedGames, resetSourceOf };
});
