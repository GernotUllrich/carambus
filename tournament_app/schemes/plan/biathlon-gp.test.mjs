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
const { parsePlan, biathlonGpPlan, biathlonVariant, createRun, runReadyGames, recordResult, finalRanking, runFinished, seedingPlayers, rankSeedList, parseRanking, groupStandings } =
  new Function(html.slice(si + S.length, ei) + "\n;return { parsePlan, biathlonGpPlan, biathlonVariant, createRun, runReadyGames, recordResult, finalRanking, runFinished, seedingPlayers, rankSeedList, parseRanking, groupStandings };")();

let failures = 0;
const assert = (c, m) => { if (!c) { console.error("  ✗ " + m); failures++; } };
const eq = (a, b, m) => assert(JSON.stringify(a) === JSON.stringify(b), `${m} (ist ${JSON.stringify(a)}, soll ${JSON.stringify(b)})`);

// Teilungsliste: Starter → [Gruppengrößen, Gruppenspiele, Variante Gruppe, Quali-Spiele]
// Gruppengrößen in Gruppenreihenfolge nach dem Treppensystem (DBU GP Kegel § 2.3 Abs. 1): die
// angebrochene letzte Reihe läuft in ihrer Richtung weiter. Die Liste nennt nur die Anzahlen.
// 31: die Liste nennt 48 Spiele; 7×4 + 1×3 ergibt 45 (Entscheidung Betreiber 06.10.2026).
const LIST = {
  32: [[4,4,4,4,4,4,4,4], 48, "10/15/120", 0], 31: [[3,4,4,4,4,4,4,4], 45, "10/15/120", 1],
  30: [[3,3,4,4,4,4,4,4], 42, "10/15/120", 2], 29: [[3,3,3,4,4,4,4,4], 39, "10/20/120", 3],
  28: [[3,3,3,3,4,4,4,4], 36, "10/20/120", 4], 27: [[3,3,3,3,3,4,4,4], 33, "10/20/120", 5],
  26: [[3,3,3,3,3,3,4,4], 30, "10/20/120", 6], 25: [[3,3,3,3,3,3,3,4], 27, "15/20/180", 7],
  24: [[3,3,3,3,3,3,3,3], 24, "15/20/180", 8],
  23: [[5,6,6,6], 55, "10/15/120", 0], 22: [[5,5,6,6], 50, "10/15/120", 0], 21: [[5,5,5,6], 45, "10/15/120", 0],
  20: [[5,5,5,5], 40, "10/20/120", 0], 19: [[5,5,5,4], 36, "10/20/120", 0], 18: [[5,5,4,4], 32, "10/20/120", 0],
  17: [[5,4,4,4], 28, "15/20/180", 0], 16: [[4,4,4,4], 24, "15/20/180", 0],
  15: [[7,8], 49, "10/15/120", 0], 14: [[7,7], 42, "10/15/120", 0], 13: [[7,6], 36, "10/20/120", 0],
  12: [[6,6], 30, "10/20/120", 0], 11: [[5,6], 25, "15/30/180", 0], 10: [[5,5], 20, "15/30/180", 0]
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
  eq(plan.rank, "dbu-gp", `${n}: DBU-Wertung`);
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
  eq(v("quali1"), "10/15/120", "Quali");
  eq(v("8f1"), "10/20/120", "Achtelfinale");
  eq([v("qf1"), v("hf2"), v("fin")], ["15/30/180", "15/30/180", "15/30/180"], "Viertelfinale bis Finale");
  const b = parsePlan(biathlonGpPlan(16));
  eq(biathlonVariant(b, b.games.find(g => g.kind === "group")).label, "15/20/180", "Gruppe 16 Starter");
  eq(biathlonVariant(b, b.games.find(g => g.key === "qf1")).label, "15/30/180", "Block B: Viertelfinale");
  eq(biathlonVariant(parsePlan('{"g1":{"pl":3,"rs":"eae","sq":["1-2","1-3","2-3"]}}'), { kind: "group" }), null, "Plan ohne Biathlon → keine Variante");
}

console.log("\nWertung nach DBU GP Kegel § 2.2 (GD = eigene ÷ gegnerische Punkte, dann Dreiband-Punkte):");
{
  const P = id => ({ pid: id, seed: +id.slice(1) });
  const [p1, p2, p3] = [P("p1"), P("p2"), P("p3")];
  // Jeder gewinnt einmal → alle 2 Punkte. Punktverhältnis: p1 220:140, p2 230:220, p3 140:230.
  // p2 hat die wenigsten Aufnahmen — nach dem alten GD (Punkte ÷ Aufnahmen) stünde p2 vorn.
  const games = [
    { a: p1, b: p3, res: { a: { balls: 120, innings: 30 }, b: { balls: 20, innings: 30 } } },
    { a: p2, b: p1, res: { a: { balls: 120, innings: 5 }, b: { balls: 100, innings: 30 } } },
    { a: p3, b: p2, res: { a: { balls: 120, innings: 5 }, b: { balls: 110, innings: 5 } } }];
  const st = groupStandings([p1, p2, p3], games, ["points", "gdq", "b3"]);
  eq(st.map(s => s.player.pid), ["p1", "p2", "p3"], "Reihenfolge nach Punktverhältnis");
  eq(st.map(s => +s.gdq.toFixed(3)), [1.571, 1.045, 0.609], "GD = eigene ÷ gegnerische Punkte");
  eq(groupStandings([p1, p2, p3], games, ["points", "gd"])[0].player.pid, "p2", "Gegenprobe: alter GD hätte p2 vorn");
  const draw = b3 => groupStandings([p1, p2], [{ a: p1, b: p2, res: { a: { balls: 60, b3: b3[0] }, b: { balls: 60, b3: b3[1] } } }], ["points", "gdq", "b3"]).map(s => s.player.pid);
  eq([draw([5, 8]), draw([8, 5])], [["p2", "p1"], ["p1", "p2"]], "bei gleichem GD entscheiden die Dreiband-Punkte");
}

// Durchlauf: der kleinere Setzplatz gewinnt jedes Spiel; der Verlierer erzielt loserBalls(goal, seed).
function simulate(n, check, loserBalls = goal => goal / 2) {
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
      const lb = loserBalls(goal, aWins ? g.playerB.seed : g.playerA.seed);
      recordResult(run, g.key, { a: { balls: aWins ? goal : lb, innings: 10 }, b: { balls: aWins ? lb : goal, innings: 10 } });
    }
  }
  return run;
}
const seedsOf = (run, n) => run.groups[n].map(p => p.seed);
const finalSeeds = run => finalRanking(run).map(r => r.player?.seed ?? null);
const placesOf = run => finalRanking(run).map(r => r.place);
const allDone = (run, pred) => run.plan.games.filter(pred).every(g => run.results[g.key]);
const pair = (run, k) => [run.results[k].a.seed, run.results[k].b.seed];
const seq = (a, b) => Array.from({ length: b - a + 1 }, (_, i) => a + i);

console.log("\nBlock A — 28 Starter (8 Gruppen, 4 Quali, Achtelfinale):");
{
  let gateOk = true;
  const run = simulate(28, (r, g) => { if (/^8f/.test(g.key) && !allDone(r, x => x.kind === "group" || x.key.startsWith("quali"))) gateOk = false; });
  assert(gateOk, "Achtelfinale erst nach allen Gruppen- und Quali-Spielen");
  eq(seedsOf(run, 1), [1, 16, 17], "Gruppe 1: Treppensystem, 3er-Gruppe");
  eq(seedsOf(run, 8), [8, 9, 24, 25], "Gruppe 8: letzte Reihe läuft rückwärts weiter");
  eq(pair(run, "quali1"), [16, 17], "Quali 1 = 2. vs. 3. der Gruppe 1");
  // Setzung: 8 Gruppenerste, dann Zweite — 4er-Zweite (2 von 3 Partien) vor Quali-Siegern (1 von 2)
  eq(["8f1", "8f2", "8f3", "8f4", "8f5", "8f6", "8f7", "8f8"].map(k => pair(run, k)),
     [[1, 16], [8, 9], [5, 12], [4, 13], [3, 14], [6, 11], [7, 10], [2, 15]], "AF 1–16, 8–9, 5–12, 4–13, 3–14, 6–11, 7–10, 2–15");
  eq(["qf1", "qf2", "qf3", "qf4"].map(k => pair(run, k)), [[1, 8], [5, 4], [3, 6], [7, 2]], "VF 1–8, 5–4, 3–6, 7–2");
  eq([pair(run, "hf1"), pair(run, "hf2"), pair(run, "fin")], [[1, 4], [3, 2], [1, 2]], "HF und Finale");
  eq(placesOf(run), [1, 2, 3, 3, ...seq(5, 28)], "Platzziffern: nur Platz 3 geteilt");
  eq(finalSeeds(run).slice(0, 16), [1, 2, 4, 3, 5, 6, 7, 8, ...seq(9, 16)], "1–16");
  eq(finalSeeds(run).slice(16), [21, 22, 23, 24, 17, 18, 19, 20, 25, 26, 27, 28],
     "17–24: 4er-Dritte (je Partie mehr Punkte) vor Quali-Verlierern; 25–28 Vierte");
}

console.log("\nPlätze 5–16 nach dem GD des KO-Spiels (§ 2.3 Abs. 6):");
{
  // Verlierer-Punkte steigen mit dem Setzplatz: der schwächer Gesetzte hat das bessere Verhältnis
  const run = simulate(28, null, (goal, seed) => Math.round(goal * 0.3) + seed);
  eq(finalSeeds(run).slice(4, 8), [8, 7, 6, 5], "5–8: VF-Verlierer nach Punktverhältnis");
  eq(finalSeeds(run).slice(8, 16), [16, 15, 14, 13, 12, 11, 10, 9], "9–16: AF-Verlierer nach Punktverhältnis");
}

console.log("\nBlock A — 32, 24 und 31 Starter (Randfälle):");
{
  const r32 = simulate(32);
  eq(r32.plan.games.filter(g => g.key.startsWith("quali")).length, 0, "32: keine Quali");
  eq(pair(r32, "8f1"), [1, 16], "32: AF1 = 1 vs. 16");
  eq(new Set(finalSeeds(r32)).size, 32, "32: Endstand vollständig");
  const r24 = simulate(24);
  eq(Object.keys(r24.results).filter(k => k.startsWith("quali")).length, 8, "24: 8 Quali-Spiele");
  eq(new Set(finalSeeds(r24)).size, 24, "24: Endstand vollständig");
  const r31 = simulate(31);
  eq(seedsOf(r31, 1), [1, 16, 17], "31: Gruppe 1 ist die 3er-Gruppe");
  eq(new Set(finalSeeds(r31)).size, 31, "31: Endstand vollständig");
}

console.log("\nBlock B — 20 und 23 Starter (4 Gruppen, Viertelfinale):");
{
  let gateOk = true;
  const run = simulate(20, (r, g) => { if (/^qf/.test(g.key) && !allDone(r, x => x.kind === "group")) gateOk = false; });
  assert(gateOk, "Viertelfinale erst nach allen Gruppenspielen");
  eq(seedsOf(run, 1), [1, 8, 9, 16, 17], "Gruppe 1: Treppensystem");
  eq(["qf1", "qf2", "qf3", "qf4"].map(k => pair(run, k)), [[1, 8], [5, 4], [3, 6], [7, 2]], "VF 1–8, 5–4, 3–6, 7–2");
  eq(pair(run, "hf1"), [1, 4], "HF1 = Sieger VF1 vs. Sieger VF2");
  eq(placesOf(run), [1, 2, 3, 3, ...seq(5, 20)], "Platzziffern");
  eq(new Set(finalSeeds(run)).size, 20, "Endstand vollständig");
  const r23 = simulate(23);
  eq(r23.groups[1].length, 5, "23: Gruppe 1 ist die 5er-Gruppe");
  eq(seedsOf(r23, 4), [4, 5, 12, 13, 20, 21], "23: angebrochene Reihe läuft rückwärts (21 → D)");
  eq(new Set(finalSeeds(r23)).size, 23, "23: Endstand vollständig");
}

console.log("\nBlock C — 12 und 15 Starter (2 Gruppen, 1.–4. ins Viertelfinale):");
{
  const run = simulate(12);
  eq(seedsOf(run, 1), [1, 4, 5, 8, 9, 12], "Gruppe 1: Treppensystem");
  eq(["qf1", "qf2", "qf3", "qf4"].map(k => pair(run, k)), [[1, 8], [5, 4], [3, 6], [7, 2]], "VF nach Setzung 1–8 …");
  eq(pair(run, "fin"), [1, 2], "Finale");
  eq(placesOf(run), [1, 2, 3, 3, ...seq(5, 12)], "Platzziffern");
  eq(finalSeeds(run).slice(8), [9, 10, 11, 12], "9–10 Gruppenfünfte, 11–12 Gruppensechste");
  const r15 = simulate(15);
  eq([r15.groups[1].length, r15.groups[2].length], [7, 8], "15: 7er + 8er");
  eq(new Set(finalSeeds(r15)).size, 15, "15: Endstand vollständig");
}

console.log("\nMeldeliste aus Carambus (carambus.seeding/v1, 23 Meldungen):");
{
  // Wie der Server sie liefert: ein Team je Spieler, seeding_position = Setzplatz;
  // absichtlich nicht sortiert, damit die Reihenfolge aus seeding_position kommen muss.
  const order = [5, 1, 23, 12, 2, 17, 9, 3, 20, 14, 4, 8, 16, 6, 21, 10, 7, 19, 11, 13, 18, 15, 22];
  const doc = { schema: "carambus.seeding/v1", tournament: { name: "23. DBU Grand Prix Biathlon" },
    teams: order.map(k => ({ seeding_position: k, players: [{ firstname: "Spieler", lastname: "S" + k, dbu_nr: String(1000 + k) }] })) };
  const players = seedingPlayers(doc);
  eq(players.length, 23, "23 Teilnehmer");
  eq(players.map(p => p.lastname).slice(0, 3), ["S1", "S2", "S3"], "Reihenfolge nach seeding_position");
  eq(players.map(p => p.seed), Array.from({ length: 23 }, (_, i) => i + 1), "seed 1..23");
  const run = createRun(parsePlan(biathlonGpPlan(players.length)), players.map(p => ({ ...p, pid: "d" + p.dbu_nr })));
  eq([1, 2, 3, 4].map(g => run.groups[g].length), [5, 6, 6, 6], "Block B: 3×6 + 1×5");
  eq(run.groups[1].map(p => p.lastname), ["S1", "S8", "S9", "S16", "S17"], "Gruppe A = 5er-Gruppe");
  eq(run.groups[4].map(p => p.lastname), ["S4", "S5", "S12", "S13", "S20", "S21"], "Gruppe D im Treppensystem");
  eq(seedingPlayers({ teams: [{ players: [{ lastname: "X" }] }, { players: [{ lastname: "Y" }] }] }).map(p => p.lastname), ["X", "Y"], "ohne seeding_position: Lieferreihenfolge");
  eq(seedingPlayers({}).length, 0, "leere Meldeliste");
  const withClub = seedingPlayers({ teams: [{ seeding_position: 1, club: { cc_id: 42, shortname: "BC Wedel" }, players: [{ lastname: "A" }] },
    { seeding_position: 2, club: { cc_id: 7, shortname: "BC Nord" }, players: [{ lastname: "B", club_shortname: "Eigener", club_cc_id: 9 }] }] });
  eq(withClub.map(p => [p.club_shortname, p.club_cc_id]), [["BC Wedel", 42], ["Eigener", 9]], "Verein vom Team, Spielerangabe hat Vorrang");
}

console.log("\nSetzliste = Rangliste × Meldeliste:");
{
  // Aufbau wie der Text aus dem DBU-PDF (Deutsche Rangliste Biathlon): Kopfzeilen, Turnierzeilen
  // mit führender Zahl, Platz 22 vor 21, zweimal Platz 40. Namen erfunden.
  const RANKING = [
    "Deutsche Rangliste Biathlon",
    "Stand: 30.06.2026, Liste Qualifikation ZDM 2026",
    "20. DBU Grand Prix (11.- 12.10.2025, GT Buer)",
    "100% 100%",
    "Nr. Name Verein LV Punkte A B1 B2 B3 C D E",
    "1 Anton Erster BC Nord NBV 1110 110 140",
    "3 Clara Dritte SCB Mitte BLVN 975 115 70",
    "9 Hans-Jörg Schröder BC Wedel NBV 646 70 90",
    "12 Max Gabelmann MSV Ost BBBV 403 170",
    "22 Zora Zweiundzwanzig BSC West BLMR 287 65",
    "21 Erik Einundzwanzig SV Süd SBV 297 40",
    "40 Tom Vierzig BF Fehrbach BVRLP 114 65 49",
    "40 Jan Auchvierzig CV Kassel HBU 114 65 49",
    "44 Peter Müller BC Grün-Weiß Wanne BVW 100 45",
    "Seite 1 von 2"
  ].join("\n");
  eq(parseRanking(RANKING).length, 10, "Ranglisten-Zeilen erkannt (9 Spieler + Turnierzeile mit führender Zahl)");
  const P = (firstname, lastname) => ({ firstname, lastname });
  const meldeliste = [P("Ute", "Ohnerang"), P("Clara", "Dritte"), P("Jan", "Auchvierzig"), P("Anton", "Erster"),
    P("Max", "Gabel"), P("Tom", "Vierzig"), P("Zora", "Zweiundzwanzig"), P("Erik", "Einundzwanzig"),
    P("Hans Jörg", "Schröder"), P("Peter", "Mueller")];
  const r = rankSeedList(meldeliste, RANKING);
  eq(r.players.map(p => p.lastname), ["Erster", "Dritte", "Schröder", "Einundzwanzig", "Zweiundzwanzig", "Vierzig", "Auchvierzig", "Mueller", "Ohnerang", "Gabel"],
    "nach Platz; gleiche Ziffer in Ranglisten-Reihenfolge; ohne Rang in Meldereihenfolge");
  eq(r.players.map(p => p.rank), [1, 3, 9, 21, 22, 40, 40, 44, null, null], "Rang je Spieler");
  eq(r.players.map(p => p.seed), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], "seed neu vergeben");
  eq(r.ranked, 8, "8 über die Rangliste gesetzt");
  eq(r.unranked.map(p => p.lastname), ["Ohnerang", "Gabel"], "Max Gabel ist nicht Max Gabelmann");
  eq(rankSeedList(meldeliste, "").players.map(p => p.lastname), meldeliste.map(p => p.lastname), "ohne Rangliste: Meldereihenfolge");
  // Kette wie im Setup: Meldeliste vom Server → Rangliste → Gruppen
  const doc = { teams: meldeliste.map((p, i) => ({ seeding_position: i + 1, players: [p] })) };
  const run = createRun(parsePlan(biathlonGpPlan(10)), rankSeedList(seedingPlayers(doc), RANKING).players.map(p => ({ ...p, pid: p.lastname })));
  eq(run.groups[1].map(p => p.lastname), ["Erster", "Einundzwanzig", "Zweiundzwanzig", "Mueller", "Ohnerang"], "10 Starter: Gruppe A aus der gerankten Setzliste");
}

console.log("\nSchreibvarianten (zweite Stufe):");
{
  const RL = [
    "19 Detlef Bretsch Triangel Soltau NBV 367 80 50",
    "30 Karla Doppel BC Eins NBV 200",
    "31 Karli Doppel BC Zwei NBV 199",
    "12 Max Gabelmann MSV Ost BBBV 403 170",
    "5 Lena Exakt BC Nord NBV 900",
    "7 Hans-Jörg Schröder BC Wedel NBV 646"
  ].join("\n");
  const P = (firstname, lastname) => ({ firstname, lastname });
  const r = rankSeedList([P("Detlev", "Bretsch"), P("Karl", "Doppel"), P("Max", "Gabel"), P("Lena", "Exakt"), P("Hans Joerg", "Schroeder")], RL);
  eq(r.players.map(p => `${p.lastname}:${p.rank}`), ["Exakt:5", "Schroeder:7", "Bretsch:19", "Doppel:null", "Gabel:null"],
    "Detlev ↔ Detlef verknüpft; exakte Treffer unverändert");
  eq(r.fuzzy.map(f => `${f.player.firstname} ${f.player.lastname} ↔ ${f.rankName} (${f.rank})`), ["Detlev Bretsch ↔ Detlef Bretsch (19)"], "Abweichung wird gemeldet, nur diese");
  eq(r.unranked.map(p => p.lastname), ["Doppel", "Gabel"], "zwei Kandidaten (Karl ↔ Karla/Karli) → ohne Rang; Gabel ≠ Gabelmann");
  eq(r.players.map(p => p.rankVariant), [null, null, "Detlef Bretsch", null, null], "Schreibvariante steht am Spieler (für die Setzliste beim Start)");
  eq(rankSeedList([P("Detlev", "Bretschmann")], RL).fuzzy.length, 0, "Nachname muss exakt passen");
  eq(rankSeedList([P("Dietmar", "Bretsch")], RL).players[0].rank, null, "Vorname mit mehr als 1 Abweichung → kein Treffer");
  // Zeile schon exakt vergeben → nicht ein zweites Mal unscharf
  const t = rankSeedList([P("Detlef", "Bretsch"), P("Detlev", "Bretsch")], RL);
  eq(t.players.map(p => `${p.firstname}:${p.rank}`), ["Detlef:19", "Detlev:null"], "exakt vergebene Zeile wird nicht doppelt genutzt");
  eq(t.fuzzy.length, 0, "dann auch keine Meldung");
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
