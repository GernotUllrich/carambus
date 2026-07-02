# Contributing to Carambus

Thanks for your interest in contributing! Carambus is developed by a very small team, so well-scoped pull requests, bug reports, and documentation fixes are all genuinely helpful. AI-assisted development is explicitly welcome — much of Carambus itself is built that way.

## Prerequisites

- **Ruby 3.2.1** (see `.ruby-version`; rbenv or similar recommended)
- **PostgreSQL**
- **Redis** (Action Cable, caching, sessions)
- **Node.js 18+** with **yarn** (esbuild + Tailwind asset builds)

## Development setup

```bash
git clone https://github.com/GernotUllrich/carambus.git
cd carambus

bundle install
yarn install

# Configure the database (PostgreSQL). Adjust config/database.yml for your
# local setup. Note: the app also reads custom settings from config/carambus.yml.

bin/rails db:create db:migrate
```

Run the app:

```bash
foreman start -f Procfile.dev   # full dev stack (server + CSS + JS watchers)
# or
bin/rails server                # Rails server only
```

## Running tests

The test suite uses **Minitest** (not RSpec):

```bash
bin/rails test                                            # all tests
bin/rails test:critical                                   # concerns + scraping tests only
bin/rails test test/concerns/local_protector_test.rb      # single file
bin/rails test test/concerns/local_protector_test.rb:23   # single test by line
```

Prepare the test database (strong_migrations is enforced):

```bash
SAFETY_ASSURED=true bin/rails db:test:prepare
```

## Linting

```bash
bundle exec standardrb                 # Ruby style (Standard)
bundle exec erblint --lint-all         # ERB templates
bundle exec brakeman --no-pager        # security scan
```

## Key concept: local vs. global records

This is essential context before touching anything that saves models.

Carambus runs as a network of servers: one central API server plus local club servers that sync data from it. Records with `id < 50_000_000` (the `MIN_ID` constant) are **global** records synced from the central API; records with `id >= MIN_ID` are **local**. The `LocalProtector` concern prevents accidental modification of global records on local server instances — a save to a global record on a local server will be blocked.

In tests, `LocalProtector` is disabled via `LocalProtectorTestOverride` in `test_helper.rb`, so fixtures with low IDs remain writable.

## Conventions

- Conventional commit messages (`feat: …`, `fix: …`, `docs: …`)
- `# frozen_string_literal: true` at the top of all Ruby files
- Comments: German for business logic, English for technical terms
- Ruby style is enforced by `standardrb`; run it before opening a PR

See `CLAUDE.md` at the repo root for a compact architecture and conventions overview.

## Questions?

- Open a [GitHub issue](https://github.com/GernotUllrich/carambus/issues)
- Or email gernot.ullrich@gmx.de
