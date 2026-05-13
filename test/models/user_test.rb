# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  accepted_privacy_at    :datetime
#  accepted_terms_at      :datetime
#  admin                  :boolean
#  announcements_read_at  :datetime
#  code                   :string
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :inet
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  first_name             :string
#  firstname              :string
#  invitation_accepted_at :datetime
#  invitation_created_at  :datetime
#  invitation_limit       :integer
#  invitation_sent_at     :datetime
#  invitation_token       :string
#  invitations_count      :integer          default(0)
#  invited_by_type        :string
#  last_name              :string
#  last_otp_timestep      :integer
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :inet
#  lastname               :string
#  otp_backup_codes       :text
#  otp_required_for_login :boolean
#  otp_secret             :string
#  preferred_language     :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  sign_in_count          :integer
#  time_zone              :string
#  unconfirmed_email      :string
#  username               :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  invited_by_id          :bigint
#  player_id              :integer
#
# Indexes
#
#  index_users_on_confirmation_token                 (confirmation_token) UNIQUE
#  index_users_on_email                              (email) UNIQUE
#  index_users_on_invitation_token                   (invitation_token) UNIQUE
#  index_users_on_invitations_count                  (invitations_count)
#  index_users_on_invited_by_id                      (invited_by_id)
#  index_users_on_invited_by_type_and_invited_by_id  (invited_by_type,invited_by_id)
#  index_users_on_reset_password_token               (reset_password_token) UNIQUE
#  index_users_on_username                           (username) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (player_id => players.id)
#

require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "default role is player" do
    user = User.new(email: "test_drip@example.com", password: "password", first_name: "default", last_name: "user")
    user.save!
    assert user.player?
  end

  setup do
    @user = users(:regular)
    @user.preferences = {"theme" => "system", "locale" => "de", "timezone" => "Berlin"}
  end

  test "valid preferences" do
    assert @user.valid?
  end

  test "invalid theme" do
    @user.preferences["theme"] = "invalid"
    assert_not @user.valid?
    assert_includes @user.errors[:preferences], I18n.t("errors.messages.invalid_theme")
  end

  test "invalid locale" do
    @user.preferences["locale"] = "xx"
    assert_not @user.valid?
    assert_includes @user.errors[:preferences], I18n.t("errors.messages.invalid_locale")
  end

  test "invalid timezone" do
    @user.preferences["timezone"] = "Invalid/Timezone"
    assert_not @user.valid?
    assert_includes @user.errors[:preferences], I18n.t("errors.messages.invalid_timezone")
  end

  test "should accept valid themes" do
    %w[system dark light].each do |theme|
      @user.preferences["theme"] = theme
      assert @user.valid?, "#{theme} should be valid"
    end
  end

  test "should set default preferences on initialization" do
    user = User.new(
      email: "new@example.com",
      password: "password",
      first_name: "New",
      last_name: "User"
    )

    assert_equal "system", user.preferences["theme"]
    assert_equal "de", user.preferences["locale"]
    assert_equal "Berlin", user.preferences["timezone"]
  end

  # MCP Multi-User-Hosting (v0.3, Plan 13-02, D-13-01-D Option-B-Override)
  # ---------------------------------------------------------------------
  test "mcp_role defaults to mcp_public_read for new User" do
    u = User.new(email: "mcp1@example.com", password: "password123")
    assert_equal "mcp_public_read", u.mcp_role
    assert u.mcp_role_mcp_public_read?
  end

  test "mcp_enabled? returns false when no cc_credentials present" do
    u = User.new(email: "mcp2@example.com", password: "password123", mcp_role: :mcp_sportwart)
    assert_not u.mcp_enabled?
  end

  test "mcp_enabled? returns true when role > public_read AND cc_credentials present" do
    u = User.new(email: "mcp3@example.com", password: "password123",
      mcp_role: :mcp_sportwart, cc_credentials: '{"username":"x"}')
    assert u.mcp_enabled?
  end

  test "mcp_cc_region falls back to ENV CC_REGION when User.cc_region nil" do
    u = User.new(email: "mcp4@example.com", password: "password123")
    ENV["CC_REGION"] = "test_env_region"
    assert_equal "test_env_region", u.mcp_cc_region
  ensure
    ENV.delete("CC_REGION")
  end

  test "existing Carambus role enum unangetastet (admin? Methoden funktional)" do
    u = User.new(email: "mcp5@example.com", password: "password123", role: :system_admin)
    assert u.admin?
    assert u.super_admin?
    # Sanity: Carambus-role und mcp_role sind unabhängig
    assert_equal "system_admin", u.role
    assert_equal "mcp_public_read", u.mcp_role
  end

  # v0.3 Plan 13-07 (D-13-01-E DSGVO minimal-pragmatic): Consent + AuditTrail-Export
  # ----------------------------------------------------------------------------------
  test "mcp_consent_given? false bei neuem User" do
    u = User.new(email: "consent1@test.de", password: "password123")
    assert_not u.mcp_consent_given?
  end

  test "mcp_consent_required? true bei mcp_role > public_read OHNE mcp_consent_at" do
    u = User.create!(email: "consent2@test.de", password: "password123",
      mcp_role: :mcp_sportwart)
    assert u.mcp_consent_required?, "Sportwart ohne consent_at muss required? true sein"
  end

  test "mcp_consent_required? false bei mcp_public_read (kein MCP-Zugriff = keine Einwilligung n\u00F6tig)" do
    u = User.create!(email: "consent3@test.de", password: "password123",
      mcp_role: :mcp_public_read)
    assert_not u.mcp_consent_required?
  end

  test "grant_mcp_consent! setzt mcp_consent_at + persistiert" do
    u = User.create!(email: "consent4@test.de", password: "password123",
      mcp_role: :mcp_sportwart)
    assert_nil u.mcp_consent_at
    u.grant_mcp_consent!
    u.reload
    refute_nil u.mcp_consent_at
    assert u.mcp_consent_given?
    assert_not u.mcp_consent_required?
  end

  test "mcp_audit_trail_export: 0 Entries \u2192 empty Array" do
    u = User.create!(email: "export1@test.de", password: "password123",
      mcp_role: :mcp_sportwart)
    assert_equal [], u.mcp_audit_trail_export
  end

  test "mcp_audit_trail_export: liefert DSGVO-relevante Felder pro Entry" do
    u = User.create!(email: "export2@test.de", password: "password123",
      mcp_role: :mcp_sportwart)
    McpAuditTrail.create!(
      user: u,
      tool_name: "cc_register_for_tournament",
      operator: "carambus_admin",
      payload: {meldeliste_cc_id: 1310, armed: true},
      pre_validation_results: [{name: "check1", ok: true}],
      read_back_status: "match",
      result: "success"
    )
    export = u.mcp_audit_trail_export
    assert_equal 1, export.length
    entry = export.first
    assert_kind_of String, entry[:zeitpunkt]
    assert_equal "cc_register_for_tournament", entry[:tool_name]
    assert_equal "carambus_admin", entry[:operator]
    assert_equal({"meldeliste_cc_id" => 1310, "armed" => true}, entry[:payload])
    assert_equal "success", entry[:result]
    assert_nothing_raised { export.to_json }
  end

  # v0.3 Plan 13-06.2 (D-13-06.1-C): Devise-JWT-Auth + JTIMatcher-Revocation
  test "User#jti column existiert + ist string-typed" do
    assert_equal :string, User.columns_hash["jti"].type
    u = User.new(email: "test-jwt-column@example.com", password: "password123")
    assert u.respond_to?(:jti), "User muss jti-Accessor haben"
  end

  test "Devise.jwt_revocation_strategy ist auf User-Model gesetzt (JTIMatcher)" do
    # JTIMatcher fügt Klassen-Methoden für JWT-Revocation hinzu
    assert User.respond_to?(:jwt_revoked?), "JTIMatcher muss jwt_revoked? auf User definieren"
    assert User.respond_to?(:revoke_jwt), "JTIMatcher muss revoke_jwt auf User definieren"
  end

  test "User generates jwt token via Warden::JWTAuth::UserEncoder" do
    u = User.first
    skip "no users in fixtures" unless u
    token, payload = Warden::JWTAuth::UserEncoder.new.call(u, :user, nil)
    assert_kind_of String, token, "token must be JWT string"
    assert payload["jti"].present?, "JWT muss jti-Claim enthalten"
    assert_equal u.id, payload["sub"].to_i, "JWT sub-Claim muss user_id sein"
    assert payload["exp"] > Time.current.to_i, "exp muss zukünftig sein (24h Default)"
  end
end
