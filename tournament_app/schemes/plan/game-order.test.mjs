// Node-Test: Spielfolge der Gruppenphase nach einer vorgegebenen Liste (DBU-Zeitplan).
//   node schemes/plan/game-order.test.mjs
// Testdaten: Vorrunde 23. GP Biathlon (17.10.2026, 19 Starter, 4 Gruppen), Namen anonymisiert —
// Gruppe A = Spieler A1–A5 usw. Partie-Nr. und Zeitfenster wie auf dem Zeitplan-Blatt.
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
const here = dirname(fileURLToPath(import.meta.url));
const html = readFileSync(join(here, "index.html"), "utf8");
const S = "/* >>> PLAN-ENGINE >>> */", E = "/* <<< PLAN-ENGINE <<< */";
const si = html.indexOf(S), ei = html.indexOf(E, si + S.length);
if (si < 0 || ei < 0) { console.error("PLAN-ENGINE-Block in index.html nicht gefunden"); process.exit(1); }
const { parsePlan, biathlonGpPlan, createRun, matchGameOrder, applyGameOrder, resolveSlot } =
  new Function(html.slice(si + S.length, ei) + "\n;return { parsePlan, biathlonGpPlan, createRun, matchGameOrder, applyGameOrder, resolveSlot };")();

let failures = 0;
const assert = (c, m) => { if (!c) { console.error("  ✗ " + m); failures++; } else console.log("  ✓ " + m); };
const eq = (a, b, m) => assert(JSON.stringify(a) === JSON.stringify(b), JSON.stringify(a) === JSON.stringify(b) ? m : `${m} (ist ${JSON.stringify(a)}, soll ${JSON.stringify(b)})`);

const LIST = `
1 09:00 Spieler A1 – Spieler A2
5 09:00 Spieler A3 – Spieler A4
2 09:00 Spieler B1 – Spieler B2
6 09:00 Spieler B3 – Spieler B4
3 10:00 Spieler C1 – Spieler C2
7 10:00 Spieler C3 – Spieler C4
4 10:00 Spieler D1 – Spieler D2
8 10:00 Spieler D3 – Spieler D4
9 11:00 Spieler A4 – Spieler A1
13 11:00 Spieler A5 – Spieler A2
10 11:00 Spieler B3 – Spieler B2
14 11:00 Spieler B5 – Spieler B4
11 12:00 Spieler C3 – Spieler C2
15 12:00 Spieler C5 – Spieler C4
17 12:00 Spieler A5 – Spieler A1
21 12:00 Spieler A3 – Spieler A2
18 13:00 Spieler B2 – Spieler B4
22 13:00 Spieler B5 – Spieler B1
19 13:00 Spieler C2 – Spieler C4
23 13:00 Spieler C5 – Spieler C1
12 14:00 Spieler D1 – Spieler D4
16 14:00 Spieler D3 – Spieler D2
25 14:00 Spieler A5 – Spieler A4
28 14:00 Spieler A3 – Spieler A1
26 15:00 Spieler B3 – Spieler B1
29 15:00 Spieler B5 – Spieler B2
27 15:00 Spieler C3 – Spieler C1
30 15:00 Spieler C5 – Spieler C2
31 16:00 Spieler A4 – Spieler A2
34 16:00 Spieler A3 – Spieler A5
32 16:00 Spieler B1 – Spieler B4
35 16:00 Spieler B5 – Spieler B3
33 17:00 Spieler C1 – Spieler C4
36 17:00 Spieler C5 – Spieler C3
20 17:00 Spieler D2 – Spieler D4
24 17:00 Spieler D3 – Spieler D1
`;

// Run mit den Gruppen des Zeitplans (die Gruppeneinteilung selbst prüft biathlon-gp.test.mjs)
function makeRun(extra = []) {
  const P = (g, i) => ({ firstname: "Spieler", lastname: g + i, pid: g + i });
  const groups = { 1: [1, 2, 3, 4, 5].map(i => P("A", i)), 2: [1, 2, 3, 4, 5].map(i => P("B", i)), 3: [1, 2, 3, 4, 5].map(i => P("C", i)), 4: [1, 2, 3, 4].map(i => P("D", i)) };
  extra.forEach(([n, p]) => groups[n].push(p));
  const players = Object.values(groups).flat().map((p, i) => ({ ...p, seed: i + 1 }));
  const run = createRun(parsePlan(biathlonGpPlan(19)), players);
  run.groups = groups;
  return run;
}

console.log("Zeitplan GP 17.10. (36 Partien, 9 Zeitfenster):");
{
  const run = makeRun();
  const r = matchGameOrder(run, LIST);
  eq([r.order.length, r.unmatched.length, r.missing.length], [36, 0, 0], "alle 36 Partien zugeordnet, nichts übrig");
  eq(r.order.map(o => o.no).slice(0, 8), [1, 5, 2, 6, 3, 7, 4, 8], "Reihenfolge = Listenreihenfolge");
  eq([...new Set(r.order.map(o => o.round))], [1, 2, 3, 4, 5, 6, 7, 8, 9], "Runde = Zeitfenster 09:00 … 17:00");
  eq(r.order.filter(o => o.round === 1).map(o => o.no), [1, 5, 2, 6], "09:00 = Partien 1, 5, 2, 6");
  const plan = applyGameOrder(parsePlan(biathlonGpPlan(19)), r.order);
  const g = k => plan.games.find(x => x.key === k);
  eq([g(r.order[0].key).round, g(r.order[0].key).listNo, g(r.order[35].key).round, g(r.order[35].key).listNo], [1, 1, 9, 24], "Runde und Partie-Nr. am Spiel");
  eq(["qf1", "hf1", "fin"].map(k => g(k).round), [10, 11, 12], "KO zählt hinter der letzten Gruppenrunde weiter");
  // niemand zweimal im selben Zeitfenster
  const clash = [...new Set(r.order.map(o => o.round))].filter(rd => {
    const ps = r.order.filter(o => o.round === rd).flatMap(o => { const x = run.plan.games.find(y => y.key === o.key); return [resolveSlot(run, x.a).pid, resolveSlot(run, x.b).pid]; });
    return ps.length !== new Set(ps).size; });
  eq(clash, [], "kein Spieler zweimal im selben Zeitfenster");
}

console.log("\nZuordnung und Meldungen:");
{
  const run = makeRun();
  eq(matchGameOrder(run, "1 09:00 A1 – A2").order.length, 1, "Nachname allein genügt");
  eq(matchGameOrder(run, "1 A1 – A2\n2 A3 – A4\n3 B1 – B2\n4 B3 – B4\n5 C1 – C2").order.map(o => o.round), [1, 1, 1, 1, 2], "ohne Zeiten: Blöcke zu 4 Partien (Tische)");
  eq(matchGameOrder(run, "1 A1 – A2\n2 A3 – A4\n3 B1 – B2", { tables: 2 }).order.map(o => o.round), [1, 1, 2], "ohne Zeiten: Blockgröße = Tischzahl");
  const bad = matchGameOrder(run, [
    "1 09:00 Spieler A1 – Spieler B1",   // verschiedene Gruppen
    "2 09:00 Spieler A1 – Niemand",      // unbekannt
    "3 09:00 Spieler A1 – Spieler A2",
    "4 10:00 Spieler A2 – Spieler A1",   // doppelt (andere Reihenfolge)
    "Pause 12:00"                        // keine Partie-Zeile
  ].join("\n"));
  eq(bad.order.map(o => o.no), [3], "nur die gültige Zeile wird übernommen");
  eq(bad.unmatched.map(u => u.reason.split(" ")[0]), ["keine", "„Niemand“", "Partie", "Zeile"], "jede andere Zeile wird mit Grund gemeldet");
  eq(bad.missing.length, 35, "nicht gelistete Gruppenspiele werden gemeldet");
  const amb = matchGameOrder(makeRun([[1, { firstname: "Andere", lastname: "A2", pid: "X" }]]), "1 A1 – A2\n2 A1 – Spieler A2");
  eq([amb.unmatched.length, amb.unmatched[0]?.reason.includes("mehrdeutig"), amb.order.length], [1, true, 1], "gleicher Nachname: mehrdeutig, mit Vorname eindeutig");
  const plan = applyGameOrder(parsePlan(biathlonGpPlan(19)), matchGameOrder(run, "1 09:00 A1 – A2").order);
  const rest = plan.games.filter(x => x.kind === "group" && x.listNo == null);
  assert(rest.every(x => x.round > 1), "nicht gelistete Spiele folgen nach der Liste");
  eq(applyGameOrder(parsePlan(biathlonGpPlan(19)), []).games.find(x => x.key === "qf1").round, 6, "ohne Liste bleibt alles wie bisher");
}

console.log("\nAus Excel kopiert (Blatt „Zeitplan“ des DBU-Originals):");
{
  // So kommt das Blatt in der Zwischenablage an: Tabs zwischen den Zellen, je Partie zwei Zeilen —
  // Zeile 1: Partie, Datum, Ist-Start, Ist-Ende, Spieler, „-“, Spieler, Tisch; Zeile 2: Plan-Uhrzeit.
  // Kopfzeile, Abschnittszeilen und die KO-Platzhalter („Ranking 1“) stehen mit drin.
  const entries = LIST.trim().split("\n").map(l => /^(\d+) (\d\d:\d\d) (.+) – (.+)$/.exec(l));
  const tsv = (played) => ["Partie\tPlan\tStart\tEnde\tBegegnung\t\t\tTisch\tErgebnis", "Vorrunde"].concat(
    entries.flatMap((m, i) => [
      [m[1], "17.10.26", played ? "9:10" : "", played ? "10:04" : "", m[3], "-", m[4], String(i % 4 + 1), ""].join("\t"),
      ["", `${m[2]} Uhr`, "", "", "", "", "", "", ""].join("\t")]),
    ["", "Viertelfinale", "1001\t18.10.26\t\t\tRanking 1\t-\tRanking 8\t\t", "\t09:00 Uhr\t\t\t\t\t\t\t",
     "Halbfinale", "1005\t18.10.26\t\t\t(Gewinner aus Partie 1001)\t-\t(Gewinner aus Partie 1002)\t\t", "\t11:00 Uhr"]).join("\r\n");
  const run = makeRun();
  const ref = matchGameOrder(run, LIST);
  for (const played of [false, true]) {
    const r = matchGameOrder(run, tsv(played));
    const tag = played ? "mit Ist-Zeiten" : "leeres Blatt";
    eq([r.order.length, r.unmatched.length, r.missing.length], [36, 0, 0], `${tag}: alle 36 Partien, keine Meldung (Kopf, Abschnitte, KO-Platzhalter still übergangen)`);
    eq(r.order.map(o => [o.key, o.no, o.time, o.round]), ref.order.map(o => [o.key, o.no, o.time, o.round]), `${tag}: identisch mit dem Kurzformat — Runde aus der Plan-Uhrzeit, nicht aus der Ist-Zeit`);
  }
  // Excel schreibt die Uhrzeit auch einstellig: 9:00 und 09:00 sind dasselbe Zeitfenster
  const mixed = matchGameOrder(run, "1\t17.10.26\t\t\tSpieler A1\t-\tSpieler A2\t1\n\t9:00 Uhr\n5\t17.10.26\t\t\tSpieler A3\t-\tSpieler A4\t2\n\t09:00 Uhr");
  eq(mixed.order.map(o => o.round), [1, 1], "9:00 und 09:00 = dieselbe Runde");
  // Ohne Folgezeile (nur die Partie-Zeilen markiert): Blöcke nach Tischzahl wie im Kurzformat
  eq(matchGameOrder(run, "1\t17.10.26\t\t\tA1\t-\tA2\t1\n2\t17.10.26\t\t\tA3\t-\tA4\t2", { tables: 1 }).order.map(o => o.round), [1, 2], "ohne Plan-Uhrzeit: Blöcke nach Tischzahl");
}

console.log(failures ? `\n❌ ${failures} Fehler` : "\n✅ ALLE TESTS GRÜN");
process.exit(failures ? 1 : 0);
