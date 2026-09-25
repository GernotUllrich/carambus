# frozen_string_literal: true

# Die gebaute Dokumentation nach shared/public/docs hochladen.
#
# WARUM NICHT IM REPO: `public/docs` ist gebauter mkdocs-Output. Getrackt erzeugte er
# ~327 dauerhafte Arbeitsbaum-Aenderungen — die `git status --porcelain` als EINE Zeile
# zusammenfasst und die deshalb leicht fuer harmlos gehalten werden. Schwerer wiegt der
# 3,7-MB-Volltextindex `search/search_index.json`: er hat am 2026-09-20 ein bereits
# entferntes Passwort wieder in den Index getragen, einen Commit nach der Entfernung.
# Dieselbe Begruendung wie bei `public/uebersichten` und `public/wissenswertes` in
# `config/deploy.rb`: niemand soll generierte Dateien committen muessen.
#
# WARUM DER FEHLER SONST UNVERMEIDLICH IST: wer eine Doku-Quelle aendert, muesste daran
# denken, den gesamten Build mitzucommitten. Am 2026-09-24 belegt — `d51c1fb8` war
# deployt, die darin enthaltene neue Seite `docs/developers/fallstricke.de.md` wurde vom
# Server aber nicht ausgeliefert, weil der Build vom 2026-09-20 stammte. Kein Fehler,
# keine Meldung, nur ein vier Tage alter Stand. Seit dieser Umstellung ist Bauen Teil des
# Deploys und nicht mehr Teil der Commit-Disziplin.
#
# WARUM NICHT AUF DEM SERVER BAUEN: die Raspberry Pis haben kein mkdocs (am 2026-09-24 auf
# bc-wedel geprueft: python3 und pip3 vorhanden, mkdocs nicht). mkdocs-material samt
# Plugins auf sechs Servern zu pflegen waere teurer als hochzuladen. Gebaut wird dort, wo
# deployt wird.
#
# ⚠️ ERSTER DEPLOY NACH DER UMSTELLUNG: bis dieser Task einmal gelaufen ist, ist
# `shared/public/docs` leer und `/docs` liefert 404. Danach ueberlebt der Bestand jeden
# Deploy, weil er in `shared/` liegt.

module CarambusDocsUpload
  PAKET = "tmp/docs-upload.tgz"
  WURZEL = "public/docs"

  # Inhaltshash des gebauten Baums: Pfad + Dateiinhalt, sortiert.
  #
  # ⚠️ NICHT den Tarball hashen — gzip schreibt einen Zeitstempel in den Header, das
  # Ergebnis waere bei identischem Inhalt jedes Mal verschieden und der Upload liefe immer.
  # Und nicht ueber die Shell rechnen: `md5` gibt es nur auf macOS, `md5sum` nur auf Linux.
  # Ruby laeuft ohnehin, ist portabel und hat keine Quoting-Probleme mit Dateinamen.
  def self.inhaltshash
    require "digest"
    Digest::SHA256.hexdigest(
      dateien.map { |f| "#{f}\0#{Digest::SHA256.file(f).hexdigest}" }.join("\n")
    )
  end

  def self.dateien
    Dir.glob("#{WURZEL}/**/*", File::FNM_DOTMATCH).select { |f| File.file?(f) }.sort
  end
end

namespace :docs do
  desc "Doku lokal bauen und nach shared/public/docs hochladen (ueberspringt, wenn unveraendert)"
  task :upload do
    run_locally do
      unless test("which mkdocs > /dev/null 2>&1")
        error "mkdocs ist auf dieser Maschine nicht installiert — die Doku kann nicht gebaut werden."
        error "  pip install mkdocs-material mkdocs-static-i18n pymdown-extensions"
        error "Abbruch: ein Deploy ohne gebaute Doku wuerde den ausgelieferten Stand einfrieren."
        exit 1
      end

      info "Doku bauen (mkdocs)…"
      # ⚠️ Als String, nicht `execute :bundle, ...`: capistrano/rbenv haengt an das Symbol
      # :bundle auch in run_locally den Server-Praefix `$HOME/.rbenv/bin/rbenv exec` —
      # den gibt es am Mac (Homebrew-rbenv) nicht. Strings mappt SSHKit nicht.
      execute "bundle exec rake mkdocs:build"

      # ⚠️ Geheimnis-Wache ueber den GEBAUTEN Baum — sonst waere diese Umstellung eine
      # Regression: solange public/docs getrackt war, lief die Wache im pre-commit ueber
      # `git ls-files` und hatte search/search_index.json im Scan. Genau so fiel am
      # 2026-09-20 auf, dass der Volltextindex ein entferntes Passwort zurueckgetragen
      # hatte. Ohne Index laeuft sie dort nicht mehr — hochgeladen auf einen oeffentlich
      # erreichbaren Server wird der Baum trotzdem. Also hier pruefen, vor dem Packen.
      info "Geheimnis-Wache ueber den gebauten Doku-Baum…"
      unless test("find public/docs -type f -print0 | xargs -0 ruby bin/burned-secret-guard")
        error "Die Geheimnis-Wache hat im gebauten Doku-Baum angeschlagen — nichts hochgeladen."
        error "Treffer pruefen, Quelle in docs/ bereinigen, neu bauen."
        exit 1
      end

      # ⚠️ COPYFILE_DISABLE=1: macOS-tar legt sonst zu jeder Datei eine `._`-AppleDouble-
      # Datei mit erweiterten Attributen an. Auf dem Linux-Server landet das als Muell im
      # ausgelieferten Doku-Baum.
      execute "COPYFILE_DISABLE=1 tar -czf #{CarambusDocsUpload::PAKET} -C public docs"
    end

    hash_lokal = CarambusDocsUpload.inhaltshash
    dateizahl = CarambusDocsUpload.dateien.size

    on roles(:app) do
      ziel = "#{shared_path}/public/docs"
      marke = "#{ziel}/.build-hash"

      if test("[ -f #{marke} ]") && capture(:cat, marke).strip == hash_lokal
        info "Doku unveraendert (#{hash_lokal[0, 12]}…) — Upload uebersprungen."
        next
      end

      paket_fern = "#{shared_path}/tmp/docs-upload.tgz"
      execute :mkdir, "-p", "#{shared_path}/tmp", "#{shared_path}/public"
      upload! CarambusDocsUpload::PAKET, paket_fern

      # Vollstaendig ersetzen, nicht darueberkopieren: `rake mkdocs:build` kopiert mit
      # `cp_r` in ein bestehendes public/docs, geloeschte Seiten blieben sonst ewig liegen.
      execute :rm, "-rf", ziel
      execute :tar, "-xzf", paket_fern, "-C", "#{shared_path}/public"
      execute :rm, "-f", paket_fern
      execute :sh, "-c", "'echo #{hash_lokal} > #{marke}'"

      info "Doku hochgeladen: #{dateizahl} Dateien (#{hash_lokal[0, 12]}…)."
    end
  end
end

# Nach dem Anlegen der linked_dir-Symlinks: ab hier zeigt release/public/docs auf
# shared/public/docs, der Upload wirkt also sofort im neuen Release.
after "deploy:symlink:linked_dirs", "docs:upload"
