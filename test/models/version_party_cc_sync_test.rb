# frozen_string_literal: true

require "test_helper"

# Plan 19-02: Der Sync wertete `data` von PartyCc-Versionen mit `eval` aus (version.rb, create- und
# update-Zweig). In allen 5.208 party_ccs steht nur Ruby-Inspect wie '{:result=>"0:0"}'.
# Belegt am alten Code: create kam an (Zuweisung wandelt den Hash per to_s zurueck), jedes update
# scheiterte dagegen mit "TypeError: can't cast Hash" (update_columns) — APPLY FAILED, Cursor lief
# weiter, die Aenderung war verloren. Und Code in `data` wurde ausgefuehrt.
# Seit 19-02 laeuft PartyCc durch den allgemeinen data-Zweig: der String kommt unveraendert an.
class VersionPartyCcSyncTest < ActiveSupport::TestCase
  LEAGUE_CC_ID = 50_000_901
  PARTY_CC_ID = 50_000_902
  NEW_PARTY_CC_ID = 50_000_903
  CODE_PROBE = "Thread.current[:carambus_sync_probe] = 42; {}"

  setup do
    skip_unless_local_server
    Thread.current[:carambus_sync_probe] = nil
    Thread.current[:carambus_sync_apply_failures] = nil
    @party = parties(:party_one)
    # PartyCc verlangt league_cc und party (belongs_to). Die CC-Kette dahinter ist fuer den Sync
    # unerheblich — der LeagueCc wird deshalb ohne Validierung angelegt.
    league_cc = LeagueCc.new(id: LEAGUE_CC_ID, name: "Sync-Test-Liga", league_id: @party.league_id)
    league_cc.unprotected = true
    league_cc.save!(validate: false)
  end

  teardown do
    Thread.current[:carambus_sync_probe] = nil
    Thread.current[:carambus_sync_apply_failures] = nil
    PartyCc.where(id: [PARTY_CC_ID, NEW_PARTY_CC_ID]).delete_all
    LeagueCc.where(id: LEAGUE_CC_ID).delete_all
  end

  def existing_party_cc!(data)
    pcc = PartyCc.new(id: PARTY_CC_ID, league_cc_id: LEAGUE_CC_ID, party_id: @party.id, data: data)
    pcc.unprotected = true
    pcc.save!(validate: false)
    pcc
  end

  def run_sync(payload)
    api_url = Carambus.config.carambus_api_url
    stub_request(:get, /#{Regexp.escape(api_url)}\/versions\/get_updates/)
      .to_return(status: 200, body: payload.to_json, headers: {"Content-Type" => "application/json"})
    Version.update_from_carambus_api({})
  end

  def update_version(id, old_data, new_data)
    attrs = {"id" => PARTY_CC_ID, "league_cc_id" => LEAGUE_CC_ID, "party_id" => @party.id, "data" => old_data}
    {"id" => id, "item_type" => "PartyCc", "item_id" => PARTY_CC_ID, "event" => "update",
     "object" => YAML.dump(attrs), "object_changes" => YAML.dump({"data" => [old_data, new_data]}),
     "created_at" => Time.current.to_s}
  end

  def create_version(id, data)
    changes = {"id" => [nil, NEW_PARTY_CC_ID], "league_cc_id" => [nil, LEAGUE_CC_ID],
               "party_id" => [nil, @party.id], "data" => [nil, data]}
    {"id" => id, "item_type" => "PartyCc", "item_id" => NEW_PARTY_CC_ID, "event" => "create",
     "object" => nil, "object_changes" => YAML.dump(changes), "created_at" => Time.current.to_s}
  end

  test "update: data in Ruby-Inspect-Form kommt als derselbe String an" do
    pcc = existing_party_cc!('{:result=>"0:0"}')
    run_sync([update_version(990_001, '{:result=>"0:0"}', '{:result=>"3:1"}')])

    assert_equal '{:result=>"3:1"}', pcc.reload.data
  end

  test "update: auch mit mehreren Schluesseln und nil bleibt der String gleich" do
    pcc = existing_party_cc!('{:result=>"0:0"}')
    run_sync([update_version(990_002, '{:result=>"0:0"}', '{:result=>"2:2", :note=>nil}')])

    assert_equal '{:result=>"2:2", :note=>nil}', pcc.reload.data
  end

  test "create: angelegter PartyCc traegt data als denselben String" do
    run_sync([create_version(990_003, '{:result=>"1:3"}')])

    created = PartyCc.find_by(id: NEW_PARTY_CC_ID)
    assert created, "PartyCc wurde nicht angelegt"
    assert_equal '{:result=>"1:3"}', created.data
  end

  test "update: Ruby-Code in data wird nicht ausgefuehrt" do
    existing_party_cc!('{:result=>"0:0"}')
    run_sync([update_version(990_004, '{:result=>"0:0"}', CODE_PROBE)])

    assert_nil Thread.current[:carambus_sync_probe], "Sync-Daten wurden als Ruby-Code ausgefuehrt"
  end

  test "create: Ruby-Code in data wird nicht ausgefuehrt" do
    run_sync([create_version(990_005, CODE_PROBE)])

    assert_nil Thread.current[:carambus_sync_probe], "Sync-Daten wurden als Ruby-Code ausgefuehrt"
  end

  # Die Apply-Fehlerliste wird am Laufende geloggt und geleert — geprueft wird deshalb das Log
  # und die Wirkung, nicht die Thread-Variable.
  test "Cursor laeuft weiter, beide Versionen kommen an, kein APPLY FAILED" do
    pcc = existing_party_cc!('{:result=>"0:0"}')
    log = StringIO.new
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(log)
    begin
      run_sync([update_version(990_006, '{:result=>"0:0"}', '{:result=>"4:0"}'),
        create_version(990_007, '{:result=>"0:4"}')])
    ensure
      Rails.logger = original_logger
    end

    assert_equal 990_007, Setting.key_get_value("last_version_id").to_i
    assert_equal '{:result=>"4:0"}', pcc.reload.data
    assert_equal '{:result=>"0:4"}', PartyCc.find_by(id: NEW_PARTY_CC_ID)&.data
    refute_match(/APPLY FAILED/, log.string)
  end
end
