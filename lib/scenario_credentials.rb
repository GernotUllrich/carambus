# frozen_string_literal: true

require "securerandom"
require "fileutils"
require "yaml"
require "json"
require "digest"
require "active_support/core_ext/hash/deep_merge"
require "active_support/encrypted_configuration"

# ─────────────────────────────────────────────────────────────────────────────
# Credentials eines Carambus-Servers (Plan 18-01).
#
# Berechnet den Inhalt der production.yml.enc aus dem Bestand (entschluesselte
# .enc), dem Secret-Pool (carambus_data/secrets.yml) und der Deklaration in der
# Szenario-config.yml (scenario.credentials). Die Merge-Regeln stammen
# unveraendert aus scenario:generate_credentials (Phase C); ohne Schalter
# liefert die Klasse wertgleich dasselbe wie vorher.
#
# Neuanlage (`created`) und Rotation (`rotated`) erzeugen frische Geheimnisse:
# bis 18-01 teilten alle Server Key, secret_key_base und AR-Schluessel.
#
# Die Klasse selbst ist reine Logik; Dateien (Key, .enc, Backups) behandelt
# ScenarioCredentials::Store, Ausgabe und Schalter der Rake-Task.
# ─────────────────────────────────────────────────────────────────────────────
class ScenarioCredentials
  # 'openai' entfernt (2026-08-15): ruby-openai ist seit Phase 36 aus dem Gemfile
  # (einzige AI-Integration ist `anthropic`). Dieselbe Tabelle steht noch in
  # scenarios.rake fuer build_feature_keys_from_pool (push_credentials).
  FEATURE_KEY_GROUPS = {
    "ai" => %w[anthropic],
    "translation" => %w[deepl google],
    "scraping" => %w[youtube kozoom]
  }.freeze
  DEFAULT_FEATURES = %w[ai translation].freeze
  PRESERVE_KEYS = %w[secret_key_base active_record_encryption devise_jwt_secret_key
    location_id location_calendar_id].freeze
  LEGACY_FLAT_KEYS = %w[anthropic_key deepl_key youtube_api_key].freeze

  Report = Struct.new(:features, :clubcloud_context, :removed, :generated_skb, :added, keyword_init: true)

  def self.deep_stringify(obj)
    case obj
    when Hash then obj.each_with_object({}) { |(k, v), h| h[k.to_s] = deep_stringify(v) }
    when Array then obj.map { |e| deep_stringify(e) }
    else obj
    end
  end

  # existing: entschluesselter Bestand (Hash, leer bei Neuanlage)
  # pool:     secrets.yml als Hash (shared / per_scenario)
  # decl:     config.yml scenario.credentials (features, clubcloud_context, region_server_contexts)
  def initialize(existing:, pool:, decl:, scenario_name:)
    @existing = existing || {}
    @pool = pool || {}
    @decl = decl || {}
    @scenario_name = scenario_name
  end

  def features
    list = Array(@decl["features"]).map(&:to_s)
    list.empty? ? DEFAULT_FEATURES.dup : list # Default: Backup ueberall
  end

  # Heutiges Verhalten von scenario:generate_credentials: Pool-Keys in den Bestand
  # mergen, historische flache Leaves entfernen, secret_key_base nur bei Leere erzeugen.
  # Liefert [Hash, Report].
  def merged
    merged = self.class.deep_stringify(@existing)
    removed = LEGACY_FLAT_KEYS.select { |k| merged.key?(k) }
    LEGACY_FLAT_KEYS.each { |k| merged.delete(k) }
    generated_skb = false
    if merged["secret_key_base"].to_s.strip.empty?
      merged["secret_key_base"] = SecureRandom.hex(64)
      generated_skb = true
    end
    added = merge_pool_keys!(merged)
    [merged, report(removed: removed, generated_skb: generated_skb, added: added)]
  end

  # Frische Geheimnisse eines Servers. AR-Schluessel wie `bin/rails db:encryption:init`.
  def self.fresh_secrets
    {
      "secret_key_base" => SecureRandom.hex(64),
      "devise_jwt_secret_key" => SecureRandom.hex(64),
      "active_record_encryption" => {
        "primary_key" => SecureRandom.alphanumeric(32),
        "deterministic_key" => SecureRandom.alphanumeric(32),
        "key_derivation_salt" => SecureRandom.alphanumeric(32)
      }
    }
  end

  # Neuanlage: eigene Geheimnisse plus Feature-Keys aus dem Pool (dieselben Regeln wie merged).
  # Kein Bestand — also auch keine Vorlagenreste aus alten .enc-Dateien.
  def created
    hash = self.class.fresh_secrets
    added = merge_pool_keys!(hash)
    [hash, report(removed: [], generated_skb: true, added: added)]
  end

  # Rotation: secret_key_base und JWT-Secret neu; der AR-primary_key wird zur Liste [alt…, neu]
  # (Rails verschluesselt mit dem letzten, entschluesselt mit allen). deterministic_key und
  # key_derivation_salt bleiben: es gibt keine deterministischen `encrypts`, und ein neues Salt
  # machte den Altbestand unlesbar. Alles andere bleibt wertgleich, der Pool wird nicht gemergt.
  def rotated
    hash = self.class.deep_stringify(@existing)
    fresh = self.class.fresh_secrets
    ar = hash["active_record_encryption"] || {}
    new_ar = fresh["active_record_encryption"]
    hash["active_record_encryption"] = ar.merge(
      "primary_key" => Array(ar["primary_key"]).compact + [new_ar["primary_key"]],
      "deterministic_key" => ar["deterministic_key"] || new_ar["deterministic_key"],
      "key_derivation_salt" => ar["key_derivation_salt"] || new_ar["key_derivation_salt"]
    )
    hash["secret_key_base"] = fresh["secret_key_base"]
    hash["devise_jwt_secret_key"] = fresh["devise_jwt_secret_key"]
    [hash, report(removed: [], generated_skb: true, added: [])]
  end

  # Fingerabdruck der Geheimnisse: SHA-256-Praefixe, nie Werte. Lokal und auf dem Server mit
  # demselben Code gerechnet (remote_fingerprint_script), damit beide Seiten vergleichbar sind.
  def self.fingerprint(hash)
    h = deep_stringify(hash || {})
    ar = h["active_record_encryption"] || {}
    d = ->(v) { v.nil? ? nil : Digest::SHA256.hexdigest(v.to_s)[0, 12] }
    {
      "secret_key_base" => d[h["secret_key_base"]],
      "devise_jwt_secret_key" => d[h["devise_jwt_secret_key"]],
      "primary_key" => Array(ar["primary_key"]).map { |k| d[k] },
      "deterministic_key" => d[ar["deterministic_key"]],
      "key_derivation_salt" => d[ar["key_derivation_salt"]]
    }
  end

  # Gate vor dem Hochladen: Was waere nach dem Upload auf dem Server nicht mehr lesbar?
  # Jeder AR-primary_key des Servers muss lokal in der Liste stehen, das Salt muss gleich sein.
  # Ohne Credentials auf dem Server (neuer Server) gibt es nichts zu verlieren.
  def self.upload_problems(local_fp, server_fp)
    return [] if server_fp.nil?

    problems = []
    missing = server_fp["primary_key"] - local_fp["primary_key"]
    unless missing.empty?
      problems << "AR-primary_key des Servers fehlt lokal (#{missing.join(", ")}) — verschlüsselte Daten wären unlesbar"
    end
    if server_fp["key_derivation_salt"] && server_fp["key_derivation_salt"] != local_fp["key_derivation_salt"]
      problems << "key_derivation_salt weicht ab — verschlüsselte Daten wären unlesbar"
    end
    problems
  end

  # Ruby-Quelltext fuer `ruby -` auf dem Server: diese Datei plus ein Treiber, der fuer ein
  # Credentials-Verzeichnis (ARGV[0]) Datei-MD5s und Fingerabdruck als JSON ausgibt.
  # Ueber stdin liest Ruby den Quelltext in der Locale-Kodierung — die Umlaute dieser Datei
  # braechen das ohne den Kodierungskommentar vorn (auf dem Server wie lokal).
  def self.remote_fingerprint_script
    "# encoding: utf-8\n" + File.read(__FILE__, encoding: "UTF-8") + <<~RUBY

      store = ScenarioCredentials::Store.new(ARGV[0])
      out = store.file_md5s
      out["fingerprint"] = ScenarioCredentials.fingerprint(store.read) if store.key? && store.enc?
      puts JSON.generate(out)
    RUBY
  end

  # Datei-Seite: production.key und production.yml.enc eines Szenarios. Neu entstehende Dateien
  # tragen Modus 600; ersetzt wird ueber Temp-Dateien, damit Key und .enc nie auseinanderlaufen.
  class Store
    class Error < StandardError; end

    attr_reader :key_path, :enc_path

    def initialize(creds_dir, environment = "production")
      @dir = creds_dir
      @key_path = File.join(creds_dir, "#{environment}.key")
      @enc_path = File.join(creds_dir, "#{environment}.yml.enc")
    end

    def key?
      File.exist?(key_path)
    end

    def enc?
      File.exist?(enc_path)
    end

    def file_md5s
      {"key_md5" => (key? ? Digest::MD5.file(key_path).hexdigest : nil),
       "enc_md5" => (enc? ? Digest::MD5.file(enc_path).hexdigest : nil)}
    end

    def read
      return {} unless enc?

      YAML.safe_load(encrypted(key_path, enc_path).read.to_s, permitted_classes: [Symbol], aliases: true) || {}
    end

    def create(hash)
      raise Error, "Credentials existieren schon (#{@dir}) — Neuanlage würde sie überschreiben" if key? || enc?

      FileUtils.mkdir_p(@dir)
      write_pair(hash)
    end

    # Liefert die Backup-Pfade [key, enc].
    def rotate(hash, timestamp:)
      raise Error, "Rotation braucht Key und .enc (#{@dir})" unless key? && enc?

      backups = [key_path, enc_path].map do |path|
        bak = "#{path}.bak-#{timestamp}"
        raise Error, "Backup existiert schon: #{bak}" if File.exist?(bak)

        FileUtils.cp(path, bak, preserve: true)
        File.chmod(0o600, bak)
        bak
      end
      write_pair(hash)
      backups
    end

    private

    def write_pair(hash)
      tmp_key = "#{key_path}.tmp"
      tmp_enc = "#{enc_path}.tmp"
      File.write(tmp_key, ActiveSupport::EncryptedFile.generate_key)
      File.chmod(0o600, tmp_key)
      encrypted(tmp_key, tmp_enc).write(hash.to_yaml)
      File.chmod(0o600, tmp_enc)
      File.rename(tmp_enc, enc_path)
      File.rename(tmp_key, key_path)
    ensure
      FileUtils.rm_f([tmp_key, tmp_enc].compact)
    end

    def encrypted(key, enc)
      ActiveSupport::EncryptedConfiguration.new(config_path: enc, key_path: key,
        env_key: "RAILS_MASTER_KEY_UNUSED", raise_if_missing_key: true)
    end
  end

  private

  def shared
    @pool["shared"] || {}
  end

  def per
    (@pool["per_scenario"] || {})[@scenario_name] || {}
  end

  def clubcloud_context
    @decl["clubcloud_context"]
  end

  # Einzelwert wird toleriert (Array()), damit ein `region_server_contexts: NBV` nicht still
  # ins Leere laeuft.
  def region_server_contexts
    Array(@decl["region_server_contexts"]).compact
  end

  def merge_pool_keys!(merged)
    added = []
    features.each do |f|
      Array(FEATURE_KEY_GROUPS[f]).each do |grp|
        next unless shared[grp]
        merged[grp] = (merged[grp] || {}).deep_merge(self.class.deep_stringify(shared[grp]))
        added << grp
      end
    end
    # clubcloud (kontext-gewaehlt; per_scenario-Override, sonst shared).
    # WICHTIG: Setting.get_cc_credentials liest mit context.downcase.to_sym →
    # der Credential-Key MUSS kleingeschrieben sein (z.B. clubcloud.nbv).
    if features.include?("clubcloud") && clubcloud_context
      ck = clubcloud_context.to_s.downcase
      cc = per.dig("clubcloud", clubcloud_context) || per.dig("clubcloud", ck) ||
        shared.dig("clubcloud", clubcloud_context) || shared.dig("clubcloud", ck)
      if cc
        merged["clubcloud"] = (merged["clubcloud"] || {}).merge(ck => self.class.deep_stringify(cc))
        added << "clubcloud.#{ck}"
      end
    end
    # Plan 29-05: region_server (Service-Account je Region, gelesen von
    # Carambus.region_server_credentials — Key kleingeschrieben wie clubcloud).
    # Anders als clubcloud eine LISTE: die Authority holt Meldelisten von MEHREREN Region Servern.
    region_server_contexts.each do |ctx|
      rk = ctx.to_s.downcase
      rs = per.dig("region_server", ctx) || per.dig("region_server", rk) ||
        shared.dig("region_server", ctx) || shared.dig("region_server", rk)
      next unless rs

      merged["region_server"] = (merged["region_server"] || {}).merge(rk => self.class.deep_stringify(rs))
      added << "region_server.#{rk}"
    end
    # google_service immer (per_scenario-Override, sonst shared)
    gsvc = per["google_service"] || shared["google_service"]
    if gsvc
      merged["google_service"] = self.class.deep_stringify(gsvc)
      added << "google_service"
    end
    added
  end

  def report(removed:, generated_skb:, added:)
    Report.new(features: features, clubcloud_context: clubcloud_context, removed: removed,
      generated_skb: generated_skb, added: added)
  end

  # ───────────────────────────────────────────────────────────────────────────
  # Sperrliste der Geheimnisse, die je oeffentlich im Repo standen (Audit 2026-09-15).
  #
  # Anlass: Die ROTATE-Laeufe vom 2026-09-14 gingen von STALEN lokalen Dateien aus und
  # haben die oeffentlich bekannten Werte erneut auf die Server verteilt — unbemerkt,
  # weil jede Ausgabe nur "hat sich geaendert" meldet, nie "das ist ein verbrannter Wert".
  # Die Liste fuehrt ausschliesslich SHA256-Summen; ein Geheimnis laesst sich daraus nicht
  # zurueckrechnen, die Datei darf also im Repo liegen. Gefuellt wird sie von
  # `rake scenario:build_credential_denylist` aus der oeffentlichen Git-Historie.
  # ───────────────────────────────────────────────────────────────────────────
  module Denylist
    DEFAULT_PATH = File.expand_path("credential_denylist.yml", __dir__)
    Hit = Struct.new(:path, :hint, keyword_init: true)

    class << self
      # { "<sha256>" => "<Herkunftshinweis>" }
      def fingerprints(path = DEFAULT_PATH)
        return {} unless File.exist?(path)

        data = YAML.safe_load(File.read(path), permitted_classes: [Symbol], aliases: true) || {}
        Array(data["fingerprints"]).each_with_object({}) do |entry, out|
          sha = entry.is_a?(Hash) ? entry["sha256"] : entry
          next if sha.to_s.strip.empty?

          out[sha.to_s.strip.downcase] = (entry.is_a?(Hash) ? entry["hint"] : nil).to_s
        end
      end

      def digest(value)
        Digest::SHA256.hexdigest(value.to_s)
      end

      # Alle Blattwerte gegen die Sperrliste pruefen. Liefert die Treffer mit ihrem
      # Schluesselpfad — nie den Wert selbst.
      def scan(hash, path = DEFAULT_PATH)
        known = fingerprints(path)
        return [] if known.empty?

        hits = []
        each_leaf(hash) do |key_path, value|
          hint = known[digest(value)]
          hits << Hit.new(path: key_path, hint: hint) if hint
        end
        hits
      end

      # Jedes nicht-leere Blatt als (Pfad, Wert) — auch vom Sperrlisten-Builder benutzt.
      def each_leaf(node, prefix = nil, &block)
        case node
        when Hash
          node.each { |k, v| each_leaf(v, [prefix, k].compact.join("."), &block) }
        when Array
          node.each_with_index { |v, i| each_leaf(v, "#{prefix}[#{i}]", &block) }
        else
          yield(prefix.to_s, node) unless node.nil? || node.to_s.empty?
        end
      end
    end
  end
end
