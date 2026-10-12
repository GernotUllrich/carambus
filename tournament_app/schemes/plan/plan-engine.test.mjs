// Node-Test der Plan-Engine (Increment 1: Parser) gegen echte Carambus-Fixtures
// (test/fixtures/tournament_plans.yml: T04, T06).
//   node schemes/plan/plan-engine.test.mjs
// Engine lebt INLINE in index.html (self-contained, file://-tauglich). Test extrahiert
// den PLAN-ENGINE-Block und evaluiert ihn — eine Quelle, trotzdem Node-testbar.
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
const here = dirname(fileURLToPath(import.meta.url));
const html = readFileSync(join(here, "index.html"), "utf8");
const S = "/* >>> PLAN-ENGINE >>> */", E = "/* <<< PLAN-ENGINE <<< */";
const si = html.indexOf(S), ei = html.indexOf(E, si + S.length);
if (si < 0 || ei < 0) { console.error("PLAN-ENGINE-Block in index.html nicht gefunden"); process.exit(1); }
const code = html.slice(si + S.length, ei);
const api = new Function(code + "\n;return { parsePlan, groupGames: groupGamesOf, placementGames: placementGamesOf, distributeToGroups, decideGame, groupStandings, createRun, runReadyGames, recordResult, finalRanking, runFinished, runGroupStandings };")();
const { parsePlan, groupGames, placementGames, distributeToGroups, decideGame, groupStandings,
        createRun, runReadyGames, recordResult, finalRanking, runFinished, runGroupStandings } = api;

let failures = 0;
const assert = (c, m) => { if (!c) { console.error("  ✗ " + m); failures++; } };
const eq = (a, b, m) => assert(JSON.stringify(a) === JSON.stringify(b), `${m} (ist ${JSON.stringify(a)}, soll ${JSON.stringify(b)})`);

// --- T04: 5 Spieler, 1 Gruppe, jeder gegen jeden, 2 Tische ---
const T04 = '{"g1":{"pl":5,"rs":"eae","sq":{"r1":{"t1":"2-4","t2":"1-5"},"r2":{"t1":"1-4","t2":"2-3"},"r3":{"t1":"2-5","t2":"3-4"},"r4":{"t1":"1-3","t2":"4-5"},"r5":{"t1":"3-5","t2":"1-2"}}},"RK":["g1.rk1","g1.rk2","g1.rk3","g1.rk4","g1.rk5"],"GK":10}';
{
  console.log("T04 (5er Round-Robin):");
  const plan = parsePlan(T04);
  eq(plan.groups.length, 1, "1 Gruppe");
  eq(plan.groups[0].pl, 5, "pl=5");
  eq(plan.groups[0].rs, "eae", "rs=eae");
  eq(groupGames(plan).length, 10, "10 Gruppenspiele (C(5,2))");
  eq(placementGames(plan).length, 0, "keine Platzierungsspiele");
  eq(plan.games.length, plan.gk, "Spielzahl == GK");
  eq(plan.rk.length, 5, "RK hat 5 Plätze");
  // Stichprobe: r1/t1 = Positionen 2 vs 4
  const g = plan.games.find(x => x.round === 1 && x.table === "t1");
  eq([g.a, g.b], ["g1.p2", "g1.p4"], "r1/t1 = g1.p2 vs g1.p4");
  eq(g.key, "group1:2-4", "gname group1:2-4");
  // Runden 1..5 vorhanden
  eq([...new Set(plan.games.map(x => x.round))].sort(), [1, 2, 3, 4, 5], "Runden 1..5");
}

// --- T06: 6 Spieler, 2 Gruppen à 3, + Finalrunde ---
const T06 = '{"GK":11,"g1":{"pl":3,"rs":"eae","sq":{"r1":{"t1":"2-3"},"r2":{"t1":"1-3"},"r3":{"t1":"1-2"}}},"g2":{"pl":3,"rs":"eae","sq":{"r1":{"t2":"2-3"},"r2":{"t2":"1-3"},"r3":{"t2":"1-2"}}},"hf1":{"r4":{"t-rand-1-2":["g1.rk1","g2.rk2"]}},"hf2":{"r4":{"t-rand-1-2":["g2.rk1","g1.rk2"]}},"p<5-6>":{"r4":{"t3":["g1.rk3","g2.rk3"]}},"fin":{"r5":{"t-admin-1-3":["hf1.rk1","hf2.rk1"]}},"p<3-4>":{"r5":{"t-admin-1-3":["hf1.rk2","hf2.rk2"]}},"RK":["fin.rk1","fin.rk2","p<3-4>.rk1","p<3-4>.rk2","p<5-6>.rk1","p<5-6>.rk2"]}';
{
  console.log("\nT06 (2 Gruppen + Finalrunde):");
  const plan = parsePlan(T06);
  eq(plan.groups.length, 2, "2 Gruppen");
  eq(plan.groups.map(g => g.pl), [3, 3], "je 3 Spieler");
  eq(groupGames(plan).length, 6, "6 Gruppenspiele (2×3)");
  eq(placementGames(plan).length, 5, "5 Platzierungsspiele (hf1,hf2,p<5-6>,fin,p<3-4>)");
  eq(plan.games.length, plan.gk, "Spielzahl == GK (11)");
  eq(plan.rk.length, 6, "RK hat 6 Plätze");
  // hf1: g1.rk1 vs g2.rk2, Runde 4, Tisch-Token t-rand-1-2
  const hf1 = plan.games.find(x => x.key === "hf1");
  eq([hf1.a, hf1.b, hf1.round, hf1.table], ["g1.rk1", "g2.rk2", 4, "t-rand-1-2"], "hf1 korrekt");
  // fin: hf1.rk1 vs hf2.rk1
  const fin = plan.games.find(x => x.key === "fin");
  eq([fin.a, fin.b], ["hf1.rk1", "hf2.rk1"], "fin = Sieger hf1 vs Sieger hf2");
  // p<5-6>: g1.rk3 vs g2.rk3, fester Tisch t3
  const p56 = plan.games.find(x => x.key === "p<5-6>");
  eq([p56.a, p56.b, p56.table], ["g1.rk3", "g2.rk3", "t3"], "p<5-6> korrekt");
  // g2-Spiele referenzieren Gruppe 2
  const g2game = plan.games.find(x => x.kind === "group" && x.group === 2);
  assert(g2game && g2game.a.startsWith("g2.p"), "Gruppe-2-Spiele referenzieren g2");
}

// --- Default-Format (sq als Array) ---
{
  console.log("\nDefault-Format (sq Array):");
  const plan = parsePlan({ g1: { pl: 3, rs: "eae_ma", sq: ["1 - 2", "1 - 3", "2 - 3"] }, RK: ["g1.rk1", "g1.rk2", "g1.rk3"], GK: 3 });
  eq(groupGames(plan).length, 3, "3 Gruppenspiele aus Array");
  const g = plan.games[0];
  eq([g.a, g.b], ["g1.p1", "g1.p2"], "erstes Spiel g1.p1 vs g1.p2");
}

// --- Increment 2: Gruppen-Verteilung (NBV-Tabellen) ---
{
  console.log("\nGruppen-Verteilung (6 Spieler → 2×3, GROUP_RULES[6]):");
  const players = Array.from({ length: 6 }, (_, i) => ({ seed: i + 1 }));
  const g = distributeToGroups(players, 2, [3, 3]);
  eq(g[1].map(p => p.seed), [1, 4, 6], "Gruppe 1 = Setzplätze 1,4,6");
  eq(g[2].map(p => p.seed), [2, 3, 5], "Gruppe 2 = Setzplätze 2,3,5");
}

// --- Increment 3 (Kern): decideGame ---
{
  console.log("\ndecideGame (2/1/0 via result/balls_goal):");
  eq(decideGame({ a: { balls: 30 }, b: { balls: 20 } }, 30, 30).winner, "a", "höhere Bälle gewinnt");
  const d2 = decideGame({ a: { balls: 30 }, b: { balls: 30 } }, 30, 30);
  eq([d2.winner, d2.pointsA, d2.pointsB], [null, 1, 1], "Gleichstand = Remis 1/1");
  // Handicap: weniger Bälle, aber höherer Erreichungsgrad → gewinnt
  eq(decideGame({ a: { balls: 20 }, b: { balls: 25 } }, 20, 40).winner, "a", "Erreichungsgrad zählt (20/20 > 25/40)");
}

// --- Increment 3 (Kern): Gruppen-Standings (Punkte → GD) ---
{
  console.log("\ngroupStandings (Punkte → GD):");
  const [s1, s4, s6] = [{ seed: 1 }, { seed: 4 }, { seed: 6 }]; // Gruppe 1 Positionen 1,2,3
  const W = (a, b) => ({ a, b, res: { a: { balls: 30, innings: 20 }, b: { balls: 10, innings: 20 } }, ballsGoalA: 30, ballsGoalB: 30 });
  const played = [W(s4, s6), W(s1, s6), W(s1, s4)]; // s1 gewinnt 2×, s4 gewinnt vs s6
  const st = groupStandings([s1, s4, s6], played);
  eq(st.map(x => x.player.seed), [1, 4, 6], "Reihenfolge 1,4,6");
  eq(st.map(x => x.points), [4, 2, 0], "Punkte 4,2,0");
  eq(st[0].gd, 1.5, "Sieger GD = 60/40 = 1.5");
}

// --- Increment 3b: VOLLSTÄNDIGER T06-Durchlauf (Gruppen → Finalrunde → RK) ---
{
  console.log("\nT06 End-to-End (6 Spieler, kleinerer Setzplatz gewinnt):");
  const players = Array.from({ length: 6 }, (_, i) => ({ seed: i + 1 }));
  const run = createRun(parsePlan(T06), players, { ballsGoal: 30, order: ["points", "gd"] });
  // Verteilung prüfen: g1=[1,4,6], g2=[2,3,5]
  eq(run.groups[1].map(p => p.seed), [1, 4, 6], "g1 = 1,4,6");
  eq(run.groups[2].map(p => p.seed), [2, 3, 5], "g2 = 2,3,5");

  let guard = 0;
  while (!runFinished(run) && guard++ < 100) {
    const ready = runReadyGames(run);
    if (!ready.length) { console.error("  ✗ DEADLOCK: kein ready-Spiel, aber nicht fertig"); failures++; break; }
    for (const g of ready) {
      // kleinerer Setzplatz gewinnt → bekommt 30 Bälle, Gegner 10
      const aWins = g.playerA.seed < g.playerB.seed;
      recordResult(run, g.key, {
        a: { balls: aWins ? 30 : 10, innings: 20 },
        b: { balls: aWins ? 10 : 30, innings: 20 }
      });
    }
  }
  assert(runFinished(run), "Turnier abgeschlossen");
  // Zwischencheck Gruppen-Standings
  eq(runGroupStandings(run, 1).map(s => s.player.seed), [1, 4, 6], "g1-Standings 1,4,6");
  eq(runGroupStandings(run, 2).map(s => s.player.seed), [2, 3, 5], "g2-Standings 2,3,5");
  // Endplatzierung: RK = [fin.rk1, fin.rk2, p<3-4>.rk1, p<3-4>.rk2, p<5-6>.rk1, p<5-6>.rk2]
  // hf1=1v3→1, hf2=2v4→2, fin=1v2→1; p34=3v4→3; p56: g1.rk3(6) vs g2.rk3(5)→5
  const rk = finalRanking(run);
  eq(rk.map(r => r.player.seed), [1, 2, 3, 4, 5, 6], "Endplatzierung 1..6");
  eq(rk.map(r => r.place), [1, 2, 3, 4, 5, 6], "Plätze 1..6");
}

console.log("\n" + (failures === 0 ? "✅ ALLE TESTS GRÜN" : `❌ ${failures} FEHLER`));
process.exit(failures === 0 ? 0 : 1);
