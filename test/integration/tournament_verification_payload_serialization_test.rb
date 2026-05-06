# frozen_string_literal: true

require "test_helper"

# Regression guard for quick-260506-k3t Bug 1: the PRG flash payload returned by
# TournamentsController#build_verification_failure_payload (line 1028) is round-tripped
# through the cookie session, which uses the :json serializer in Rails 7.2 by default
# (test.rb / staging.rb / production-*.rb — only development.rb sets redis_session_store).
# If the helper returns symbol keys, JSON serialization stringifies them and view-side
# access via @verification_failure[:body_text] returns nil → empty modal body in production.
#
# This test pins the wire-format contract: build_verification_failure_payload MUST return
# a Hash whose body_text and failures keys survive a JSON round-trip with string-key access.
class TournamentVerificationPayloadSerializationTest < ActionDispatch::IntegrationTest
  test "build_verification_failure_payload returns a hash whose keys survive a JSON round-trip" do
    controller = TournamentsController.new
    fake_failures = [
      { label: "Bälle-Ziel", value: 99999, range: 10..80 },
      { label: "Innings", value: 0, range: 1..100 }
    ]
    payload = controller.send(:build_verification_failure_payload, fake_failures)

    # Simulate the cookie-session JSON serializer round-trip exactly.
    round_tripped = JSON.parse(JSON.dump(payload))

    assert_kind_of String, round_tripped["body_text"], "body_text must be readable via string key after JSON round-trip"
    assert_predicate round_tripped["body_text"], :present?, "body_text must not be empty after JSON round-trip"
    assert_kind_of Array, round_tripped["failures"], "failures must be readable via string key after JSON round-trip"
    assert_equal 2, round_tripped["failures"].length, "failures must round-trip with the same element count"
  end

  test "build_verification_failure_payload body_text includes the discipline range hint" do
    controller = TournamentsController.new
    fake_failures = [{ label: "Bälle-Ziel", value: 99999, range: 10..80 }]
    payload = controller.send(:build_verification_failure_payload, fake_failures)
    round_tripped = JSON.parse(JSON.dump(payload))

    # The hint format ("üblich: 10-80") is what the operator sees in the modal — proves
    # we exercised the body_intro + body_lines path, not just the empty hash shape.
    assert_match(/üblich:\s*10-80/, round_tripped["body_text"])
  end
end
