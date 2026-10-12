# frozen_string_literal: true

require "open3"
require "fileutils"

class RegionDump
  # Baut Regionsdumps (Plan 18-02): ein konsistenter Snapshot der Quelle → bereinigte Basis-Kopie →
  # je Region Template-Kopie, cleanup:remove_non_region_records (unveraendert), Pruefung, pg_dump.
  # Temp-Datenbanken werden immer entfernt; ein Fehler in einer Region bricht die uebrigen nicht ab.
  class Builder
    class Error < StandardError; end

    Result = Struct.new(:region, :ok, :message, :seconds, :size, keyword_init: true)

    def initialize(source_db:, out_dir:, regions: :all, log: $stdout)
      @source_db = source_db
      @out_dir = out_dir
      @regions = regions
      @log = log
      @ts = Time.now.strftime("%Y%m%d_%H%M%S")
    end

    def run
      base = "region_dump_base_#{@ts}"
      results = []
      started = Time.now
      last_version_id = build_base(base)
      targets = resolve_regions(base)
      raise Error, "keine passende Region in #{@source_db}" if targets.empty?

      targets.each { |id, shortname| results << build_region(base, id, shortname, last_version_id) }
      say "── fertig in #{(Time.now - started).round} s: #{results.count(&:ok)} von #{results.size} Regionen ok"
      results
    ensure
      dropdb(base)
    end

    private

    def say(msg)
      @log.puts(msg)
    end

    def config
      @config ||= ActiveRecord::Base.connection_db_config.configuration_hash
    end

    def pg_env
      {"PGHOST" => config[:host], "PGPORT" => config[:port], "PGUSER" => config[:username],
       "PGPASSWORD" => config[:password]}.compact.transform_values(&:to_s)
    end

    def database_url(db)
      host = config[:host].presence || "localhost"
      "postgresql://#{host}#{":#{config[:port]}" if config[:port]}/#{db}"
    end

    def sh!(cmd)
      _out, err, status = Open3.capture3(pg_env, "bash", "-o", "pipefail", "-c", cmd)
      raise Error, "#{cmd.split.first} fehlgeschlagen: #{err.lines.last(3).join.strip}" unless status.success?
    end

    def psql_exec!(db, sql)
      _out, err, status = Open3.capture3(pg_env, "psql", "-X", "-q", "-v", "ON_ERROR_STOP=1", "-d", db, "-c", sql)
      raise Error, "SQL fehlgeschlagen: #{err.lines.last.to_s.strip}" unless status.success?
    end

    def psql_value(db, sql)
      out, err, status = Open3.capture3(pg_env, "psql", "-X", "-tA", "-d", db, "-c", sql)
      raise Error, "SQL fehlgeschlagen: #{err.lines.last.to_s.strip}" unless status.success?

      out.strip
    end

    def dropdb(db)
      system(pg_env, "dropdb", "--if-exists", db, out: File::NULL, err: File::NULL)
    end

    # Konsistenz: Daten und last_version_id aus EINEM Snapshot (pg_export_snapshot + pg_dump --snapshot).
    # Die Transaktion bleibt offen, bis pg_dump fertig ist.
    def build_base(base)
      say "── Basis: Snapshot von #{@source_db} (ohne Versionsdaten) → #{base}"
      t = Time.now
      sh!("createdb #{base}")
      conn = PG.connect({dbname: @source_db, host: config[:host], port: config[:port], user: config[:username],
                         password: config[:password]}.compact)
      begin
        conn.exec("BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY")
        snapshot = conn.exec("SELECT pg_export_snapshot()").getvalue(0, 0)
        last_version_id = conn.exec("SELECT COALESCE(MAX(id), 0) FROM versions").getvalue(0, 0).to_i
        sh!("pg_dump --snapshot=#{snapshot} --no-owner --no-privileges --exclude-table-data=versions #{@source_db} " \
            "| psql -X -q -v ON_ERROR_STOP=1 -d #{base} > /dev/null")
        conn.exec("COMMIT")
      ensure
        conn.close
      end
      RegionDump::SANITIZE.each { |_label, sql| psql_exec!(base, sql) }
      psql_exec!(base, RegionDump.last_version_sql(last_version_id))
      say "   Basis fertig in #{(Time.now - t).round} s, last_version_id #{last_version_id}, bereinigt: " \
          "#{RegionDump::SANITIZE.map(&:first).join(", ")}"
      last_version_id
    end

    # Regionen mit Clubs und einem Kuerzel aus Grossbuchstaben (ohne Platzhalter UNKNOWN).
    def resolve_regions(base)
      rows = psql_value(base, "SELECT DISTINCT r.id, UPPER(r.shortname) FROM regions r JOIN clubs c ON c.region_id = r.id " \
                              "WHERE UPPER(r.shortname) ~ '^[A-Z]+$' AND UPPER(r.shortname) <> 'UNKNOWN' ORDER BY 2")
      all = rows.lines.map do |l|
        id, s = l.strip.split("|")
        [id.to_i, s]
      end
      return all if @regions == :all

      wanted = Array(@regions).map { |r| r.to_s.upcase }
      unknown = wanted - all.map(&:last)
      raise Error, "unbekannte Region(en) oder ohne Clubs: #{unknown.join(", ")}" if unknown.any?

      all.select { |_, s| wanted.include?(s) }
    end

    def build_region(base, region_id, shortname, last_version_id)
      t = Time.now
      db = "region_dump_#{shortname.downcase}_#{@ts}"
      dir = File.join(@out_dir, shortname)
      FileUtils.mkdir_p(dir, mode: 0o750)
      sh!("createdb --template=#{base} #{db}")
      filter!(db, shortname, dir)
      failed = RegionDump::CHECKS.merge(RegionDump.region_checks(region_id))
        .reject { |_label, sql| psql_value(db, sql) == "0" }.keys
      raise Error, "Prüfung gescheitert: #{failed.join(", ")} — kein Dump abgelegt" if failed.any?

      schema_version = psql_value(db, "SELECT MAX(version) FROM schema_migrations")
      file = write_dump(db, dir, shortname)
      manifest = RegionDump.manifest(region: shortname, file: file, last_version_id: last_version_id,
        schema_version: schema_version, created_at: Time.now)
      publish(dir, file, manifest)
      result = Result.new(region: shortname, ok: true, message: manifest["file"], seconds: (Time.now - t).round,
        size: manifest["size"])
      say "   ✅ #{shortname}: #{manifest["file"]} (#{(manifest["size"] / 1024.0 / 1024).round(1)} MB, #{result.seconds} s)"
      result
    rescue Error => e
      say "   ❌ #{shortname}: #{e.message}"
      Result.new(region: shortname, ok: false, message: e.message, seconds: (Time.now - t).round)
    ensure
      dropdb(db)
    end

    # Der Filter bleibt der bestehende Rake-Task (Subprozess gegen die Region-DB); Ausgabe ins Region-Log.
    def filter!(db, shortname, dir)
      env = pg_env.merge("REGION_SHORTNAME" => shortname, "DATABASE_URL" => database_url(db),
        "RAILS_ENV" => Rails.env, "DOCS_AUTO_REBUILD" => "0")
      ok = system(env, Rails.root.join("bin/rails").to_s, "cleanup:remove_non_region_records",
        chdir: Rails.root.to_s, out: [File.join(dir, "filter.log"), "w", 0o640], err: [:child, :out])
      raise Error, "Regionsfilter fehlgeschlagen (#{File.join(dir, "filter.log")})" unless ok
    end

    def write_dump(db, dir, shortname)
      file = File.join(dir, RegionDump.dump_name(shortname, Time.now))
      sh!("pg_dump --no-owner --no-privileges #{db} | gzip > #{file}.part")
      File.chmod(0o640, "#{file}.part")
      File.rename("#{file}.part", file)
      file
    end

    def publish(dir, file, manifest)
      json_tmp = File.join(dir, "latest.json.tmp")
      File.write(json_tmp, JSON.pretty_generate(manifest))
      File.chmod(0o640, json_tmp)
      File.rename(json_tmp, File.join(dir, "latest.json"))
      link_tmp = File.join(dir, "latest.sql.gz.tmp")
      FileUtils.rm_f(link_tmp)
      File.symlink(File.basename(file), link_tmp)
      File.rename(link_tmp, File.join(dir, "latest.sql.gz"))
      RegionDump.expired(Dir.children(dir)).each { |f| FileUtils.rm_f(File.join(dir, f)) }
    end
  end
end
