# frozen_string_literal: true

require "test_helper"

# Regionsdumps (Plan 18-02): Bereinigungsregeln gegen die Test-DB, Pruefungen, Manifest, Aufbewahrung.
# Der Build selbst (Snapshot, Filter, pg_dump) ist per lokalem Echtlauf gegen carambus_api_development belegt
# (18-02-SUMMARY), weil er eigene Datenbanken anlegt.
class RegionDumpTest < ActiveSupport::TestCase
  def conn
    ActiveRecord::Base.connection
  end

  def value(sql)
    conn.select_value(sql).to_s
  end

  def seed_sensitive_rows
    user = User.first || flunk("Fixture-User fehlt")
    tournament = Tournament.first || flunk("Fixture-Turnier fehlt")
    conn.execute("INSERT INTO user_tournaments (user_id, tournament_id, created_at, updated_at) " \
                 "VALUES (#{user.id}, #{tournament.id}, now(), now())")
    conn.execute("INSERT INTO region_ccs (cc_id, context, shortname, username, userpw, created_at, updated_at) " \
                 "VALUES (99001, 'tst', 'TST', 'login', 'klartext', now(), now())")
    conn.execute("INSERT INTO international_sources (name, source_type, api_credentials, created_at, updated_at) " \
                 "VALUES ('Testquelle', 'youtube', 'geheim', now(), now())")
    conn.execute("INSERT INTO ai_usage_events (created_at, updated_at) VALUES (now(), now())")
    conn.execute("INSERT INTO mcp_audit_trails (user_id, tool_name, result, created_at, updated_at) " \
                 "VALUES (#{user.id}, 'test', 'ok', now(), now())")
    conn.execute("INSERT INTO versions (item_type, item_id, event, whodunnit, created_at, updated_at) " \
                 "VALUES ('Club', 1, 'update', 'jemand', now(), now())")
    setting = Setting.first || Setting.create!
    conn.execute("UPDATE settings SET data = '{\"session_id\":{\"String\":\"abc\"},\"session_login_time\":{\"String\":\"x\"}," \
                 "\"context\":{\"String\":\"nbv\"}}' WHERE id = #{setting.id}")
  end

  def sanitize!
    RegionDump::SANITIZE.each { |_label, sql| conn.execute(sql) }
  end

  test "vor der Bereinigung schlagen die Pruefungen an" do
    seed_sensitive_rows
    failing = RegionDump::CHECKS.reject { |_l, sql| value(sql) == "0" }.keys
    %w[users user_tournaments region_ccs-Zugänge international_sources-Zugänge mcp_audit_trails ai_usage_events
      versions settings-Sitzung last_version_id\ fehlt].each { |k| assert_includes failing, k }
  end

  test "nach der Bereinigung und last_version_id sind alle Pruefungen 0" do
    seed_sensitive_rows
    sanitize!
    conn.execute(RegionDump.last_version_sql(13_741_187))
    failing = RegionDump::CHECKS.reject { |_l, sql| value(sql) == "0" }
    assert_empty failing
  end

  test "die Bereinigung laesst uebrige settings-Schluessel stehen und setzt last_version_id im Setting-Format" do
    seed_sensitive_rows
    sanitize!
    conn.execute(RegionDump.last_version_sql(42))
    data = JSON.parse(value("SELECT data FROM settings ORDER BY id LIMIT 1"))
    assert_equal({"String" => "nbv"}, data["context"])
    assert_equal({"Integer" => "42"}, data["last_version_id"])
    refute data.key?("session_id")
  end

  test "Regionspruefung findet fremde Zeilen und laesst NULL/global_context durch" do
    checks = RegionDump.region_checks(1)
    assert_equal RegionDump::REGION_TABLES.size, checks.size
    assert_match(/region_id = 1 OR region_id IS NULL OR global_context = TRUE/, checks["fremde clubs"])
    assert_raises(ArgumentError) { RegionDump.region_checks("1; DROP TABLE clubs") }
  end

  test "last_version_sql nimmt nur Ganzzahlen" do
    assert_raises(ArgumentError) { RegionDump.last_version_sql("1'); DROP TABLE settings; --") }
  end

  test "Manifest traegt Groesse und sha256 der Datei" do
    Dir.mktmpdir do |dir|
      file = File.join(dir, RegionDump.dump_name("nbv", Time.utc(2026, 9, 14, 3, 58, 17)))
      File.write(file, "dump")
      m = RegionDump.manifest(region: "nbv", file: file, last_version_id: "13741187", schema_version: 20260830190000,
        created_at: Time.utc(2026, 9, 14, 3, 58, 19))
      assert_equal "carambus_nbv_20260914_035817.sql.gz", m["file"]
      assert_equal "NBV", m["region"]
      assert_equal 13_741_187, m["last_version_id"]
      assert_equal "20260830190000", m["schema_version"]
      assert_equal 4, m["size"]
      assert_equal Digest::SHA256.hexdigest("dump"), m["sha256"]
      assert_equal "2026-09-14T03:58:19Z", m["created_at"]
    end
  end

  test "Zugang: Zeile anlegen, ersetzen, entfernen" do
    text = RegionDump.htpasswd_set("", "bc-wedel", "$apr1$aaa$x")
    text = RegionDump.htpasswd_set(text, "pbv", "$apr1$bbb$y")
    text = RegionDump.htpasswd_set(text, "bc-wedel", "$apr1$ccc$z")
    assert_equal "pbv:$apr1$bbb$y\nbc-wedel:$apr1$ccc$z\n", text
    assert_equal %w[pbv bc-wedel], RegionDump.htpasswd_logins(text)
    text, removed = RegionDump.htpasswd_remove(text, "bc-wedel")
    assert removed
    assert_equal "pbv:$apr1$bbb$y\n", text
    assert_equal ["", true], RegionDump.htpasswd_remove(text, "pbv")
    refute RegionDump.htpasswd_remove("pbv:x\n", "gibtsnicht").last
  end

  test "Zugang: ungueltige Logins werden abgelehnt" do
    ["a:b", "", "x", "mit leer", "ümlaut"].each do |login|
      assert_raises(ArgumentError, login) { RegionDump.htpasswd_set("", login, "h") }
    end
  end

  test "Zugang: apr1-Hash ist mit demselben Salz reproduzierbar und passt nur zum richtigen Passwort" do
    hash = RegionDump.apr1("geheimes-passwort")
    salt = hash.split("$")[2]
    assert_match(/\A\$apr1\$[^$]+\$/, hash)
    assert_equal hash, RegionDump.apr1("geheimes-passwort", salt: salt)
    refute_equal hash, RegionDump.apr1("falsches-passwort", salt: salt)
  end

  test "Aufbewahrung loescht alle ausser den zwei juengsten Dumps und nichts anderes" do
    files = %w[carambus_nbv_20260912_010000.sql.gz carambus_nbv_20260914_010000.sql.gz latest.json latest.sql.gz
      carambus_nbv_20260913_010000.sql.gz filter.log carambus_nbv_20260911_010000.sql.gz.part]
    assert_equal %w[carambus_nbv_20260912_010000.sql.gz], RegionDump.expired(files)
    assert_empty RegionDump.expired(%w[carambus_nbv_20260914_010000.sql.gz])
  end
end
