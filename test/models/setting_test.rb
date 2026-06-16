# frozen_string_literal: true

require "test_helper"

# Plan 39-02 Task 1 (D-39-2): reine Credential-Auswahl-Naht `resolve_login_credentials`.
# Testet NUR die Credential-Quelle (testbar ohne Net::HTTP) — der MD5/checkUser.php-Login-Flow
# in login_to_cc bleibt unberuehrt und wird hier nicht angefasst.
class SettingTest < ActiveSupport::TestCase
  SENTINEL = {username: "region-admin", password: "region-pw"}.freeze

  test "resolve_login_credentials nutzt explizite Override-Creds 1:1 ohne get_cc_credentials zu befragen" do
    Setting.stub(:get_cc_credentials, ->(_ctx) { flunk("get_cc_credentials darf bei vollstaendigem Override NICHT aufgerufen werden") }) do
      result = Setting.resolve_login_credentials("nbv", username: "user@example.com", password: "secret")
      assert_equal({username: "user@example.com", password: "secret"}, result)
    end
  end

  test "resolve_login_credentials faellt ohne Override auf get_cc_credentials zurueck (Region-Admin)" do
    Setting.stub(:get_cc_credentials, ->(ctx) { SENTINEL.merge(context: ctx) }) do
      result = Setting.resolve_login_credentials("nbv")
      assert_equal SENTINEL.merge(context: "nbv"), result
    end
  end

  test "resolve_login_credentials faellt bei nur teilweisem Override (nur username) auf get_cc_credentials zurueck" do
    Setting.stub(:get_cc_credentials, ->(_ctx) { SENTINEL }) do
      result = Setting.resolve_login_credentials("nbv", username: "user@example.com", password: nil)
      assert_equal SENTINEL, result
    end
  end
end
