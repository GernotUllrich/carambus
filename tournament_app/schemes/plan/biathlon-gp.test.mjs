// Node-Test: DBU Grand Prix Biathlon (Teilungsliste 4 Billards, 10–32 Starter).
//   node schemes/plan/biathlon-gp.test.mjs
// Prüft den Plan-Generator gegen die Teilungsliste (DBU-Ausschreibung 712.pdf, Seite 3),
// die drei Blöcke im Durchlauf und die Biathlon-Variante je Phase.
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
const here = dirname(fileURLToPath(import.meta.url));
const html = readFileSync(join(here, "index.html"), "utf8");
const S = "/* >>> PLAN-ENGINE >>> */", E = "/* <<< PLAN-ENGINE <<< */";
const si = html.indexOf(S), ei = html.indexOf(E, si + S.length);
if (si < 0 || ei < 0) { console.error("PLAN-ENGINE-Block in index.html nicht gefunden"); process.exit(1); }
const { parsePlan, biathlonGpPlan, biathlonVariant, createRun, runReadyGames, recordResult, finalRanking, runFinished } =
  new Function(html.slice(si + S.length, ei) + "\n;return { parsePlan, biathlonGpPlan, biathlonVariant, createRun, runReadyGames, recordResult, finalRanking, runFinished };")();

let failures = 0;
const assert = (c, m) => { if (!c) { console.error("  ✗ " + m); failures++; } };
const eq = (a, b, m) => assert(JSON.stringify(a) === JSON.stringify(b), `${m} (ist ${JSON.stringify(a)}, soll ${JSON.stringify(b)})`);

// Teilungsliste: Starter → [Gruppengrößen, Gruppenspiele, Variante Gruppe, Quali-Spiele]
// 31: die Liste nennt 48 Spiele; 7×4 + 1×3 ergibt 45 (Entscheidung Betreiber 06.10.2026).
const LIST = {
  32: [[4,4,4,4,4,4,4,4], 48, "10/15/120", 0], 31: [[4,4,4,4,4,4,4,3], 45, "10/15/120", 1],
  30: [[4,4,4,4,4,4,3,3], 42, "10/15/120", 2], 29: [[4,4,4,4,4,3,3,3], 39, "10/20/120", 3],
  28: [[4,4,4,4,3,3,3,3], 36, "10/20/120", 4], 27: [[4,4,4,3,3,3,3,3], 33, "10/20/120", 5],
  26: [[4,4,3,3,3,3,3,3], 30, "10/20/120", 6], 25: [[4,3,3,3,3,3,3,3], 27, "15/20/180", 7],
  24: [[3,3,3,3,3,3,3,3], 24, "15/20/180", 8],
  23: [[6,6,6,5], 55, "10/15/120", 0], 22: [[6,6,5,5], 50, "10/15/120", 0], 21: [[6,5,5,5], 45, "10/15/120", 0],
  20: [[5,5,5,5], 40, "10/20/120", 0], 19: [[5,5,5,4], 36, "10/20/120", 0], 18: [[5,5,4,4], 32, "10/20/120", 0],
  17: [[5,4,4,4], 28, "15/20/180", 0], 16: [[4,4,4,4], 24, "15/20/180", 0],
  15: [[8,7], 49, "10/15/120", 0], 14: [[7,7], 42, "10/15/120", 0], 13: [[7,6], 36, "10/20/120", 0],
  12: [[6,6], 30, "10/20/120", 0], 11: [[6,5], 25, "15/30/180", 0], 10: [[5,5], 20, "15/30/180", 0]
};

console.log("Teilungsliste (10–32 Starter):");
for (let n = 10; n <= 32; n++) {
  const [sizes, groupGames, gVar, nQuali] = LIST[n];
  const plan = parsePlan(biathlonGpPlan(n));
  const ko = n >= 24 ? 15 : 7; // AF 8 + VF 4 + HF 2 + F 1 bzw. VF 4 + HF 2 + F 1
  eq(plan.groups.map(g => g.pl), sizes, `${n}: Gruppengrößen`);
  eq(plan.games.filter(g => g.kind === "group").length, groupGames, `${n}: Gruppenspiele`);
  eq(plan.games.filter(g => g.key.startsWith("quali")).length, nQuali, `${n}: Quali-Spiele`);
  eq(plan.games.length, groupGames + nQuali + ko, `${n}: Spiele gesamt`);
  eq(plan.games.length, plan.gk, `${n}: GK passt`);
  eq(plan.rk.length, n, `${n}: Endstand hat ${n} Plätze`);
  eq(plan.biathlon.g, gVar, `${n}: Variante Gruppe`);
  assert(!plan.games.some(g => g.key.startsWith("p<")), `${n}: kein Spiel um Platz 3`);
}
{
  let threw = 0; for (const n of [9, 33, 0]) { try { biathlonGpPlan(n); } catch (_) { threw++; } }
  eq(threw, 3, "außerhalb 10–32 wird abgelehnt");
}

console.log("\nVariante je Phase:");
{
  const plan = parsePlan(biathlonGpPlan(28));
  const v = key => biathlonVariant(plan, plan.games.find(g => g.key === key))?.label;
  eq(biathlonVariant(plan, plan.games.find(g => g.kind === "group")), { label: "10/20/120", balls_goal_3b: 10, innings_goal_3b: 20, balls_goal: 120 }, "Gruppe 28 Starter");
  eq(v("quali5"), "10/15/120", "Quali");
  eq(v("8f1"), "10/20/120", "Achtelfinale");
  eq([v("qf1"), v("hf2"), v("fin")], ["15/30/180", "15/30/180", "15/30/180"], "Viertelfinale bis Finale");
  const b = parsePlan(biathlonGpPlan(16));
  eq(biathlonVariant(b, b.games.find(g => g.kind === "group")).label, "15/20/180", "Gruppe 16 Starter");
  eq(biathlonVariant(b, b.games.find(g => g.key === "qf1")).label, "15/30/180", "Block B: Viertelfinale");
  eq(biathlonVariant(parsePlan('{"g1":{"pl":3,"rs":"eae","sq":["1-2","1-3","2-3"]}}'), { kind: "group" }), null, "Plan ohne Biathlon → keine Variante");
}

// Durchlauf: der kleinere Setzplatz gewinnt jedes Spiel.
function simulate(n, check) {
  const plan = parsePlan(biathlonGpPlan(n));
  const players = Array.from({ length: n }, (_, i) => ({ seed: i + 1, pid: "s" + (i + 1) }));
  const run = createRun(plan, players);
  let guard = 0;
  while (!runFinished(run) && guard++ < 500) {
    const ready = runReadyGames(run);
    if (!ready.length) { assert(false, `${n}: Durchlauf hängt`); break; }
    for (const g of ready) {
      check?.(run, g);
      const goal = biathlonVariant(plan, g).balls_goal;
      const aWins = g.playerA.seed < g.playerB.seed;
      recordResult(run, g.key, { a: { balls: aWins ? goal : goal / 2, innings: 10 }, b: { balls: aWins ? goal / 2 : goal, innings: 10 } });
    }
  }
  return run;
}
const seedsOf = (run, n) => run.groups[n].map(p => p.seed);
const finalSeeds = run => finalRanking(run).map(r => r.player?.seed ?? null);
const placesOf = run => finalRanking(run).map(r => r.place);
const allDone = (run, pred) => run.plan.games.filter(pred).every(g => run.results[g.key]);

console.log("\nBlock A — 28 Starter (8 Gruppen, 4 Quali, Achtelfinale):");
{
  let gateOk = true;
  const run = simulate(28, (r, g) => { if (/^8f/.test(g.key) && !allDone(r, x => x.kind === "group" || x.key.startsWith("quali"))) gateOk = false; });
  assert(gateOk, "Achtelfinale erst nach allen Gruppen- und Quali-Spielen");
  eq(seedsOf(run, 1), [1, 16, 17, 25], "Gruppe 1: Schlange + 4. Spieler vorn");
  eq(seedsOf(run, 8), [8, 9, 24], "Gruppe 8: 3er-Gruppe");
  eq([run.results.quali5.a.seed, run.results.quali5.b.seed], [12, 21], "Quali 5 = 2. vs. 3. der Gruppe 5");
  eq([run.results["8f1"].a.seed, run.results["8f1"].b.seed], [1, 15], "AF1 = A1 vs. B2");
  eq([run.results["8f4"].a.seed, run.results["8f4"].b.seed], [7, 9], "AF4 = G1 vs. Quali-Sieger H");
  eq([run.results["8f5"].a.seed, run.results["8f5"].b.seed], [2, 16], "AF5 = B1 vs. A2");
  eq([run.results.fin.a.seed, run.results.fin.b.seed], [1, 2], "Finale 1 vs. 2");
  eq(finalSeeds(run).slice(0, 4), [1, 2, 5, 6], "Plätze 1–4 (HF-Verlierer 5 und 6)");
  eq(placesOf(run), [1, 2, 3, 3, 5, 5, 5, 5, 9, 9, 9, 9, 9, 9, 9, 9, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28], "Platzziffern");
  eq(new Set(finalSeeds(run)).size, 28, "jeder Starter genau einmal im Endstand");
  eq(finalSeeds(run).slice(16, 24).sort((a, b) => a - b), [17, 18, 19, 20, 21, 22, 23, 24], "17–24: Gruppendritte bzw. Quali-Verlierer");
}

console.log("\nBlock A — 32 und 24 Starter (Randfälle):");
{
  const r32 = simulate(32);
  eq(r32.plan.games.filter(g => g.key.startsWith("quali")).length, 0, "32: keine Quali");
  eq([r32.results["8f1"].a.seed, r32.results["8f1"].b.seed], [1, 15], "32: AF1 = A1 vs. B2");
  eq(new Set(finalSeeds(r32)).size, 32, "32: Endstand vollständig");
  const r24 = simulate(24);
  eq(Object.keys(r24.results).filter(k => k.startsWith("quali")).length, 8, "24: 8 Quali-Spiele");
  eq(new Set(finalSeeds(r24)).size, 24, "24: Endstand vollständig");
  const r31 = simulate(31);
  eq(seedsOf(r31, 8), [8, 9, 24], "31: Gruppe 8 ist die 3er-Gruppe");
  eq(new Set(finalSeeds(r31)).size, 31, "31: Endstand vollständig");
}

console.log("\nBlock B — 20 und 23 Starter (4 Gruppen, Viertelfinale):");
{
  let gateOk = true;
  const run = simulate(20, (r, g) => { if (/^qf/.test(g.key) && !allDone(r, x => x.kind === "group")) gateOk = false; });
  assert(gateOk, "Viertelfinale erst nach allen Gruppenspielen");
  eq(seedsOf(run, 1), [1, 8, 9, 16, 17], "Gruppe 1: Schlange");
  eq([run.results.qf1.a.seed, run.results.qf1.b.seed], [1, 7], "VF1 = A1 vs. B2");
  eq([run.results.qf3.a.seed, run.results.qf3.b.seed], [2, 8], "VF3 = B1 vs. A2");
  eq([run.results.hf1.a.seed, run.results.hf1.b.seed], [1, 3], "HF1 = A1 vs. C1");
  eq(placesOf(run), [1, 2, 3, 3, 5, 5, 5, 5, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20], "Platzziffern");
  eq(new Set(finalSeeds(run)).size, 20, "Endstand vollständig");
  const r23 = simulate(23);
  eq(r23.groups[4].length, 5, "23: Gruppe 4 ist die 5er-Gruppe");
  eq(seedsOf(r23, 1), [1, 8, 9, 16, 17, 21], "23: angebrochene Reihe füllt vorn");
  eq(new Set(finalSeeds(r23)).size, 23, "23: Endstand vollständig");
}

console.log("\nBlock C — 12 und 15 Starter (2 Gruppen, 1.–4. ins Viertelfinale):");
{
  const run = simulate(12);
  eq(seedsOf(run, 1), [1, 4, 5, 8, 9, 12], "Gruppe 1: Schlange");
  eq([run.results.qf1.a.seed, run.results.qf1.b.seed], [1, 7], "VF1 = A1 vs. B4");
  eq([run.results.qf2.a.seed, run.results.qf2.b.seed], [3, 5], "VF2 = B2 vs. A3");
  eq([run.results.qf4.a.seed, run.results.qf4.b.seed], [4, 6], "VF4 = A2 vs. B3");
  eq([run.results.fin.a.seed, run.results.fin.b.seed], [1, 2], "Finale A1 vs. B1");
  eq(placesOf(run), [1, 2, 3, 3, 5, 5, 5, 5, 9, 10, 11, 12], "Platzziffern");
  const num = (x, y) => x - y;
  eq([finalSeeds(run).slice(8, 10).sort(num), finalSeeds(run).slice(10).sort(num)], [[9, 10], [11, 12]], "9–10 Gruppenfünfte, 11–12 Gruppensechste");
  const r15 = simulate(15);
  eq([r15.groups[1].length, r15.groups[2].length], [8, 7], "15: 8er + 7er");
  eq(new Set(finalSeeds(r15)).size, 15, "15: Endstand vollständig");
}

console.log("\nAlle Teilnehmerzahlen laufen durch:");
for (let n = 10; n <= 32; n++) {
  const run = simulate(n);
  assert(runFinished(run), `${n}: Turnier endet`);
  eq(new Set(finalSeeds(run).filter(Boolean)).size, n, `${n}: Endstand vollständig`);
  eq(finalSeeds(run)[0], 1, `${n}: Setzplatz 1 gewinnt`);
}

console.log(failures ? `\n❌ ${failures} Fehler` : "\n✅ ALLE TESTS GRÜN");
process.exit(failures ? 1 : 0);
