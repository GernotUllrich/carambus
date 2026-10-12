# frozen_string_literal: true

require "test_helper"

# Einspielen beim Verein (Plan 18-03): Zugang aus secrets.yml, Manifest-Pruefung, \restrict-Filter, Download
# gegen WebMock. Der Ladeweg selbst (createdb, psql, sequence_reset) ist per lokalem Echtlauf belegt.
class RegionDumpFetchTest < ActiveSupport::TestCase
  URL = "https://dumps.example.test"
  BODY = "-- dump\nSELECT 1;\n"
  FILE = "carambus_nbv_20260914_010000.sql.gz"

  def manifest(overrides = {})
    {"region" => "NBV", "file" => FILE, "created_at" => "2026-09-14T01:00:00Z", "last_version_id" => 13_747_200,
     "schema_version" => "20260901000000", "size" => BODY.bytesize,
     "sha256" => Digest::SHA256.hexdigest(BODY)}.merge(overrides)
  end

  def stub_manifest(m = manifest, status: 200)
    stub_request(:get, "#{URL}/region_dumps/NBV/latest.json").with(basic_auth: %w[verein geheim])
      .to_return(status: status, body: JSON.generate(m))
  end

  def stub_file(body = BODY, status: 200)
    stub_request(:get, "#{URL}/region_dumps/NBV/#{FILE}").with(basic_auth: %w[verein geheim])
      .to_return(status: status, body: body)
  end

  def fetch(dir)
    RegionDump::Fetch.new(url: URL, region: "nbv", login: "verein", password: "geheim", dir: dir, log: nil)
  end

  # ── Helfer ──────────────────────────────────────────────────────────────────────────────────────
  test "Zugang aus secrets.yml: fehlender Abschnitt ist nil, unvollstaendiger ein Fehler, url hat einen Default" do
    assert_nil RegionDump.access_from_secrets({}, "carambus_pbv")
    assert_nil RegionDump.access_from_secrets({"per_scenario" => {"carambus_pbv" => {}}}, "carambus_pbv")
    pool = {"per_scenario" => {"carambus_pbv" => {"region_dump" => {"login" => "pbv", "password" => "x"}}}}
    assert_equal({login: "pbv", password: "x", url: RegionDump::DEFAULT_URL}, RegionDump.access_from_secrets(pool, "carambus_pbv"))
    pool["per_scenario"]["carambus_pbv"]["region_dump"]["url"] = "https://other.test/"
    assert_equal "https://other.test", RegionDump.access_from_secrets(pool, "carambus_pbv")[:url]
    pool["per_scenario"]["carambus_pbv"]["region_dump"].delete("password")
    assert_raises(ArgumentError) { RegionDump.access_from_secrets(pool, "carambus_pbv") }
  end

  test "Manifest: fremde Region, fremder Dateiname, fehlende Pruefsumme werden abgewiesen" do
    assert_equal manifest, RegionDump.validate_manifest!(manifest, region: "nbv")
    {"region" => "BVW", "file" => "carambus_bvw_20260914_010000.sql.gz", "sha256" => "abc", "size" => 0,
     "last_version_id" => nil}.each do |key, bad|
      assert_raises(ArgumentError, key) { RegionDump.validate_manifest!(manifest(key => bad), region: "NBV") }
    end
    assert_raises(ArgumentError) { RegionDump.validate_manifest!(manifest("file" => "../../etc/passwd"), region: "NBV") }
  end

  test "psql-Version entscheidet ueber den \\restrict-Filter" do
    refute RegionDump.restrict_supported?("psql (PostgreSQL) 14.15 (Homebrew)")
    assert RegionDump.restrict_supported?("psql (PostgreSQL) 14.19")
    refute RegionDump.restrict_supported?("psql (PostgreSQL) 16.9")
    assert RegionDump.restrict_supported?("psql (PostgreSQL) 16.15 (Ubuntu 16.15-1.pgdg24.04+1)")
    assert RegionDump.restrict_supported?("psql (PostgreSQL) 17.6")
    assert RegionDump.restrict_supported?("psql (PostgreSQL) 18.0")
    refute RegionDump.restrict_supported?("psql (PostgreSQL) 13.20")
    refute RegionDump.restrict_supported?("")
  end

  test "nur die \\restrict-Zeilen werden gefiltert" do
    assert RegionDump.restrict_line?("\\restrict AbC123xyz\n")
    assert RegionDump.restrict_line?("\\unrestrict AbC123xyz\n")
    refute RegionDump.restrict_line?("SELECT '\\restrict x';\n")
    refute RegionDump.restrict_line?("\\connect foo\n")
  end

  # ── Download ────────────────────────────────────────────────────────────────────────────────────
  test "laedt die im Manifest genannte Datei und prueft sie" do
    Dir.mktmpdir do |dir|
      stub_manifest
      stub_file
      path, m = fetch(dir).run
      assert_equal File.join(dir, FILE), path
      assert_equal BODY, File.read(path)
      assert_equal 13_747_200, m["last_version_id"]
      assert_equal "600", format("%o", File.stat(path).mode & 0o777)
      assert_not_requested :get, "#{URL}/region_dumps/NBV/latest.sql.gz"
    end
  end

  test "falsche Pruefsumme: Abbruch, keine Datei bleibt liegen" do
    Dir.mktmpdir do |dir|
      stub_manifest(manifest("sha256" => Digest::SHA256.hexdigest("anders")))
      stub_file
      error = assert_raises(RegionDump::Fetch::Error) { fetch(dir).run }
      assert_match(/sha256/, error.message)
      assert_empty Dir.children(dir)
    end
  end

  test "HTTP-Fehler werden verstaendlich gemeldet, das Passwort nie" do
    {401 => /falsch oder entzogen/, 403 => /kein Zugang eingerichtet/, 404 => /kein Dump/}.each do |status, text|
      WebMock.reset!
      Dir.mktmpdir do |dir|
        stub_manifest(status: status)
        error = assert_raises(RegionDump::Fetch::Error) { fetch(dir).run }
        assert_match text, error.message
        refute_includes error.message, "geheim"
      end
    end
  end

  test "Manifest einer fremden Region wird nicht geladen" do
    Dir.mktmpdir do |dir|
      stub_manifest(manifest("region" => "BVW"))
      assert_raises(RegionDump::Fetch::Error) { fetch(dir).run }
      assert_not_requested :get, "#{URL}/region_dumps/NBV/#{FILE}"
    end
  end

  test "ein bereits vorhandener, intakter Dump wird nicht erneut geladen; aeltere werden aufgeraeumt" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, FILE), BODY)
      %w[20260912_010000 20260913_010000].each { |ts| File.write(File.join(dir, "carambus_nbv_#{ts}.sql.gz"), "alt") }
      stub_manifest
      fetch(dir).run
      assert_not_requested :get, "#{URL}/region_dumps/NBV/#{FILE}"
      assert_equal ["carambus_nbv_20260913_010000.sql.gz", FILE], Dir.children(dir).sort
    end
  end
end
