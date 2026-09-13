// tools/check-core-sync.mjs — verifiziert, dass der inline-Kern aller self-contained
// Dateien mit shared/ übereinstimmt (kein Schreiben). Exit 1 bei Drift.
// Dünner Wrapper um `sync-core.mjs --check` (für CI / Pre-Commit).
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const r = spawnSync(process.execPath, [join(here, "sync-core.mjs"), "--check"], { stdio: "inherit" });
process.exit(r.status ?? 1);
