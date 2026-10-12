# frozen_string_literal: true

# Regionsdumps der Authority (Plan 18-02) — Regeln in lib/region_dump.rb, Ablauf in lib/region_dump/builder.rb,
# Betrieb in docs/administrators/region-dumps.
namespace :region_dump do
  def region_dump_dir
    ENV["REGION_DUMP_DIR"].presence || File.expand_path("../../shared/region_dumps", Rails.root)
  end

  desc "Regionsdumps bauen: REGION (z. B. NBV) oder all. Nur auf der Authority; lokal nur mit SOURCE_DB=<db> " \
       "(und REGION_DUMP_DIR). Usage: rake \"region_dump:build[all]\""
  task :build, [:region] => :environment do |_, args|
    source_db = ENV["SOURCE_DB"].presence
    if ApplicationRecord.local_server? && source_db.nil?
      puts "❌ Regionsdumps entstehen auf der Authority. Für einen lokalen Test SOURCE_DB=<db> setzen."
      exit 1
    end
    region = args[:region].to_s.strip
    if region.empty?
      puts "Usage: rake \"region_dump:build[NBV]\" oder \"region_dump:build[all]\""
      exit 1
    end
    source_db ||= ActiveRecord::Base.connection_db_config.database
    out_dir = region_dump_dir
    FileUtils.mkdir_p(out_dir, mode: 0o750)
    puts "── region_dump:build[#{region}] Quelle #{source_db} → #{out_dir}"
    results = RegionDump::Builder.new(source_db: source_db, out_dir: out_dir,
      regions: region.casecmp?("all") ? :all : region.split(/[\s,]+/)).run
    results.each do |r|
      puts format("   %-6s %s %s", r.region, r.ok ? "ok    " : "FEHLER", r.message)
    end
    exit 1 unless results.all?(&:ok)
  rescue RegionDump::Builder::Error => e
    puts "❌ #{e.message}"
    exit 1
  end

  def region_dump_htpasswd(region)
    region = region.to_s.strip.upcase
    unless RegionDump::REGION.match?(region) && Region.where("UPPER(shortname) = ?", region).exists?
      puts "❌ Unbekannte Region: #{region.inspect}"
      exit 1
    end
    dir = File.join(region_dump_dir, ".htpasswd")
    FileUtils.mkdir_p(dir, mode: 0o750)
    [region, File.join(dir, region)]
  end

  def region_dump_write(path, text)
    tmp = "#{path}.tmp"
    File.write(tmp, text)
    File.chmod(0o640, tmp)
    File.rename(tmp, path)
  end

  desc "Zugang zum Regionsdump ausgeben (neues Passwort, einmalig angezeigt). Usage: rake \"region_dump:grant[NBV,bc-wedel]\""
  task :grant, [:region, :login] => :environment do |_, args|
    region, path = region_dump_htpasswd(args[:region])
    login = RegionDump.valid_login!(args[:login])
    password = SecureRandom.alphanumeric(24)
    existed = RegionDump.htpasswd_logins(File.exist?(path) ? File.read(path) : "").include?(login)
    region_dump_write(path, RegionDump.htpasswd_set(File.exist?(path) ? File.read(path) : "", login, RegionDump.apr1(password)))
    puts "✅ Zugang #{existed ? "erneuert" : "angelegt"} für #{region}: #{login}"
    puts "   Passwort (wird nicht noch einmal angezeigt): #{password}"
    puts "   Abruf: https://api.carambus.de/region_dumps/#{region}/latest.json"
  rescue ArgumentError => e
    puts "❌ #{e.message}"
    exit 1
  end

  desc "Zugang zum Regionsdump entziehen. Usage: rake \"region_dump:revoke[NBV,bc-wedel]\""
  task :revoke, [:region, :login] => :environment do |_, args|
    region, path = region_dump_htpasswd(args[:region])
    text, removed = RegionDump.htpasswd_remove(File.exist?(path) ? File.read(path) : "", args[:login])
    unless removed
      puts "❌ Kein Zugang #{args[:login].inspect} für #{region}"
      exit 1
    end
    region_dump_write(path, text)
    puts "✅ Zugang entzogen: #{region}/#{args[:login]}"
  end

  desc "Zugänge zu den Regionsdumps auflisten (nur Logins)"
  task list: :environment do
    dir = File.join(region_dump_dir, ".htpasswd")
    files = Dir.exist?(dir) ? Dir.children(dir).grep(RegionDump::REGION).sort : []
    puts(files.empty? ? "Keine Zugänge vergeben (#{dir})" : "Zugänge (#{dir}):")
    files.each { |r| puts "   #{r}: #{RegionDump.htpasswd_logins(File.read(File.join(dir, r))).join(", ").presence || "—"}" }
  end
end
