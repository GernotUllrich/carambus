# Post-mortem: Quick Task 260415-26d — overcommit MkDocsBuild hook (rolled back)

**Author:** Claude (during 2026-04-15 session)
**Status:** ROLLED BACK
**Original quick task commit (now partially reverted):** `912bf72a`
**Amended version (correct public/docs/ rendered):** `0388793b`
**Rollback commit:** see `git log --grep="260415-26d"` — the commit message begins with `revert`
**Duration of investigation:** ~1 hour in-session
**Replacement approach:** deferred; CI guard in a future milestone is the current recommendation

---

## TL;DR

Quick task 260415-26d attempted to install an overcommit pre-commit hook (`MkDocsBuild`) that would run `bin/rails mkdocs:build` and auto-stage the regenerated `public/docs/**/*` files whenever any `docs/**/*.md` source file was staged. The goal was to structurally prevent the v7.0 UAT G-02 class of bug where `public/docs/` had been stale for 4 weeks without anyone noticing.

**The hook did not work.** Under certain conditions (specifically: the exact production `git commit` path with staged docs, which is the only path that matters), overcommit reports the hook ran successfully but the hook script never actually executes. The user sees `[MkDocsBuild] OK` and an apparently-green commit, while the `public/docs/` tree remains stale — exact G-02 reproduction.

The first dog-food commit (`59c0d7ee`) committed only the source file and left `public/docs/` stale, proving the hook failed at its one job. The amend to `0388793b` was a manual fix — not a hook success.

We rolled back the entire task and captured these findings so no one re-attempts the same approach without reading them first.

---

## What was delivered and what was rolled back

**Delivered (now all removed):**
- `.overcommit.yml` with a single PreCommit CustomHook `MkDocsBuild`, `include: docs/**/*.md`, `command: bin/overcommit/mkdocs-build-on-docs-change`, all overcommit default hooks disabled
- `bin/overcommit/mkdocs-build-on-docs-change` — bash script checking staged files, running `bin/rails mkdocs:build`, running `git add public/docs/`
- `docs/developers/overcommit-hooks.{de,en}.md` — bilingual activation walkthrough
- A "Pre-commit Hook: Local Auto-Rebuild" section added to `docs/reference/mkdocs_documentation.en.md`
- Updated STATE.md marking the G-02 tech debt as "RESOLVED"

**Rolled back:**
- All of the above
- `bundle exec overcommit --uninstall` executed
- Local git config `overcommit.*.signature` and `overcommit.configuration.verifysignatures` cleaned
- `docs/reference/mkdocs_documentation.en.md` section replaced with a "Manual Rebuild Discipline" section pointing at this post-mortem
- STATE.md G-02 debt re-marked as "STILL OPEN"
- STATE.md Quick Tasks row for `260415-26d` marked as ROLLED BACK

**Kept in git history (not rm'd):** commits `912bf72a` (original install), `9494ec76` (planning artifacts), `0388793b` (amend with rendered output). The rollback reverts the code effect but keeps these commits in the log as evidence of the attempt.

---

## What we thought would happen

Stage a `docs/**/*.md` edit, run `git commit`, and:

```
git commit
    │
    ├── Staged set contains docs/**/*.md?
    │
    ├── no  → Hook does not execute (0 ms overhead)
    │          overcommit's `include:` filter short-circuits.
    │
    └── yes → Hook runs bin/overcommit/mkdocs-build-on-docs-change
              ├── `bin/rails mkdocs:build`  (~7s)
              ├── `git add public/docs/`
              └── Regenerated files are folded into the
                    in-progress commit atomically.
```

Measured a full `bin/rails mkdocs:build` takes ~7 seconds wall-clock on this workstation. The hook's `include:` filter was expected to short-circuit code-only commits to 0 ms overhead.

---

## What actually happened

### Observation 1: the dog-food commit was stale

The first real-world use of the hook was the commit that introduced the bilingual developer docs themselves (commit `59c0d7ee`). Expected behaviour: committing `docs/developers/overcommit-hooks.{de,en}.md` + `docs/reference/mkdocs_documentation.en.md` would trigger the hook, rebuild `public/docs/`, fold the rebuilt files into the commit atomically.

Actual result: `git show --name-only 59c0d7ee` returned **only the source file** (1 file, 86 insertions). `public/docs/en/reference/mkdocs_documentation/index.html` did NOT contain the new "Pre-commit Hook: Local Auto-Rebuild" section. Manual rebuild afterward proved the source-to-rendered path worked and produced the section correctly — so the hook was supposed to have done this but didn't.

This is exact G-02 reproduction. The hook failed at the one case it existed to prevent.

### Observation 2: `bundle exec overcommit --run` runs the hook correctly; `git commit` does not

The investigation used a proof-of-life diagnostic: a single `echo ... >> /tmp/proof-of-life.log` added as line 2 of the hook script (before any `set -euo pipefail`, before any command substitution, before any conditional).

| Invocation | Proof-of-life log written? | Diagnostic file written? |
|---|---|---|
| `bash bin/overcommit/mkdocs-build-on-docs-change` (direct) | yes | yes |
| `bundle exec overcommit --run` (overcommit dry-run) | yes | yes |
| `git commit -m "..."` (real commit, with `docs/*.md` staged) | **no** | **no** |

All three invocations ran against the exact same repo state on the same file system. Only the direct and dry-run paths actually executed the hook script. The real commit path did not — and yet overcommit reported `[MkDocsBuild] OK`.

### Observation 3: the overcommit wrapper did load in the real-commit case

An injected `File.write('/tmp/wrapper-ran.log', ...)` as line 2 of `.git/hooks/pre-commit` (the overcommit wrapper, Ruby) did write successfully on every real `git commit`. So the `.git/hooks/pre-commit` symlink was wired, the wrapper loaded, overcommit initialized, and the hook runner ran. The breakdown is downstream of the wrapper — somewhere between "overcommit decides to run MkDocsBuild" and "the bash script actually executes".

### Observation 4: GIT_TRACE confirms no sub-process for the hook script was spawned

Running `GIT_TRACE=1 git commit -m "..."`:

```
08:33:27.700677 run-command.c:667  trace: run_command: ... /Volumes/.../\.git/hooks/pre-commit
08:33:27.700681 run-command.c:759  trace: start_command: ... /Volumes/.../\.git/hooks/pre-commit
08:33:27.985814 git.c:476          trace: built-in: git diff --name-only -z --diff-filter=ACMR ... --cached
08:33:28.003828 git.c:476          trace: built-in: git diff --name-only -z --diff-filter=ACMR ...
08:33:28.315522 git.c:476          trace: built-in: git stash list -1
Running pre-commit hooks
✓ All pre-commit hooks passed
```

Note: `git stash list -1` appears but **no `git stash save`** (the "stash for hooks" step is skipped or never reached), and **no `run_command`/`start_command` line for a `bash` / `bin/overcommit/mkdocs-build-on-docs-change` sub-process**. The trace proves overcommit never actually spawned the hook script in this invocation — yet it printed `[MkDocsBuild] OK`.

### Observation 5: the rendered-file mtime does get touched at commit time

This is the most confusing data point. `ls -la public/docs/en/reference/mkdocs_documentation/index.html` showed the file mtime at exactly commit time (`08:18` for commit `59c0d7ee`). Something during the commit flow touched that file. But the content of the file did NOT contain the staged section — so whatever touched it rebuilt from stale source, or didn't actually rebuild and just touched the mtime.

This is unexplained. The investigation stopped here because the primary finding (hook doesn't run from real commits) was already conclusive.

---

## Secondary findings (incidental, but documented for completeness)

### `required: true` blocks `SKIP=`

The `.overcommit.yml` config marked `MkDocsBuild` as `required: true`. This causes overcommit to refuse the `SKIP=MkDocsBuild git commit ...` escape hatch with:

```
Cannot skip MkDocsBuild since it is required
```

The developer docs (now removed) documented SKIP as the bypass — that documentation was wrong. `required: true` has to be dropped for SKIP to work. Trivially fixable, but worth noting: the test `SKIP=MkDocsBuild git commit --amend --no-edit` still succeeded in folding `public/docs/` into the amend, because the amend's staged set contained only `public/docs/*` (no `docs/*.md`), which hit the hook script's "no docs/**/*.md in staged set, skipping" early-exit and exited 0. So it worked despite the SKIP not working. Edge case, not a design feature.

### Absolute paths in `command:` are treated as repo-relative

`command: ['/tmp/minimal-hook.sh']` caused overcommit to report:

```
MkDocsBuild in /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/tmp/minimal-hook.sh
```

`overcommit/hook_signer.rb:48` does `File.join(repo_root, command.first.to_s)`. Ruby's `File.join("/a/b", "/c/d")` returns `/a/b/c/d` — leading slashes are collapsed, not treated as "this is already absolute". So `command:` in overcommit only accepts repo-relative paths to tracked files. A test hook in `/tmp` can't be wired.

### overcommit's stash mechanism (`stash_unstaged_changes.rb`) is incompatible with hooks that add files

`lib/overcommit/hook_context/helpers/stash_unstaged_changes.rb:114` → `cleanup_environment` → `clear_working_tree` runs `git reset --hard` after the hooks return. If a hook did successfully `git add` files, that reset would blow the additions out of the index, and the subsequent `git stash pop --index` would restore the pre-hook stash (which does not contain the hook's additions). This is a structural incompatibility — even if Observation 2 had not existed, hooks that add files for inclusion in the pending commit would be unreliable under overcommit's stash semantics whenever any unstaged changes exist.

This was not confirmed to be the Observation 2 root cause (because the hook doesn't even run), but it would be a second failure mode if Observation 2 were fixed.

---

## Root-cause analysis status

**Confirmed:** the hook script does not run when invoked via `git commit` in the production code path, despite running correctly via `bundle exec overcommit --run` and direct bash invocation.

**Not confirmed:** *why*. Candidates considered and not ruled out:
1. overcommit's `should_skip?` logic returns true under some condition only in the real-commit context (but `[MkDocsBuild] OK` implies it reached `end_hook`, which implies should_skip? returned false — contradiction)
2. overcommit's hook caching / memoization (searched for cache-related code, found none)
3. A subtle interaction between `include:` filtering and the ad-hoc hook adapter in `lib/overcommit/hook_loader/plugin_hook_loader.rb:82-93` where the `command` is invoked without the `applicable_files` list
4. A race with overcommit's stash + restore sequence where the working-tree state the hook would read doesn't match the index
5. Some overcommit version-specific behaviour (gem version 0.68.0, ruby 3.2.1, git via homebrew)

None of these were proven. The investigation was stopped at the "hook doesn't run" finding because that was already a hard blocker. Fixing overcommit's internals was out of scope for a quick task.

---

## Decisions

1. **Remove the hook entirely, don't try to repair it.** The failure modes are subtle enough that a hand-patched overcommit config would carry false confidence into production.
2. **Do not retry the overcommit approach.** Any future attempt at automating this hardening should use either:
   - a plain `.git/hooks/pre-commit` shell script (no overcommit framework, no stash dance, no signing, simpler semantics, loses per-clone activation ergonomics); or
   - a CI guard (GitHub Actions job that runs `mkdocs build` and fails on `public/docs/` drift); or
   - some combination (e.g. plain pre-commit for local safety + CI guard for push-time backstop)
3. **Manual rebuild discipline is the current answer**, documented in `docs/reference/mkdocs_documentation.en.md` § "Manual Rebuild Discipline (no automatic hardening)" and in STATE.md under "Known tech debt carried into next milestone".
4. **The POSTMORTEM stays in the quick task directory** so future searches for `overcommit MkDocsBuild` or `public/docs/ hardening` land here and read the findings before re-attempting.

---

## Warning to future maintainers

If you find yourself about to:
- Install overcommit for a pre-commit build step
- Write a pre-commit hook that runs a build tool and does `git add` on the output
- Copy the approach from quick task 260415-26d because it "looked" like it worked

...read this post-mortem first. The hook can be made to pass `bundle exec overcommit --run` and still silently fail under `git commit`. Pretty green output from overcommit is not proof that the hook executed. Verify end-to-end by:

1. Add a proof-of-life `echo ... >> /tmp/proof.log` as **the first line** of the hook script, before any `set -e`
2. Stage a real source-file change
3. Run `git commit -m "test"`
4. Confirm `/tmp/proof.log` actually contains an entry
5. **Also** verify the committed tree actually contains the expected generated output via `git show --name-only <commit>` — not just the source edit

If any of those fail, you've reproduced the 260415-26d issue.

---

## Timeline (for the curious)

- **08:10** — quick task 260415-26d executed. gsd-executor reported success, hook installed, apparent dog-food success.
- **08:18** — commit `59c0d7ee` created as dog-food test of the hook by the orchestrator (not the executor). `git show --name-only` revealed only the source file was in the commit.
- **08:19** — user asked about performance ("will this slow down doc-heavy commits?"). Performance measurement showed ~7 s per hook fire. Information added to `docs/reference/mkdocs_documentation.en.md`.
- **08:21** — while committing the performance doc, the discrepancy between source file (had section) and rendered file (did not have section) was noticed.
- **08:22** — confirmed `public/docs/en/reference/mkdocs_documentation/index.html` was rebuilt at commit time but without the staged source changes. Reproduced manually via `bin/rails mkdocs:build` — rebuild worked correctly outside the hook.
- **08:23–08:33** — investigation: stashed code walkthrough, proof-of-life diagnostics, GIT_TRACE, minimal test hooks, plugin loader read. Findings above gathered.
- **08:34** — decision made with user: roll back (Option A).
- **08:40–08:45** — rollback executed; this post-mortem written.

---

## Files in this quick task directory after rollback

- `260415-26d-PLAN.md` — the original plan (kept as-is for historical accuracy)
- `260415-26d-SUMMARY.md` — the executor's summary at initial implementation time (kept as-is; now misleading, but historical)
- `260415-26d-POSTMORTEM.md` — **this file**, the authoritative record

The PLAN and SUMMARY are kept unmodified on purpose: editing them to reflect the rollback would erase evidence of what the executor actually claimed vs. what actually happened. Anyone reading the quick task dir should read PLAN + SUMMARY + POSTMORTEM together.
