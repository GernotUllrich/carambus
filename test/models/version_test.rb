# frozen_string_literal: true

require "test_helper"

class VersionTest < ActiveSupport::TestCase
  # === safe_parse unit tests ===

  test "safe_parse returns hash when given JSON object string" do
    assert_equal({"free_game_form" => "bk2_kombi"}, Version.safe_parse('{"free_game_form":"bk2_kombi"}'))
  end

  test "safe_parse returns array when given JSON array string" do
    assert_equal([1, 2, 3], Version.safe_parse("[1,2,3]"))
  end

  test "safe_parse returns parsed YAML for YAML-formatted hash" do
    yaml_str = "---\nfoo: bar\n"
    assert_equal({"foo" => "bar"}, Version.safe_parse(yaml_str))
  end

  test "safe_parse returns raw string when JSON parse fails" do
    bad = '{"not valid json'
    assert_equal bad, Version.safe_parse(bad)
  end

  test "safe_parse returns blank input unchanged" do
    assert_nil Version.safe_parse(nil)
    assert_equal "", Version.safe_parse("")
  end

  # === safe_parse_for_text_column unit tests ===

  test "safe_parse_for_text_column returns JSON string unchanged" do
    json = '{"free_game_form":"bk2_kombi"}'
    assert_equal json, Version.safe_parse_for_text_column(json)
  end

  test "safe_parse_for_text_column converts YAML-serialized hash back to JSON string" do
    yaml_str = "---\nfree_game_form: bk2_kombi\n"
    result = Version.safe_parse_for_text_column(yaml_str)
    assert_kind_of String, result
    assert_equal({"free_game_form" => "bk2_kombi"}, JSON.parse(result))
  end

  test "safe_parse_for_text_column returns raw on invalid JSON" do
    bad = '{"incomplete'
    assert_equal bad, Version.safe_parse_for_text_column(bad)
  end

  # === coerce_serialized_args! (Sync-Apply-Fix 2026-06-17) ===
  # PlayerRanking: serialize :remarks (type: Hash) + :t_ids (type: Array). Der Sync
  # liefert die Werte als String → write_attribute warf SerializationTypeMismatch,
  # der Apply schlug still fehl, der Cursor lief trotzdem hoch (stiller Verlust).

  test "coerce_serialized_args! parst JSON-String für serialize-Hash-Spalte (remarks)" do
    args = {"remarks" => '{"result":{"GD":1.33,"t_ids":[15754]}}', "gd" => 1.33}
    Version.coerce_serialized_args!(PlayerRanking, args)
    assert_kind_of Hash, args["remarks"]
    assert_equal 1.33, args["remarks"].dig("result", "GD")
    assert_in_delta 1.33, args["gd"], 0.0001 # Nicht-serialisierte Spalte unverändert
  end

  test "coerce_serialized_args! parst JSON-String für serialize-Array-Spalte (t_ids)" do
    args = {"t_ids" => "[15754, 15755]"}
    Version.coerce_serialized_args!(PlayerRanking, args)
    assert_equal [15754, 15755], args["t_ids"]
  end

  test "coerce_serialized_args! lässt Nicht-String-Werte unverändert" do
    args = {"remarks" => {"already" => "hash"}, "rank" => 5}
    Version.coerce_serialized_args!(PlayerRanking, args)
    assert_equal({"already" => "hash"}, args["remarks"])
    assert_equal 5, args["rank"]
  end

  test "coerce_serialized_args! lässt String-Spalten ohne serialize-Coder unverändert" do
    # ba_state ist eine normale string-Spalte (kein serialize) → bleibt String
    args = {"ba_state" => "active"}
    Version.coerce_serialized_args!(PlayerRanking, args)
    assert_equal "active", args["ba_state"]
  end

  test "coerce_serialized_args! ergibt schreibbaren remarks-Hash (kein SerializationTypeMismatch)" do
    pr = PlayerRanking.new
    args = {"remarks" => '{"result":{"GD":2.5}}'}
    Version.coerce_serialized_args!(PlayerRanking, args)
    # Der eigentliche Repro: write_attribute darf NICHT mehr werfen
    assert_nothing_raised { pr.write_attribute("remarks", args["remarks"]) }
    assert_equal 2.5, pr.remarks.dig("result", "GD")
  end

  # === Integration regression — round-trip through update_from_carambus_api ===
  #
  # This tests the exact bug path: update event with no object_changes falls through
  # to YAML.load(h["object"]) and then safe_parse_for_text_column(args["data"]).
  # Without the fix, YAML.load('{"free_game_form":"bk2_kombi"}') returns a Hash,
  # and update_columns rejects it with "can't cast Hash" for the text column.

  test "update_from_carambus_api round-trips Discipline with JSON data column without Hash cast" do
    skip_unless_local_server

    # Pre-create a Discipline so the update path (obj.present?) is exercised.
    # Use id >= MIN_ID so LocalProtector does not block. unprotected flag is set
    # via the ApiProtectorTestOverride in test_helper.
    disc = Discipline.where(id: 50_000_099).first_or_initialize
    disc.name = "TestBK-sync"
    disc.data = nil
    disc.unprotected = true
    disc.save!(validate: false)

    # Build a Version payload mimicking PaperTrail's versions.object YAML dump.
    # No object_changes → triggers the h["object"] fallback branch (the buggy path).
    disc_attrs = {
      "id" => 50_000_099,
      "name" => "TestBK-sync",
      "data" => '{"free_game_form":"bk2_kombi","ballziel_choices":[50,60,70]}',
      "created_at" => disc.created_at,
      "updated_at" => Time.current
    }
    payload = [{
      "id" => 999_999,
      "item_type" => "Discipline",
      "item_id" => 50_000_099,
      "event" => "update",
      "object" => YAML.dump(disc_attrs),
      "object_changes" => nil,
      "created_at" => Time.current.to_s
    }]

    # Stub the HTTP GET that update_from_carambus_api performs internally.
    api_url = Carambus.config.carambus_api_url
    stub_request(:get, /#{Regexp.escape(api_url)}\/versions\/get_updates/)
      .to_return(status: 200, body: payload.to_json, headers: {"Content-Type" => "application/json"})

    assert_nothing_raised do
      Version.update_from_carambus_api({})
    end

    disc.reload
    assert_kind_of String, disc.data, "data column must remain a String (text column) — not cast to Hash"
    parsed = JSON.parse(disc.data)
    assert_equal "bk2_kombi", parsed["free_game_form"]
    assert_equal [50, 60, 70], parsed["ballziel_choices"]
  ensure
    Discipline.where(id: 50_000_099).destroy_all
  end

  # === H1-03 (Phase 41) — Ordered redelivery apply path ===
  # Beweist das exakte Fehlerbild, das diese Phase behebt: eine international
  # organisierte Region wird VOR ihrem organisierten Turnier appliziert (niedrigere
  # Version-id zuerst, siehe get_updates id ASC + Client .shift front-to-back),
  # sodass der belongs_to :organizer beim Turnier-Apply bereits auflösbar ist
  # (kein "Organisiert von muss ausgefüllt werden").

  test "redelivered international tournament applies after its organizer region version is applied first" do
    skip_unless_local_server

    Tournament.where(id: 52_000_251).destroy_all
    Region.where(id: 52_000_250).destroy_all

    region_attrs = {
      "id" => 52_000_250,
      "shortname" => "INTX",
      "name" => "Intl Apply",
      "global_context" => true,
      "region_id" => nil,
      "created_at" => Time.current,
      "updated_at" => Time.current
    }
    tournament_attrs = {
      "id" => 52_000_251,
      "title" => "Intl Apply Tournament",
      "organizer_type" => "Region",
      "organizer_id" => 52_000_250,
      "region_id" => nil,
      "single_or_league" => "single",
      "season_id" => seasons(:current).id,
      "date" => 1.week.from_now,
      "created_at" => Time.current,
      "updated_at" => Time.current
    }

    # Region-Version-id (990_001) < Tournament-Version-id (990_002) — mirrors
    # get_updates .order(id: :asc) + client .shift front-to-back.
    payload = [
      {
        "id" => 990_001,
        "item_type" => "Region",
        "item_id" => 52_000_250,
        "event" => "update",
        "object" => YAML.dump(region_attrs),
        "object_changes" => nil,
        "created_at" => Time.current.to_s
      },
      {
        "id" => 990_002,
        "item_type" => "Tournament",
        "item_id" => 52_000_251,
        "event" => "update",
        "object" => YAML.dump(tournament_attrs),
        "object_changes" => nil,
        "created_at" => Time.current.to_s
      }
    ]

    api_url = Carambus.config.carambus_api_url
    stub_request(:get, /#{Regexp.escape(api_url)}\/versions\/get_updates/)
      .to_return(status: 200, body: payload.to_json, headers: {"Content-Type" => "application/json"})

    assert_nothing_raised do
      Version.update_from_carambus_api({})
    end

    assert Region.exists?(52_000_250), "Organizer-Region muss zuerst angelegt werden (niedrigere Version-id)"
    assert Tournament.exists?(52_000_251), "Turnier muss NACH der Region applien, mit auflösbarem organizer"
  ensure
    Tournament.where(id: 52_000_251).destroy_all
    Region.where(id: 52_000_250).destroy_all
  end

  # === T-CR-01 — Version.local_from_api NameError regression (Phase 38.4-17) ===

  test "T-CR-01-local-from-api-no-raises 38.4-17: Version.local_from_api uses local_server? (predicate)" do
    # Phase 38.4-CR-01: pre-fix, Version.local_from_api at version.rb:434 called
    # `local_server` (no question mark) — a NameError. This test asserts the method
    # invocation completes without raising NameError. Behaviour-wise, it's a no-op
    # when local_server? returns false (typical test-DB state) and triggers
    # sequence_reset when local_server? returns true.
    assert_nothing_raised do
      Version.local_from_api
    end
  end

  test "T-CR-01-local-from-api-stub-true 38.4-17: when local_server? stubbed true, sequence_reset is called" do
    called = false
    Version.stub :local_server?, true do
      Version.stub :sequence_reset, ->() { called = true } do
        Version.local_from_api
      end
    end
    assert_equal true, called,
      "T-CR-01: Version.sequence_reset must be called when local_server? returns true"
  end

  test "T-CR-01-local-from-api-stub-false 38.4-17: when local_server? stubbed false, sequence_reset is NOT called" do
    called = false
    Version.stub :local_server?, false do
      Version.stub :sequence_reset, ->() { called = true } do
        Version.local_from_api
      end
    end
    assert_equal false, called,
      "T-CR-01: Version.sequence_reset must NOT be called when local_server? returns false"
  end

  # === H33 (P1) — Guard gegen leere/nicht-JSON-API-Antwort (kein roher 500) ===

  test "parse_api_json returns nil for blank body" do
    assert_nil Version.parse_api_json("")
    assert_nil Version.parse_api_json(nil)
  end

  test "parse_api_json returns nil for non-JSON body (empty/403)" do
    assert_nil Version.parse_api_json("not json")
    assert_nil Version.parse_api_json("<html>403 Forbidden</html>")
  end

  test "parse_api_json parses valid JSON object and array" do
    assert_equal({"a" => 1}, Version.parse_api_json('{"a":1}'))
    assert_equal([1, 2], Version.parse_api_json("[1,2]"))
  end

  test "update_from_carambus_api raises ApiUnavailableError on empty API body (H33)" do
    Version.stub :http_get_with_ssl_bypass, "" do
      assert_raises(Version::ApiUnavailableError) do
        Version.update_from_carambus_api({})
      end
    end
  end

  test "last_version falls back to local last id on empty API body (H33, no 500)" do
    Version.stub :http_get_with_ssl_bypass, "" do
      expected = Version.last&.id
      # assert_nil statt assert_equal(nil, ...) vermeidet die Minitest-6-Deprecation-Warnung
      # (siehe Phase 41-01: gleiches Muster in region_taggable_sync_test.rb).
      if expected.nil?
        assert_nil Version.last_version
      else
        assert_equal expected, Version.last_version
      end
    end
  end

  test "update_carambus is nil-safe on empty API body (H33, no crash)" do
    Version.stub :http_get_with_ssl_bypass, "" do
      assert_nothing_raised { Version.update_carambus }
    end
  end
  # === http_get_with_ssl_bypass: Statusbehandlung + User-Agent ===
  # Hintergrund: /versions/* liegt auf der Authority hinter dem nginx-Bot-Filter.
  # Ein 403 kam frueher ungeprueft als Rumpf zurueck und landete in JSON.parse —
  # der Sync auf bc-wedel stand dadurch monatelang unbemerkt.

  test "http_get_with_ssl_bypass returns nil on 403 when nil_on_error" do
    stub_request(:get, "https://api.example.test/versions/get_updates")
      .to_return(status: 403, body: "Forbidden\n")
    assert_nil Version.http_get_with_ssl_bypass(
      URI("https://api.example.test/versions/get_updates"), nil_on_error: true
    )
  end

  test "http_get_with_ssl_bypass still returns the body on 403 by default (HTML-Aufrufer unberuehrt)" do
    stub_request(:get, "https://api.example.test/x").to_return(status: 403, body: "Forbidden\n")
    assert_equal "Forbidden\n", Version.http_get_with_ssl_bypass(URI("https://api.example.test/x"))
  end

  test "http_get_with_ssl_bypass returns the body on success even with nil_on_error" do
    stub_request(:get, "https://api.example.test/x").to_return(status: 200, body: "[]")
    assert_equal "[]", Version.http_get_with_ssl_bypass(URI("https://api.example.test/x"), nil_on_error: true)
  end

  test "http_get_with_ssl_bypass sends the named User-Agent" do
    stub = stub_request(:get, "https://api.example.test/x")
      .with(headers: {"User-Agent" => Version::SYNC_USER_AGENT})
      .to_return(status: 200, body: "[]")
    Version.http_get_with_ssl_bypass(URI("https://api.example.test/x"))
    assert_requested(stub)
  end

  test "SYNC_USER_AGENT trips none of the nginx bot-block patterns" do
    # Muster gespiegelt aus templates/nginx/carambus_bot_block.conf
    # (map $http_user_agent $carambus_block_bot). Faellt der Agent hier durch,
    # antwortet die Authority mit 403 und der Sync steht still.
    refute_empty Version::SYNC_USER_AGENT, "leerer User-Agent wird vom Bot-Filter geblockt"
    refute_match(/(bot|crawler|spider|scraper|wget|curl\/|python-requests)/i,
      Version::SYNC_USER_AGENT)
  end

  # === Phase 37-01: Apply-Loop — ungueltige Records duerfen nicht zurueckgesetzt werden ===
  #
  # WARUM DIESE TESTS NICHT `skip_unless_local_server` NUTZEN: Die beiden vorhandenen Apply-Tests
  # (Zeile 99 und 155) skippen in DIESEM Repo, weil carambus_api ohne `carambus_api_url` laeuft — der
  # Apply-Loop ist hier also faktisch ungetestet. Fuer einen Eingriff in die Replikationsgrundlage
  # aller Regional-Server ist das zu wenig. `Carambus.config=` erlaubt es, die URL fuer die Dauer
  # eines Tests zu setzen; damit laeuft der Loop auch auf der Authority.

  def with_api_url(url = "https://api.example.test")
    previous = Carambus.config
    Carambus.config = OpenStruct.new(previous.to_h.merge(carambus_api_url: url))
    yield
  ensure
    Carambus.config = previous
  end

  def apply_version(item_type:, item_id:, object:, object_changes: nil, version_id: 999_001)
    payload = [{
      "id" => version_id,
      "item_type" => item_type,
      "item_id" => item_id,
      "event" => "update",
      "object" => YAML.dump(object),
      "object_changes" => object_changes.present? ? YAML.dump(object_changes) : nil,
      "created_at" => Time.current.to_s
    }]
    with_api_url do
      stub_request(:get, %r{/versions/get_updates})
        .to_return(status: 200, body: payload.to_json, headers: {"Content-Type" => "application/json"})
      Version.update_from_carambus_api({})
    end
  end

  # Der Sammel-Reset passiert am Ende von update_from_carambus_api, deshalb faengt der Test das Log.
  def capture_sync_log
    io = StringIO.new
    previous = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = previous
  end

  # Eine GLOBALE Liga (id < MIN_ID), die eine heute noch greifende Validierung verletzt.
  #
  # NICHT MEHR UEBER `shortname`: seit `07d82ec0` gilt die Pflicht nur noch `on: :create` — der
  # BillardArea-Altbestand konnte sie nie erfuellen, und jeder Massenlauf kippte daran.
  # Bestandsrecords sind damit gueltig.
  #
  # STATTDESSEN DIE `cc_id`-EINDEUTIGKEIT (greift weiterhin auf UPDATE): zwei Ligen derselben Region
  # und Saison mit derselben `cc_id`. Bewusst NICHT die Namens-Eindeutigkeit — die haengt am `name`,
  # und Tests, die den Namen umschreiben (Snapshot-Faelle), machten den Record dabei versehentlich
  # wieder gueltig.
  def invalid_global_league(id: 3_700_001)
    shared = {organizer_type: "Region", organizer_id: regions(:nbv).id,
              season: seasons(:current), cc_id: 880_000 + (id % 1000)}

    twin = League.new(shared.merge(id: id + 10_000_000, name: "Zwilling #{id}", shortname: "ZW"))
    twin.unprotected = true
    twin.save!(validate: false)

    l = League.new(shared.merge(id: id, name: "Alt-Liga #{id}", shortname: "AL"))
    l.unprotected = true
    l.save!(validate: false)
    assert_not l.valid?, "Testvoraussetzung: der Record muss ungueltig sein"
    l
  end

  # AC-1 — der Hauptbefund. Vor dem Fix schreibt der Apply den PaperTrail-`object`-Snapshot zurueck,
  # und der ist der Zustand VOR der Aenderung: source_kind bliebe nil.
  test "AC-1: eine Aenderung an einem ungueltigen Record kommt an" do
    league = invalid_global_league
    snapshot = league.attributes.merge("source_kind" => nil)

    apply_version(item_type: "League", item_id: league.id, object: snapshot,
      object_changes: {"source_kind" => [nil, "ba"]})

    assert_equal "ba", league.reload.source_kind,
      "der neue Wert muss stehen — nicht der Zustand vor der Aenderung"
  end

  # AC-2 — die Absicht des Fallbacks bleibt: vollstaendiger Datensatz statt unvollstaendigem Delta.
  test "AC-2: der Fallback schreibt den vollen Snapshot, die neuen Werte gewinnen" do
    league = invalid_global_league(id: 3_700_002)
    league.update_column(:name, "lokal abgewichen")
    snapshot = league.attributes.merge("name" => "Stand der Authority", "source_kind" => nil)

    apply_version(item_type: "League", item_id: league.id, object: snapshot,
      object_changes: {"source_kind" => [nil, "ba"]}, version_id: 999_002)

    league.reload
    assert_equal "ba", league.source_kind, "die Aenderung gewinnt"
    assert_equal "Stand der Authority", league.name, "und der Rest kommt aus dem vollen Snapshot"
  end

  # AC-4 — derselbe Denkfehler an der zweiten Fundstelle (version.rb:496).
  test "AC-4: ein lokal fehlender Record entsteht im neuen Zustand" do
    id = 3_700_003
    League.where(id: id).delete_all
    snapshot = {"id" => id, "name" => "Neu-Liga", "shortname" => "NL",
                "organizer_type" => "Region", "organizer_id" => regions(:nbv).id,
                "season_id" => seasons(:current).id, "source_kind" => nil,
                "created_at" => Time.current, "updated_at" => Time.current}

    apply_version(item_type: "League", item_id: id, object: snapshot,
      object_changes: {"source_kind" => [nil, "ba"]}, version_id: 999_003)

    created = League.find_by(id: id)
    assert_not_nil created, "der Record muss angelegt worden sein"
    assert_equal "ba", created.source_kind, "und zwar im Zustand NACH der Aenderung"
  end

  # AC-5 — Verhaltenserhalt. Muss von Anfang an gruen sein: das ist das Sicherheitsnetz.
  test "AC-5: ein gueltiger Record wird unveraendert appliziert" do
    league = League.new(id: 3_700_004, name: "Gueltige Liga", shortname: "GL",
      organizer_type: "Region", organizer_id: regions(:nbv).id, season: seasons(:current))
    league.unprotected = true
    league.save!
    assert league.valid?

    apply_version(item_type: "League", item_id: league.id,
      object: league.attributes.merge("source_kind" => nil),
      object_changes: {"source_kind" => [nil, "club_cloud"]}, version_id: 999_004)

    assert_equal "club_cloud", league.reload.source_kind
  end

  # AC-3 — die Ungueltigkeit darf nicht mehr unsichtbar sein. Das ist zugleich das Messinstrument
  # fuer die Bestandsaufnahme (Folgearbeit): "wie viel Altbestand steckt in diesem Zustand?"
  #
  # Geprueft wird die LOG-AUSGABE, nicht das Thread-Local: der Sammler wird am Durchlauf-Ende
  # zurueckgesetzt, und im Betrieb ist ohnehin das Log der Kanal, den jemand liest.
  test "AC-3: ein ungueltiger Record wird gemeldet, getrennt von uebersprungenen Versionen" do
    league = invalid_global_league(id: 3_700_005)

    logged = capture_sync_log do
      apply_version(item_type: "League", item_id: league.id,
        object: league.attributes.merge("source_kind" => nil),
        object_changes: {"source_kind" => [nil, "ba"]}, version_id: 999_005)
    end

    assert_equal "ba", league.reload.source_kind, "geschrieben wird trotzdem"

    assert_match(/ungültig/i, logged, "die Meldung nennt den Zustand")
    assert_match(/trotzdem geschrieben/i, logged, "und sagt, dass die Aenderung ankam")
    assert_match(/League/, logged, "Modell")
    assert_match(/#{league.id}/, logged, "id")
    assert_match(/999005/, logged, "Version-id")
    assert_match(/must be unique/i, logged, "der Validierungsfehler gehoert dazu")
    assert_no_match(/übersprungen/i, logged,
      "NICHT im Topf der uebersprungenen Versionen — die werden ja gerade nicht geschrieben")
  end
  # ===================================================================================
  # Plan 02.1-03: unbekannte Spalten im Snapshot
  #
  # Diese Tests entstanden als CHARAKTERISIERUNG der Ist-Lage (Apply scheitert, bekannte Werte
  # gehen mit verloren, Cursor laeuft hoch) und beschreiben nach dem Einbau des Filters das
  # gewuenschte Verhalten. Der Sync ist die Replikationsgrundlage aller Regional-Server —
  # deshalb zuerst der Beleg, dann der Eingriff.
  #
  # Warum das zaehlt: `has_paper_trail` ist NUR auf der Authority aktiv
  # (`unless carambus_api_url.present?`, local_protector.rb:31). Dort entstehen die Versionen,
  # lokale Server konsumieren sie — jeder Snapshot traegt daher ALLE Spalten der Authority.
  # Faellt lokal eine Spalte weg (oder hinkt ein Server bei den Migrationen hinterher), traegt
  # der Snapshot einen Schluessel, den die lokale Tabelle nicht kennt.
  #
  # ⚠️ Bewusst ein erfundener Spaltenname, NICHT `pin4`: geprueft wird der Mechanismus, nicht
  # dieser eine Fall. Und bewusst `League` statt `Player` — weniger Fixture-Abhaengigkeit,
  # gleiche Harness wie AC-1..AC-5.
  # ===================================================================================

  UNBEKANNTE_SPALTE = "zzz_gibt_es_lokal_nicht"

  test "Update: eine unbekannte Spalte wird verworfen, die bekannten Werte kommen an" do
    league = League.new(id: 3_700_010, name: "Filter-Liga U", shortname: "FU",
      organizer_type: "Region", organizer_id: regions(:nbv).id, season: seasons(:current))
    league.unprotected = true
    league.save!

    log = capture_sync_log do
      apply_version(item_type: "League", item_id: league.id,
        object: league.attributes.merge("source_kind" => nil),
        object_changes: {"source_kind" => [nil, "ba"], UNBEKANNTE_SPALTE => [nil, "x"]},
        version_id: 999_010)
    end

    refute_match(/APPLY FAILED/, log, "der Apply darf an der fremden Spalte nicht mehr scheitern")
    assert_match(/unbekannte Spalten verworfen.*#{UNBEKANNTE_SPALTE}/o, log,
      "das Verworfene MUSS nachvollziehbar sein — es ist die einzige Spur")
    assert_equal "ba", league.reload.source_kind,
      "der bekannte Wert kommt an, als waere die fremde Spalte nie dagewesen"
  end

  test "Create: eine unbekannte Spalte verhindert das Anlegen nicht mehr" do
    id = 3_700_011
    League.where(id: id).delete_all
    snapshot = {"id" => id, "name" => "Filter-Liga C", "shortname" => "FC",
                "organizer_type" => "Region", "organizer_id" => regions(:nbv).id,
                "season_id" => seasons(:current).id, "source_kind" => nil,
                UNBEKANNTE_SPALTE => "x",
                "created_at" => Time.current, "updated_at" => Time.current}

    log = capture_sync_log do
      apply_version(item_type: "League", item_id: id, object: snapshot,
        object_changes: {"source_kind" => [nil, "ba"]}, version_id: 999_011)
    end

    refute_match(/APPLY FAILED/, log)
    created = League.find_by(id: id)
    assert_not_nil created, "der Record muss trotz der fremden Spalte entstehen"
    assert_equal "ba", created.source_kind, "und zwar im Zustand NACH der Aenderung"
    assert_match(/unbekannte Spalten verworfen/, log)
  end

  # ⚠️ Der Cursor lief schon vor dem Filter hoch — DAS ist der Grund, warum ein Fehlschlag hier
  # endgueltiger Verlust ist und nicht bloss ein Wiederholungsfall. Der Test haelt fest, dass
  # der Filter daran nichts aendert: er verhindert den Fehlschlag, statt ihn zu wiederholen.
  test "der Cursor laeuft weiter — der Filter aendert daran bewusst nichts" do
    league = League.new(id: 3_700_012, name: "Filter-Liga X", shortname: "FX",
      organizer_type: "Region", organizer_id: regions(:nbv).id, season: seasons(:current))
    league.unprotected = true
    league.save!

    capture_sync_log do
      apply_version(item_type: "League", item_id: league.id,
        object: league.attributes.merge(UNBEKANNTE_SPALTE => "x"),
        object_changes: {"source_kind" => [nil, "ba"]}, version_id: 999_012)
    end

    assert_equal 999_012, Setting.key_get_value("last_version_id").to_i,
      "der Cursor steht hinter der gescheiterten Version — sie wird nie wieder geliefert " \
      "(version.rb:549). Der Verlust ist laut, aber endgueltig."
  end

  # ===================================================================================
  # Plan 02.1-03, Task 3: `players.pin4` ausser Betrieb
  # ===================================================================================

  test "pin4 ist fuer ActiveRecord unsichtbar, die Spalte steht aber noch in der Datenbank" do
    refute Player.new.respond_to?(:pin4), "ignored_columns muss das Attribut ausblenden"
    refute_includes Player.column_names, "pin4", "auch aus column_names — so wirkt ignored_columns"

    # ⚠️ Die DATENBANKSPALTE bleibt: `remove_column` ist Plan 02.1-04, erst nach dem Deploy.
    db_spalten = ActiveRecord::Base.connection.columns("players").map(&:name)
    assert_includes db_spalten, "pin4", "die Spalte darf in diesem Plan NICHT entfernt sein"
  end

  test "region_ids bleibt weiter ignoriert — die Liste wurde erweitert, nicht ersetzt" do
    assert_includes Player.ignored_columns, "region_ids"
    assert_includes Player.ignored_columns, "pin4"
  end

  test "ein Player laesst sich ohne die pin4-Validierung speichern" do
    p = Player.new(firstname: "Test", lastname: "Filter",
      club_id: clubs(:bcw).id, type: "Player")
    p.unprotected = true
    assert p.save, "Speichern darf nicht an einer Validierung fuer ein ignoriertes Attribut scheitern: " \
      "#{p.errors.full_messages.join("; ")}"
  end

  # ⚠️ Der eigentliche Zweck der Kombination: ein Authority-Snapshot mit `pin4` darf den
  # Player-Sync nicht mehr zerlegen — und zwar SCHON JETZT, vor dem remove_column.
  test "ein Authority-Snapshot mit pin4 verliert nur pin4, nicht die uebrigen Werte" do
    args = {"firstname" => "Max", "lastname" => "Muster", "pin4" => "1234"}

    log = capture_sync_log { Version.reject_unknown_columns!(Player, args, 42) }

    assert_equal({"firstname" => "Max", "lastname" => "Muster"}, args)
    assert_match(/unbekannte Spalten verworfen.*pin4/, log)
  end
end
