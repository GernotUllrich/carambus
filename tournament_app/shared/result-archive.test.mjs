// Node-Test der Ergebnisarchiv-Normalisierer im gemeinsamen Kern:
//   node shared/result-archive.test.mjs
// Geprueft werden genau die vier Bedingungen, die die Carambus-Anzeige
// (app/views/tournaments/show.html.erb) stellt — drei davon schlagen dort STILL fehl,
// deshalb muessen sie hier festgenagelt sein. Vertrag:
// HANDOFF-to-carambus-tournament-result-archive.md
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const src = readFileSync(join(here, "carambus-core.js"), "utf8");
const win = {};
new Function("window", "localStorage", "document", src)(win, { getItem: () => null, setItem: () => {} }, undefined);
const { buildResultStandings, buildResultGames } = win.Carambus.util;

let failures = 0;
const assert = (c, m) => { if (!c) { console.error("  ✗ " + m); failures++; } else console.log("  ✓ " + m); };
const keysOf = rows => rows.map(r => Object.keys(r.columns).join("|"));

console.log("Endstand (buildResultStandings):");
{
  // Zeile 2 hat eine Spalte weniger und keinen Player — der internationale Gast-Fall.
  const out = buildResultStandings([
    { player: { cc_id: 18522, lastname: "Jetten", firstname: "Karina" }, rank: 1,
      columns: { Rang: "1", Name: "Jetten, Karina", Land: "NL", Punkte: "10", GD: "1,250" } },
    { player: null, rank: 2, columns: { Rang: "2", Name: "Buelens, Jaimie", Punkte: "8" } }
  ]);
  const ks = keysOf(out);
  assert(ks[0] === ks[1], "alle Zeilen tragen dieselben Keys in derselben Reihenfolge");
  assert(out[1].columns.Land === "", "fehlender Wert wird zu Leerstring, nicht null/undefined");
  assert(typeof out[0].columns.Rank === "number" && out[0].columns.Rank === 1, "Rank ist Integer");
  assert(out[1].player === null, "Zeile ohne aufgeloesten Player bleibt erhalten (AK-6)");
  const noRank = buildResultStandings([{ columns: { Name: "A" } }, { columns: { Name: "B" } }]);
  assert(noRank[1].columns.Rank === 2, "fehlender rank faellt auf die Position zurueck");
}

console.log("Spiele (buildResultGames):");
{
  const out = buildResultGames([
    { gname: "R1.1", seqno: 1, round_no: 1, table_no: 1,
      columns: { Partie: "1", Spiel: "Gruppe 1", "Spieler A": "Jetten", "Spieler B": "Traem",
                 Ergebnis: "15:11", "Aufn. A": "14", "HS A": "6" } },
    { gname: "R1.2", seqno: 2, round_no: 1,
      columns: { Spiel: "Gruppe 1", "Spieler A": "Buelens", "Spieler B": "Michalkowa" } }
  ]);
  const ks = keysOf(out);
  assert(ks[0] === ks[1], "alle Spielzeilen tragen dieselben Keys");
  assert(out[1].columns.Ergebnis === "—", "Zeile ohne Ergebnis bekommt einen Strich statt still zu verschwinden");
  assert(/^\d+$/.test(String(out[1].columns.Partie)), "Partie ist immer eine Zahl (Sortierung via to_i)");
  assert(out[1].columns.Partie === "2", "fehlende Partie wird aus der Position ergaenzt");
  assert(!("Heim" in out[0].columns) && !("Gast" in out[0].columns),
         "keine Heim/Gast-Spalten bei Einzelturnieren (leere brechen die Zeile ab)");
  assert(out[1].table_no === null, "fehlendes table_no wird explizit null");
  const bare = buildResultGames([{ columns: { Ergebnis: "1:0" } }]);
  assert(bare[0].gname === "g1" && bare[0].seqno === 1, "gname/seqno fallen auf die Position zurueck");
}

console.log(failures === 0 ? "\n✅ alle Zusicherungen erfuellt" : `\n❌ ${failures} Fehler`);
process.exit(failures === 0 ? 0 : 1);
