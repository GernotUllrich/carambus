# Add config/database.yml.example for easier contributor onboarding

**Labels:** good first issue, help wanted

## Summary

The repository ships no committed `config/database.yml` and no `config/database.yml.example`. A new contributor cloning the repo has to reverse-engineer the expected PostgreSQL configuration (database names per environment, user, host) before `bin/rails db:create` works.

## Why it matters

A committed `database.yml.example` with placeholder credentials is the classic Rails onboarding convention: copy it to `database.yml`, adjust two values, done. It directly lowers the barrier for the first successful `bin/rails server`.

## Where

- New file: `config/database.yml.example`
- Reference for expected structure: any local working `config/database.yml` (gitignored), plus `config/carambus.yml.erb` for naming conventions used by scenario deployments (e.g. `carambus_<scenario>_development`).

## Suggested approach

1. Create `config/database.yml.example` with the standard Rails 7 PostgreSQL layout: a `default` section (adapter `postgresql`, encoding `unicode`, pool from `RAILS_MAX_THREADS`) and `development` / `test` / `production` sections.
2. Use placeholder values: database `carambus_development` / `carambus_test`, username/password placeholders or ENV lookups (`<%= ENV["DATABASE_USER"] %>`), host `localhost`.
3. Add a short comment header: "Copy to config/database.yml and adjust for your machine."
4. Mention the copy step in `CONTRIBUTING.md` (Development setup section).

## Definition of done

- `config/database.yml.example` exists, is valid YAML+ERB, and contains `development`, `test`, and `production` sections with no real credentials.
- `cp config/database.yml.example config/database.yml` followed by `bin/rails db:create db:migrate` works on a stock PostgreSQL install (with at most a username/password edit).
- `CONTRIBUTING.md` references the example file.
