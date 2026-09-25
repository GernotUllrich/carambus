# config valid only for current version of Capistrano
lock "3.19.2"

set :application, "carambus"
set :repo_url, "git@github.com:GernotUllrich/#{fetch(:application)}.git"
set :deploy_to, -> { "/var/www/#{fetch(:basename)}" }  # Plan 21-10: lambda, :basename set in production.rb (stage-file)

# Default branch is :master
# ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp
set :branch, "master"

# Default value for :linked_files is []
append :linked_files, "config/database.yml", "config/cable.yml", "config/carambus.yml", "config/nginx.conf", "config/puma.rb", "config/environments/production.rb", "config/env.production"

# Default value for linked_dirs is []
append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "public/system", "storage", "config/credentials", "bundle"

# public/app (Turnier-App) ist KEIN linked_dir mehr: seit Plan 17-04 liegt die App im Repo
# (Quelle tournament_app/, Build public/app/) und geht mit jedem Release mit. Ob /app/
# ausgeliefert wird, entscheidet nginx nach serve_tournament_app (templates/nginx/nginx_conf.erb).

# public/uebersichten: die statischen Bestandsuebersichten (rake coverage:pages). Sie werden auf
# dem Server ERZEUGT, nicht mitdeployt — deshalb ein linked_dir und nicht ein Verzeichnis im Repo:
# so ueberlebt der Stand jeden Deploy, und niemand muss generierte Dateien committen. Universell:
# bleibt das Verzeichnis leer, liefert nginx 404 — harmlos.
append :linked_dirs, "public/uebersichten"

# public/wissenswertes: Inhalte FUER DIE MITGLIEDER (Praesentationen, Anleitungen), erreichbar
# ueber den Knopf "Wissenswertes" auf der Scoreboard-Welcome-Page.
#
# ⚠️ BEWUSST NICHT in public/uebersichten: dort schreibt `rake coverage:pages` eine eigene
# `index.html` (Bestandsuebersichten Turniere/Ligen) und ueberschreibt alles Gleichnamige
# kommentarlos. Ausserdem sind das zwei verschiedene Dinge — interne Bestandsberichte hier,
# Mitglieder-Inhalte dort.
#
# Wie uebersichten ein linked_dir und kein Repo-Verzeichnis: die Dateien werden auf dem Server
# gepflegt und ueberleben so jeden Deploy. Bleibt es leer, liefert nginx 404 — harmlos.
append :linked_dirs, "public/wissenswertes"

# public/docs: die gebaute mkdocs-Dokumentation. Sie wird NICHT mitdeployt und liegt seit
# 2026-09-24 nicht mehr im Repo — sie war dort 552 getrackte Dateien (59 MB) gebauter Output
# und erzeugte ~327 dauerhafte Arbeitsbaum-Aenderungen. Der 3,7-MB-Volltextindex
# search/search_index.json hat am 2026-09-20 ausserdem ein bereits entferntes Passwort wieder
# in den Index getragen.
#
# Befuellt wird das Verzeichnis von `docs:upload` (lib/capistrano/tasks/docs.rake), das nach
# deploy:symlink:linked_dirs laeuft: lokal bauen, packen, hochladen, entpacken. Auf dem Server
# gebaut wird NICHT — die Raspberry Pis haben kein mkdocs.
#
# Ausgeliefert wird ueber Rails (`docs#show` liest Rails.root/public/docs/<pfad>), nicht ueber
# nginx. Bleibt das Verzeichnis leer, liefert /docs 404 — harmlos, aber genau das ist der
# Zustand bis zum ersten `docs:upload`.
append :linked_dirs, "public/docs"

# tmp/reports: Auswertungen, die auf dem Server ERZEUGT werden (`rake training:report[...,csv]`).
#
# Wie uebersichten und wissenswertes ein linked_dir: `tmp/` selbst ist NICHT verlinkt (nur
# tmp/pids, tmp/cache, tmp/sockets), eine dort abgelegte Datei waere beim naechsten Deploy weg.
# Ueber shared/ ueberlebt der Bestand, und der Code bleibt pfad-naiv — er schreibt schlicht nach
# Rails.root/tmp/reports und muss nichts ueber das Capistrano-Layout wissen. Bleibt es leer,
# passiert nichts.
append :linked_dirs, "tmp/reports"

# Default value for keep_releases is 5
set :keep_releases, 5

# Bundler optimizations
set :bundle_path, -> { shared_path.join('bundle') }
set :bundle_without, %w{development test}.join(' ')
set :bundle_jobs, 4
set :bundle_flags, '--quiet'

# Uncomment the following to require manually verifying the host key before first deploy.
# set :ssh_options, verify_host_key: :secure

# Verify Node.js is available
namespace :deploy do
  desc "Verify Node.js and yarn are available"
  task :verify_node do
    on roles(:app) do
      execute :node, "--version"
      execute :yarn, "--version"
    end
  end
end

# Hook into the default asset compilation process
namespace :deploy do
  namespace :assets do
    # Check if assets have changed - shared helper
    task :check_changes do
      on roles(:app) do
        # Vergleichsbasis ist das LIVE-Release (Ziel von `current`), nicht das zuletzt
        # angelegte Verzeichnis in releases/: ein abgebrochener Deploy hinterlaesst dort ein
        # Release OHNE kompilierte Assets. Am 2026-09-25 (carambus_api) war genau so eins die
        # Vergleichsbasis -> "keine Aenderung" -> Release ohne public/assets -> jede Seite 500.
        # Nur ein Live-Release MIT Sprockets-Manifest taugt als Quelle fuer den Skip-Fall.
        previous_path = capture(:readlink, "-e", current_path, "2>/dev/null || true").strip
        live_has_assets = !previous_path.empty? &&
          test("ls #{previous_path}/public/assets/.sprockets-manifest-*.json >/dev/null 2>&1")

        if !live_has_assets || ENV['FORCE_ASSETS']
          set :assets_changed, true
          if ENV['FORCE_ASSETS']
            info "🔨 FORCE_ASSETS=1 - will compile assets"
          elsif previous_path.empty?
            info "📦 First deployment - will compile assets"
          else
            info "📦 Live release has no compiled assets - will compile assets"
          end
        else
          set :assets_source, previous_path

          # Check for differences in asset-related files
          assets_differ = false
          asset_paths = %w[
            app/javascript
            app/assets
            app/views
            config/locales
            package.json
            yarn.lock
            esbuild.config.mjs
            tailwind.config.js
          ]

          asset_paths.each do |path|
            if test("[ -e #{release_path}/#{path} ]") && test("[ -e #{previous_path}/#{path} ]")
              # Both exist, check for differences. `-x builds`: app/assets/builds ist
              # Build-Output (gitignored) und liegt nur im gebauten Live-Release — ohne den
              # Ausschluss meldete der Vergleich immer eine Aenderung.
              if test("! diff -rq -x builds #{release_path}/#{path} #{previous_path}/#{path} >/dev/null 2>&1")
                assets_differ = true
                break
              end
            elsif test("[ -e #{release_path}/#{path} ]") || test("[ -e #{previous_path}/#{path} ]")
              # One exists, one doesn't - that's a change
              assets_differ = true
              break
            end
          end

          set :assets_changed, assets_differ

          if assets_differ
            info "✅ Asset files changed since last deployment - will compile assets"
          else
            info "⏭️  No asset changes detected - skipping compilation (saves ~45 seconds)"
            info "💡 Use FORCE_ASSETS=1 to force asset compilation if needed"
          end
        end
      end
    end

    desc "Install yarn dependencies before asset compilation"
    task :install_dependencies do
      on roles(:app) do
        within release_path do
          if fetch(:assets_changed, true)
            # Install JavaScript dependencies
            execute :yarn, :install
          end
        end
      end
    end

    desc "Build JavaScript and CSS assets before Rails precompilation"
    task :build_frontend_assets do
      on roles(:app) do
        within release_path do
          with rails_env: fetch(:rails_env) do
            if fetch(:assets_changed, true)
              # Build JavaScript assets
              execute :yarn, :build

              # Build CSS assets
              execute :yarn, "build:css"

              # Ensure the builds directory exists for Rails asset pipeline
              execute :mkdir, "-p app/assets/builds"
            end
          end
        end
      end
    end

    desc "Verify manifest was created properly"
    task :verify_manifest do
      on roles(:app) do
        within release_path do
          # Only verify if assets were actually compiled
          if fetch(:assets_changed, true)
            execute :ls, "-la public/assets/"
            execute :find, "public/assets", "-name '*.json'", "-o", "-name 'manifest*'"
          else
            info "Skipping manifest verification (assets were not recompiled)"
          end
        end
      end
    end

    desc "Precompile Rails assets"
    task :precompile do
      on roles(:app) do
        within release_path do
          with rails_env: fetch(:rails_env) do
            if fetch(:assets_changed, true)
              info "Running Rails asset precompilation..."
              execute :bundle, :exec, :rails, "assets:precompile"
            else
              # public/assets ist kein linked_dir: ohne Kopie haette das neue Release gar
              # keine Assets. Quelle ist das Live-Release aus check_changes.
              source = fetch(:assets_source)
              info "Skipping Rails asset precompilation - copying assets from #{source}"
              execute :cp, "-a", "#{source}/public/assets", "#{release_path}/public/"
              execute :mkdir, "-p", "#{release_path}/app/assets/builds"
              execute :cp, "-a", "#{source}/app/assets/builds/.", "#{release_path}/app/assets/builds/"
            end
          end
        end
      end
    end
  end
end

# Hook into the custom asset compilation process
before "deploy:assets:precompile", "deploy:assets:check_changes"
before "deploy:assets:precompile", "deploy:verify_node"
before "deploy:assets:precompile", "deploy:assets:install_dependencies"
before "deploy:assets:precompile", "deploy:assets:build_frontend_assets"

# Ensure manifest is properly handled after precompilation
after "deploy:assets:precompile", "deploy:assets:verify_manifest"

# Hook asset precompilation into the deployment process
before "deploy:symlink:release", "deploy:assets:precompile"

# Ensure current symlink exists after database reset
namespace :deploy do
  desc "Ensure current symlink exists"
  task :ensure_current_symlink do
    on roles(:app) do
      # Check if current symlink exists and is valid
      if test("[ ! -L #{deploy_to}/current ]") || test("[ ! -e #{deploy_to}/current ]")
        # Find the latest release
        latest_release = capture(:ls, "-t", "#{deploy_to}/releases").split.first
        if latest_release
          execute :ln, "-sf", "#{deploy_to}/releases/#{latest_release}", "#{deploy_to}/current"
          puts "   ✅ Recreated current symlink to #{latest_release}"
        else
          puts "   ⚠️  No releases found to symlink"
        end
      else
        puts "   ✅ Current symlink already exists"
      end
    end
  end
end

# Run symlink check before asset precompilation
before "deploy:assets:precompile", "deploy:ensure_current_symlink"

# Puma restart configuration
after 'deploy:publishing', 'puma:restart'

namespace :puma do
  desc "Restart application"
  task :restart do
    on roles(:app) do
      execute "sudo #{current_path}/bin/manage-puma.sh #{fetch(:basename)}"
    end
  end
end
