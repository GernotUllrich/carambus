# frozen_string_literal: true

require "test_helper"

# Credentials eines Carambus-Servers (Plan 18-01).
#
# Teil 1 nagelt das Verhalten von scenario:generate_credentials fest, wie es vor
# dem Umbau war (Merge aus secrets.yml in den Bestand). Belegt zusaetzlich per
# Digest-Vergleich alt/neu ueber alle 8 Szenarien (18-01-SUMMARY).
class ScenarioCredentialsTest < ActiveSupport::TestCase
  POOL = {
    "shared" => {
      "anthropic" => {"api_key" => "shared-anthropic"},
      "deepl" => {"key" => "shared-deepl"},
      "google" => {"translate_api_key" => "shared-google"},
      "youtube" => {"api_key" => "shared-youtube"},
      "kozoom" => {"email" => "k@example.org", "password" => "shared-kozoom"},
      "google_service" => {"client_email" => "svc@example.org", "private_key" => "shared-pk"},
      "clubcloud" => {"nbv" => {"username" => "nbv-user", "password" => "nbv-pw"}},
      "region_server" => {"nbv" => {"email" => "rs-nbv@example.org", "password" => "rs-pw"}}
    },
    "per_scenario" => {
      "carambus_test" => {
        "google_service" => {"client_email" => "own@example.org", "private_key" => "own-pk"},
        "clubcloud" => {"NBV" => {"username" => "own-user", "password" => "own-pw"}}
      }
    }
  }.freeze

  EXISTING = {
    "secret_key_base" => "bestand-skb",
    "active_record_encryption" => {"primary_key" => "bestand-pk", "deterministic_key" => "bestand-dk",
                                   "key_derivation_salt" => "bestand-salt"},
    "anthropic" => {"api_key" => "alt", "model" => "bleibt"},
    "anthropic_key" => "flach-alt",
    "stripe" => {"private_key" => "vorlagenrest"},
    "location_id" => 1
  }.freeze

  def credentials(existing: EXISTING, pool: POOL, decl: {}, scenario_name: "carambus_test")
    ScenarioCredentials.new(existing: existing, pool: pool, decl: decl, scenario_name: scenario_name)
  end

  def merged(...)
    credentials(...).merged
  end

  # --- Teil 1: heutiges Verhalten (AC-1) -------------------------------------------------------

  test "ohne features gelten ai und translation" do
    hash, report = merged
    assert_equal %w[ai translation], report.features
    assert_equal "shared-anthropic", hash.dig("anthropic", "api_key")
    assert_equal "shared-deepl", hash.dig("deepl", "key")
    assert_equal "shared-google", hash.dig("google", "translate_api_key")
    assert_nil hash["youtube"]
    assert_nil hash["kozoom"]
  end

  test "Pool-Keys werden in den Bestand gemergt, nicht ersetzt" do
    hash, = merged
    assert_equal "bleibt", hash.dig("anthropic", "model")
  end

  test "scraping bringt youtube und kozoom" do
    hash, = merged(decl: {"features" => %w[scraping]})
    assert_equal "shared-youtube", hash.dig("youtube", "api_key")
    assert_equal "shared-kozoom", hash.dig("kozoom", "password")
    assert_nil hash["deepl"]
  end

  test "google_service kommt immer, per_scenario vor shared" do
    hash, report = merged(decl: {"features" => %w[scraping]})
    assert_equal "own-pk", hash.dig("google_service", "private_key")
    assert_includes report.added, "google_service"

    other, = merged(scenario_name: "carambus_other")
    assert_equal "shared-pk", other.dig("google_service", "private_key")
  end

  test "clubcloud nur mit Feature und Kontext, Schluessel kleingeschrieben, per_scenario vor shared" do
    without_feature, = merged(decl: {"clubcloud_context" => "NBV"})
    assert_nil without_feature["clubcloud"]

    without_context, = merged(decl: {"features" => %w[clubcloud]})
    assert_nil without_context["clubcloud"]

    hash, report = merged(decl: {"features" => %w[clubcloud], "clubcloud_context" => "NBV"})
    assert_equal({"username" => "own-user", "password" => "own-pw"}, hash.dig("clubcloud", "nbv"))
    assert_includes report.added, "clubcloud.nbv"

    other, = merged(decl: {"features" => %w[clubcloud], "clubcloud_context" => "NBV"}, scenario_name: "carambus_other")
    assert_equal "nbv-pw", other.dig("clubcloud", "nbv", "password")
  end

  test "region_server als Liste, Einzelwert toleriert, unbekannter Kontext uebersprungen" do
    hash, report = merged(decl: {"region_server_contexts" => %w[NBV BVNR]})
    assert_equal "rs-pw", hash.dig("region_server", "nbv", "password")
    assert_nil hash.dig("region_server", "bvnr")
    assert_equal ["region_server.nbv"], report.added.grep(/region_server/)

    single, = merged(decl: {"region_server_contexts" => "NBV"})
    assert_equal "rs-pw", single.dig("region_server", "nbv", "password")
  end

  test "historische flache Leaves werden entfernt und gemeldet" do
    hash, report = merged
    refute hash.key?("anthropic_key")
    assert_equal %w[anthropic_key], report.removed
  end

  test "secret_key_base bleibt, wenn vorhanden" do
    hash, report = merged
    assert_equal "bestand-skb", hash["secret_key_base"]
    refute report.generated_skb
  end

  test "secret_key_base entsteht nur bei Leere" do
    hash, report = merged(existing: EXISTING.merge("secret_key_base" => " "))
    assert_equal 128, hash["secret_key_base"].length
    assert report.generated_skb
  end

  test "Vorlagenreste, AR-Schluessel und location_id bleiben unveraendert" do
    hash, = merged
    assert_equal EXISTING["stripe"], hash["stripe"]
    assert_equal EXISTING["active_record_encryption"], hash["active_record_encryption"]
    assert_equal 1, hash["location_id"]
  end

  test "Symbol-Schluessel im Bestand werden zu Strings" do
    hash, = merged(existing: {secret_key_base: "sym-skb", location_id: 2})
    assert_equal "sym-skb", hash["secret_key_base"]
    assert_equal 2, hash["location_id"]
  end

  test "leerer Pool fuegt nichts hinzu" do
    hash, report = merged(pool: {})
    assert_empty report.added
    assert_equal "alt", hash.dig("anthropic", "api_key")
  end

  # --- Teil 2: Neuanlage (AC-2) ----------------------------------------------------------------

  test "Neuanlage erzeugt eigene Geheimnisse" do
    hash, = credentials(existing: {}).created
    assert_equal 128, hash["secret_key_base"].length
    assert_equal 128, hash["devise_jwt_secret_key"].length
    refute_equal hash["secret_key_base"], hash["devise_jwt_secret_key"]
    ar = hash["active_record_encryption"]
    %w[primary_key deterministic_key key_derivation_salt].each do |k|
      assert_match(/\A[A-Za-z0-9]{32}\z/, ar[k], k)
    end
  end

  test "zwei Neuanlagen teilen kein Geheimnis" do
    a, = credentials(existing: {}).created
    b, = credentials(existing: {}).created
    refute_equal a["secret_key_base"], b["secret_key_base"]
    refute_equal a["devise_jwt_secret_key"], b["devise_jwt_secret_key"]
    %w[primary_key deterministic_key key_derivation_salt].each do |k|
      refute_equal a.dig("active_record_encryption", k), b.dig("active_record_encryption", k), k
    end
  end

  test "Neuanlage uebernimmt nur Pool-Keys, keinen Bestand" do
    hash, report = credentials(existing: EXISTING).created
    assert_equal "shared-anthropic", hash.dig("anthropic", "api_key")
    assert_equal "own-pk", hash.dig("google_service", "private_key")
    assert_includes report.added, "google_service"
    refute hash.key?("stripe")
    refute hash.key?("location_id")
    refute_equal "bestand-skb", hash["secret_key_base"]
  end

  test "Neuanlage mit leerem Pool enthaelt nur die Geheimnisse" do
    hash, = credentials(existing: {}, pool: {}).created
    assert_equal %w[active_record_encryption devise_jwt_secret_key secret_key_base], hash.keys.sort
  end

  # --- Teil 3: Rotation (AC-3) -----------------------------------------------------------------

  test "Rotation tauscht secret_key_base und JWT-Secret" do
    hash, = credentials.rotated
    refute_equal "bestand-skb", hash["secret_key_base"]
    assert_equal 128, hash["secret_key_base"].length
    assert_equal 128, hash["devise_jwt_secret_key"].length
  end

  test "Rotation macht den primary_key zur Liste alt, neu und laesst Salt und deterministic_key" do
    hash, = credentials.rotated
    ar = hash["active_record_encryption"]
    assert_equal 2, ar["primary_key"].size
    assert_equal "bestand-pk", ar["primary_key"].first
    assert_match(/\A[A-Za-z0-9]{32}\z/, ar["primary_key"].last)
    assert_equal "bestand-salt", ar["key_derivation_salt"]
    assert_equal "bestand-dk", ar["deterministic_key"]
  end

  test "Rotation laesst alle uebrigen Eintraege wertgleich und mergt keinen Pool" do
    hash, = credentials.rotated
    rest = ->(h) { h.except("secret_key_base", "devise_jwt_secret_key", "active_record_encryption") }
    assert_equal rest.call(EXISTING), rest.call(hash)
  end

  test "zweite Rotation haengt an, statt alte Schluessel zu verlieren" do
    once, = credentials.rotated
    twice, = credentials(existing: once).rotated
    keys = twice.dig("active_record_encryption", "primary_key")
    assert_equal 3, keys.size
    assert_equal once.dig("active_record_encryption", "primary_key"), keys.first(2)
  end

  test "Rotation ohne AR-Schluessel legt ihn vollstaendig an" do
    hash, = credentials(existing: {"secret_key_base" => "x"}).rotated
    ar = hash["active_record_encryption"]
    assert_equal 1, ar["primary_key"].size
    assert ar["key_derivation_salt"].present?
  end

  test "Chiffrat vom alten Schluessel ist nach der Rotation lesbar" do
    rotated, = credentials.rotated
    old_ar = EXISTING["active_record_encryption"]
    new_ar = rotated["active_record_encryption"]

    ciphertext = encryptor.encrypt("geheim", key_provider: key_provider(old_ar["primary_key"], old_ar["key_derivation_salt"]))
    clear = encryptor.decrypt(ciphertext, key_provider: key_provider(new_ar["primary_key"], new_ar["key_derivation_salt"]))
    assert_equal "geheim", clear
  end

  test "mit anderem Salt ist das alte Chiffrat nicht lesbar (Grund, das Salt zu behalten)" do
    old_ar = EXISTING["active_record_encryption"]
    ciphertext = encryptor.encrypt("geheim", key_provider: key_provider(old_ar["primary_key"], old_ar["key_derivation_salt"]))
    assert_raises(ActiveRecord::Encryption::Errors::Decryption) do
      encryptor.decrypt(ciphertext, key_provider: key_provider(old_ar["primary_key"], "anderes-salt"))
    end
  end

  test "neue Werte verschluesselt der letzte Schluessel der Liste" do
    rotated, = credentials.rotated
    new_ar = rotated["active_record_encryption"]
    salt = new_ar["key_derivation_salt"]
    ciphertext = encryptor.encrypt("neu", key_provider: key_provider(new_ar["primary_key"], salt))
    assert_equal "neu", encryptor.decrypt(ciphertext, key_provider: key_provider(new_ar["primary_key"].last, salt))
    assert_raises(ActiveRecord::Encryption::Errors::Decryption) do
      encryptor.decrypt(ciphertext, key_provider: key_provider(new_ar["primary_key"].first, salt))
    end
  end

  # --- Teil 4: Dateien (Store) -----------------------------------------------------------------

  test "Store legt Key und .enc mit Modus 600 an und liest sie zurueck" do
    Dir.mktmpdir do |dir|
      store = ScenarioCredentials::Store.new(File.join(dir, "credentials"))
      hash, = credentials(existing: {}, pool: {}).created
      store.create(hash)
      assert_equal "600", mode(store.key_path)
      assert_equal "600", mode(store.enc_path)
      assert_equal hash, store.read
      assert_empty Dir[File.join(dir, "credentials", "*.tmp")]
    end
  end

  test "Store verweigert die Neuanlage ueber vorhandene Dateien" do
    Dir.mktmpdir do |dir|
      store = ScenarioCredentials::Store.new(dir)
      File.write(store.enc_path, "x")
      assert_raises(ScenarioCredentials::Store::Error) { store.create({"a" => 1}) }
      assert_equal "x", File.read(store.enc_path)
    end
  end

  test "Store rotiert mit Backup; der alte Key oeffnet nur noch das Backup" do
    Dir.mktmpdir do |dir|
      store = ScenarioCredentials::Store.new(dir)
      store.create({"secret_key_base" => "alt"})
      old_key = File.read(store.key_path)

      backups = store.rotate({"secret_key_base" => "neu"}, timestamp: "20260913120000")

      assert_equal [store.key_path, store.enc_path].map { |p| "#{p}.bak-20260913120000" }, backups
      backups.each { |b| assert_equal "600", mode(b) }
      refute_equal old_key, File.read(store.key_path)
      assert_equal({"secret_key_base" => "neu"}, store.read)
      old = ActiveSupport::EncryptedConfiguration.new(config_path: backups.last, key_path: backups.first,
        env_key: "UNUSED", raise_if_missing_key: true)
      assert_equal "alt", YAML.safe_load(old.read)["secret_key_base"]
    end
  end

  test "Store rotiert nicht ohne Key und .enc und ueberschreibt kein Backup" do
    Dir.mktmpdir do |dir|
      store = ScenarioCredentials::Store.new(dir)
      assert_raises(ScenarioCredentials::Store::Error) { store.rotate({}, timestamp: "1") }

      store.create({"a" => 1})
      store.rotate({"a" => 2}, timestamp: "1")
      assert_raises(ScenarioCredentials::Store::Error) { store.rotate({"a" => 3}, timestamp: "1") }
      assert_equal({"a" => 2}, store.read)
    end
  end

  # --- Teil 5: Fingerabdruck und Upload-Gate (pull/upload_credentials) --------------------------

  test "Fingerabdruck enthaelt nur Hash-Praefixe, keine Werte" do
    fp = ScenarioCredentials.fingerprint(EXISTING)
    assert_equal Digest::SHA256.hexdigest("bestand-skb")[0, 12], fp["secret_key_base"]
    assert_equal [Digest::SHA256.hexdigest("bestand-pk")[0, 12]], fp["primary_key"]
    assert_nil fp["devise_jwt_secret_key"]
    refute_includes fp.to_json, "bestand"
  end

  test "Fingerabdruck ist fuer Symbol- und String-Schluessel gleich" do
    sym = {secret_key_base: "bestand-skb", active_record_encryption: {primary_key: "bestand-pk"}}
    assert_equal ScenarioCredentials.fingerprint(EXISTING).slice("secret_key_base", "primary_key"),
      ScenarioCredentials.fingerprint(sym).slice("secret_key_base", "primary_key")
  end

  test "Gate: nach einer Rotation darf hochgeladen werden" do
    rotated, = credentials.rotated
    assert_empty ScenarioCredentials.upload_problems(ScenarioCredentials.fingerprint(rotated), ScenarioCredentials.fingerprint(EXISTING))
  end

  test "Gate: neuer Server ohne Credentials" do
    assert_empty ScenarioCredentials.upload_problems(ScenarioCredentials.fingerprint(EXISTING), nil)
  end

  test "Gate: veraltete Kopie verlöre den AR-Schluessel des Servers" do
    server, = credentials.rotated # Server ist weiter als die lokale Kopie
    problems = ScenarioCredentials.upload_problems(ScenarioCredentials.fingerprint(EXISTING), ScenarioCredentials.fingerprint(server))
    assert_equal 1, problems.size
    assert_match(/primary_key des Servers fehlt lokal/, problems.first)
  end

  test "Gate: anderes Salt" do
    other = EXISTING.merge("active_record_encryption" => EXISTING["active_record_encryption"].merge("key_derivation_salt" => "x"))
    problems = ScenarioCredentials.upload_problems(ScenarioCredentials.fingerprint(other), ScenarioCredentials.fingerprint(EXISTING))
    assert(problems.any? { |p| p.include?("key_derivation_salt") })
  end

  test "Server-Skript laeuft per ruby - und liefert dieselben Werte wie lokal" do
    Dir.mktmpdir do |dir|
      store = ScenarioCredentials::Store.new(dir)
      store.create(EXISTING)
      out, err, status = Open3.capture3(RbConfig.ruby, "-rbundler/setup", "-", dir,
        stdin_data: ScenarioCredentials.remote_fingerprint_script)
      assert status.success?, err
      remote = JSON.parse(out.lines.last)
      assert_equal store.file_md5s, remote.slice("key_md5", "enc_md5")
      assert_equal ScenarioCredentials.fingerprint(EXISTING), remote["fingerprint"]
    end
  end

  test "Server-Skript ohne Credentials liefert leere Pruefsummen" do
    Dir.mktmpdir do |dir|
      out, err, status = Open3.capture3(RbConfig.ruby, "-rbundler/setup", "-", dir,
        stdin_data: ScenarioCredentials.remote_fingerprint_script)
      assert status.success?, err
      assert_equal({"key_md5" => nil, "enc_md5" => nil}, JSON.parse(out.lines.last))
    end
  end

  # ── Sperrliste verbrannter Geheimnisse (Audit 2026-09-15, Punkt 4) ─────────

  test "Denylist findet einen verbrannten Wert mit Pfad und Herkunft" do
    with_denylist("verbrannt" => "production.anthropic.api_key (44cd1b75)") do |path|
      creds = {"anthropic" => {"api_key" => "verbrannt"}, "deepl" => {"key" => "frisch"}}
      hits = ScenarioCredentials::Denylist.scan(creds, path)

      assert_equal 1, hits.size
      assert_equal "anthropic.api_key", hits.first.path
      assert_equal "production.anthropic.api_key (44cd1b75)", hits.first.hint
    end
  end

  test "Denylist meldet nichts bei ausschliesslich frischen Werten" do
    with_denylist("verbrannt" => "production.anthropic.api_key") do |path|
      creds = {"anthropic" => {"api_key" => "frisch"}, "clubcloud" => {"nbv" => {"password" => "auch-frisch"}}}

      assert_empty ScenarioCredentials::Denylist.scan(creds, path)
    end
  end

  test "Denylist prueft auch verschachtelte Gruppen und Arrays" do
    with_denylist("verbrannt" => "hint") do |path|
      creds = {"clubcloud" => {"nbv" => {"password" => "verbrannt"}}, "hosts" => ["ok", "verbrannt"]}
      paths = ScenarioCredentials::Denylist.scan(creds, path).map(&:path)

      assert_equal ["clubcloud.nbv.password", "hosts[1]"], paths.sort
    end
  end

  test "fehlende oder leere Sperrliste blockiert nichts" do
    assert_empty ScenarioCredentials::Denylist.fingerprints(File.join(Dir.tmpdir, "gibt-es-nicht.yml"))
    assert_empty ScenarioCredentials::Denylist.scan({"a" => "b"}, File.join(Dir.tmpdir, "gibt-es-nicht.yml"))
  end

  private

  # Schreibt eine temporaere Sperrliste aus { Klartext => Hinweis } und gibt ihren Pfad weiter.
  def with_denylist(values)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "credential_denylist.yml")
      entries = values.map { |value, hint| {"sha256" => ScenarioCredentials::Denylist.digest(value), "hint" => hint} }
      File.write(path, {"fingerprints" => entries}.to_yaml)
      yield path
    end
  end

  def encryptor
    ActiveRecord::Encryption::Encryptor.new
  end

  # Eigener KeyGenerator je Aufruf: der globale merkt sich das Salt beim ersten Ableiten
  # (KeyGenerator#key_derivation_salt), ein Umsetzen der Config waere danach wirkungslos.
  # Der Provider leitet die Schluessel im Konstruktor ab — also mit dem hier gesetzten Salt.
  def key_provider(passwords, salt)
    before = ActiveRecord::Encryption.config.key_derivation_salt
    ActiveRecord::Encryption.config.key_derivation_salt = salt
    ActiveRecord::Encryption::DerivedSecretKeyProvider.new(passwords, key_generator: ActiveRecord::Encryption::KeyGenerator.new)
  ensure
    ActiveRecord::Encryption.config.key_derivation_salt = before
  end

  def mode(path)
    format("%o", File.stat(path).mode & 0o777)
  end
end
