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
end
