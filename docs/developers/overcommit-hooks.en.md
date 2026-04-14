# Overcommit Git Hooks — MkDocsBuild

This project uses [overcommit](https://github.com/sds/overcommit) to manage a single, narrowly scoped pre-commit hook: **MkDocsBuild**. The hook structurally prevents a class of bug where `docs/**/*.md` source edits are committed without the generated `public/docs/**/*` tree being rebuilt in the same commit.

## What the hook does

When you run `git commit` and the staged set contains at least one `docs/**/*.md` path, the hook:

1. Runs `bin/rails mkdocs:build` — this regenerates `site/` and copies it into `public/docs/`.
2. Runs `git add public/docs/` — this folds the regenerated files into the in-progress commit so source and generated output ship atomically.

If the build fails, the commit is aborted with the error output from the rake task. Nothing is committed in that state.

### Why this exists

The Rails server serves `/docs/` from the tracked `public/docs/` tree, **not** from the `docs/` source tree. Any drift between source and generated output silently ships stale content to end users. During v7.0 UAT this surfaced as gap **G-02** (commit `7cf16114`) — `public/docs/` was four weeks behind the source and had to be rebuilt inline. This hook makes that class of drift structurally impossible on a workstation where it is active.

## Activation (one-time, per fresh clone)

Overcommit ships as a Gemfile gem but hooks are **not** installed automatically. On every fresh clone run:

```bash
bundle exec overcommit --install
bundle exec overcommit --sign
```

`--install` wires `.git/hooks/pre-commit` (and peers) to dispatch into overcommit. `--sign` signs the `.overcommit.yml` config; overcommit refuses to run an unsigned config as a safety measure against untrusted pulls.

**Re-sign after every edit of `.overcommit.yml` or `bin/overcommit/*`:**

```bash
bundle exec overcommit --sign
bundle exec overcommit --sign pre-commit   # when a hook script's content changes
```

The first command re-signs the config file; the second re-signs individual plugin hooks and is required whenever the referenced script's contents change.

## Prerequisites

The hook calls `bin/rails mkdocs:build`, which requires the `mkdocs` CLI to be available on your PATH. Install it via pip:

```bash
pip install mkdocs-material mkdocs-static-i18n pymdown-extensions
```

If `mkdocs` is missing when the hook fires, the commit is aborted with:

```
[MkDocsBuild] ERROR: mkdocs CLI not found.
[MkDocsBuild] Install with:
[MkDocsBuild]   pip install mkdocs-material mkdocs-static-i18n pymdown-extensions
```

There is no silent skip on missing `mkdocs` — a missing CLI always blocks the commit.

## When it fires / when it does not

- **Fires** when at least one staged path matches `docs/**/*.md`.
- **Does NOT fire** when the staged set contains only Ruby, JS, ERB, YAML, config, or anything else outside `docs/**/*.md`. Overcommit's `include:` filter short-circuits the whole hook — zero Rails boot, zero `mkdocs` invocation, zero overhead.

This means day-to-day Ruby/JS/schema work sees no cost from this hook.

## Bypass escape hatch

For legitimate emergencies (e.g. committing a fix while the docs build is temporarily broken), bypass the hook for a single commit:

```bash
SKIP=MkDocsBuild git commit -m "fix: urgent, docs rebuild pending"
```

The next commit that touches `docs/**/*.md` will regenerate everything, so the escape hatch self-heals on the next docs-touching commit.

Do **not** use `--no-verify` — that skips every hook, not just `MkDocsBuild`, and hides the fact that the bypass happened.

## Troubleshooting

**"mkdocs CLI not found"** — Install the prerequisites shown above. The `pip install` command is the same one the rake task and the hook both print.

**Hook ran but `git status public/docs/` shows nothing new staged** — This is normal. It means your `docs/**/*.md` edit did not change any rendered HTML output (e.g. you added a trailing newline, fixed a typo that mkdocs whitespace-normalises, or edited a file that is excluded from the mkdocs config). The hook still ran successfully; the commit is clean.

**"Overcommit::Exceptions::InvalidHookSignature"** — Someone edited `.overcommit.yml` or `bin/overcommit/mkdocs-build-on-docs-change`. Re-sign:

```bash
bundle exec overcommit --sign
bundle exec overcommit --sign pre-commit
```

**"I want to run the hook manually without committing"** — Use:

```bash
bundle exec overcommit --run
```

This executes all pre-commit hooks against the current staged set without creating a commit. Useful for verifying the hook after edits.

## Related files

- `.overcommit.yml` — Overcommit configuration (registers MkDocsBuild, disables default hooks).
- `bin/overcommit/mkdocs-build-on-docs-change` — The hook script that runs `bin/rails mkdocs:build` and stages `public/docs/`.
- `lib/tasks/mkdocs.rake` — The rake task the hook invokes (also usable standalone: `bin/rails mkdocs:build`).
