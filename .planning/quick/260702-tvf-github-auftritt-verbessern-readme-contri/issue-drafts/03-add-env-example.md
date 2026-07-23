# Add .env.example documenting optional environment variables

**Labels:** good first issue, help wanted

## Summary

Carambus reads several optional environment variables (`REDIS_URL`, `DEEPL_API_KEY`, `OPENAI_API_KEY`, `SMTP_USERNAME`, `SMTP_PASSWORD`, …) that are documented only in prose (`CLAUDE.md` / docs). There is no `.env.example` template file a contributor can copy.

## Why it matters

New contributors should be able to see at a glance which environment variables exist, which are optional, and what format they take — without grepping the codebase. An `.env.example` is the standard convention for this.

## Where

- New file: `.env.example` at the repo root
- Variable inventory sources: `CLAUDE.md` ("Configuration" section), plus a grep for `ENV[` / `ENV.fetch` across `config/` and `app/`.

## Suggested approach

1. Grep the codebase for environment variable reads: `grep -rn "ENV\[" config/ app/ | grep -oE 'ENV\[[^]]+\]' | sort -u`.
2. Create `.env.example` listing each variable with a placeholder value and a one-line comment stating what it is for and whether it is optional (most are — e.g. `DEEPL_API_KEY` only enables DeepL translation).
3. Do NOT include any real secrets — placeholders only (e.g. `DEEPL_API_KEY=your-deepl-key-here`).
4. Verify `.env` (without `.example`) is gitignored; add it to `.gitignore` if not.
5. Reference the file from `CONTRIBUTING.md`.

## Definition of done

- `.env.example` exists at the repo root, contains at least `REDIS_URL`, `DEEPL_API_KEY`, `OPENAI_API_KEY`, `SMTP_USERNAME`, `SMTP_PASSWORD` with placeholder values and comments.
- No real credentials appear in the file (`git diff` review).
- `.env` is covered by `.gitignore`.
- `CONTRIBUTING.md` mentions the file.
