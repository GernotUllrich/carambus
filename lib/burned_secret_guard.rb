# frozen_string_literal: true

require "yaml"
require "digest"

# ─────────────────────────────────────────────────────────────────────────────
# Baum-Wache — verbrannte Geheimnisse duerfen nicht ins Repo zurueckkehren.
#
# Kontext: Plan 21-01 hat den Klartext der Postgres-Rolle `www_data` aus 25
# getrackten Dateien entfernt — und dabei fast wieder eingefuegt. Beim
# Branch-Wechsel fiel `docs/` kurz auf den Stand VOR der Bereinigung zurueck,
# und der mitlaufende `docs-rebuild`-Listener baute genau in dem Moment
# `public/docs/search/search_index.json` neu, mitsamt dem Passwort. Nur ein
# Blick von Hand hat das gefangen. Eine Bereinigung ohne Wache ist eine
# Momentaufnahme, kein Zustand.
#
# Wirkung:
#   - pre-commit (overcommit): prueft die GESTAGTEN Dateien (ARGV) — schnell
#   - CI: prueft den GANZEN getrackten Baum (`git ls-files`) — faengt auch das,
#     was ohne Commit hineingeraten ist, etwa durch einen Generator
#
# Quelle der Wahrheit ist `lib/credential_denylist.yml` — SHA256-Summen, keine
# Werte. Diese Wache ist deren ZWEITER Verbraucher: die vier Auswertungsstellen
# in `lib/tasks/scenarios.rake` pruefen nur Rails-Credentials (FEATURE_KEY_GROUPS)
# und erreichen ein DB-Passwort nie.
#
# Der Wert wird NIE ausgegeben — auch nicht gekuerzt, auch nicht im Fehlerfall.
# Gemeldet werden Datei, Zeile und der `hint` des Eintrags. Das ist der ganze
# Sinn einer Sperrliste aus Summen.
#
# Bewusst KEINE Baseline und kein Ratchet (anders als lib/ui_hex_guard.rb): ein
# Treffer ist immer ein Fehler. Es gibt keinen legitimen Grund, ein verbranntes
# Geheimnis im Baum zu haben.
#
# Bewusst KEINE Rails-Abhaengigkeit: laeuft in overcommit und CI ohne Boot.
# ─────────────────────────────────────────────────────────────────────────────
module BurnedSecretGuard
  ROOT = File.expand_path("..", __dir__) # lib/ → Projektwurzel

  DENYLIST_FILE = File.join(ROOT, "lib", "credential_denylist.yml")

  # Token-Klasse: Base64-/Hex-/Passwort-Alphabet ohne Trennzeichen. Ein Geheimnis
  # muss als EIN Token erfasst werden, sonst trifft seine Summe nie. Vor der
  # Aufnahme eines Fingerprints deshalb pruefen, dass der Wert nur aus diesen
  # Zeichen besteht (fuer `shared.database_password` am 2026-09-20 geprueft).
  TOKEN_RE = %r{[A-Za-z0-9+/=_-]{8,}}

  # Mindestlaenge 8: kuerzere Tokens sind zu niedrig-entropisch, ihre Summen
  # wuerden an Allerweltswoertern haengenbleiben (Fehlalarm-Risiko).
  #
  # Obergrenze je Datei; groessere werden uebersprungen.
  #
  # 2026-09-24 von 2 MB auf 16 MB angehoben: bei 2 MB fiel
  # `public/docs/search/search_index.json` (3,7 MB) durch — ausgerechnet der
  # Volltextindex der gesamten Dokumentation, also die Datei, die am 2026-09-20 ein
  # bereits entferntes Passwort wieder in den Index getragen hat. Die Wache hat diesen
  # Fall nie abgedeckt, obwohl die Datei im `git ls-files`-Scan stand.
  #
  # Kosten der Anhebung: im ganzen Repo liegt genau EINE getrackte Datei zwischen 2 und
  # 16 MB (ein Storage-Backup-Blob), und die wird eine Zeile weiter unten als binaer
  # verworfen. Ueber 16 MB bleibt es bei einer Datei, die weiterhin uebersprungen wird.
  MAX_BYTES = 16_000_000

  Hit = Struct.new(:path, :line_no, :hint, keyword_init: true)

  class << self
    # Einstieg fuer bin/burned-secret-guard.
    # paths leer → ganzer getrackter Baum; sonst genau diese Pfade.
    # Rueckgabe: true = sauber.
    def check(paths = [], denylist: load_denylist, out: $stdout)
      files = paths.empty? ? tracked_files : paths
      hits = scan(files, denylist)

      if hits.empty?
        out.puts "Baum-Wache: 0 Treffer in #{files.size} Datei(en) " \
                 "gegen #{denylist.size} Fingerprint(s) der Sperrliste."
        return true
      end

      out.puts "Baum-Wache: #{hits.size} verbranntes Geheimnis/Geheimnisse gefunden."
      out.puts ""
      hits.each do |hit|
        out.puts "  #{hit.path}:#{hit.line_no}"
        out.puts "    Sperrlisten-Eintrag: #{hit.hint}"
      end
      out.puts ""
      out.puts "Der Wert wird bewusst nicht ausgegeben. Entfernen, nicht maskieren —"
      out.puts "und pruefen, ob er ueber einen Generator (mkdocs, scenario:*) wieder"
      out.puts "hineinlaeuft. Sperrliste: lib/credential_denylist.yml"
      false
    end

    # Sperrliste als Hash { sha256 => hint }.
    def load_denylist(file = DENYLIST_FILE)
      entries = YAML.load_file(file)["fingerprints"] || []
      entries.to_h { |e| [e["sha256"], e["hint"].to_s] }
    end

    # Getrackte Dateien. force_encoding ist noetig: ohne sie scheitert split("\0")
    # an Dateinamen mit Umlauten (ArgumentError: invalid byte sequence).
    def tracked_files
      `git ls-files -z`.force_encoding("UTF-8").split("\0")
    end

    def scan(files, denylist)
      sums = denylist.keys.to_set
      hits = []

      files.each do |path|
        next unless File.file?(path)
        next if File.size(path) > MAX_BYTES

        data = File.binread(path)
        next if data.include?("\0") # binaer

        data.force_encoding("UTF-8")
        data.each_line.with_index(1) do |line, line_no|
          line.scan(TOKEN_RE) do |token|
            sum = Digest::SHA256.hexdigest(token)
            hits << Hit.new(path: path, line_no: line_no, hint: denylist[sum]) if sums.include?(sum)
          end
        end
      end

      hits
    end
  end
end
