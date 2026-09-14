# frozen_string_literal: true

require "test_helper"

# Konten eines aus dem Regionsdump befuellten Servers (Plan 18-03).
class LocalAccountsTest < ActiveSupport::TestCase
  setup do
    User.where(email: LocalAccounts::SCOREBOARD_EMAIL).delete_all
    ActionMailer::Base.deliveries.clear
  end

  test "Scoreboard-Konto wird angelegt, bestaetigt, als player — ohne Mail" do
    user, created = LocalAccounts.ensure_scoreboard!
    assert created
    assert user.persisted?
    assert user.confirmed?
    assert user.player?
    # User.scoreboard sucht dieselbe Adresse (liefert in der Test-Umgebung bewusst nil)
    assert_equal "scoreboard@carambus.de", user.email
    assert_empty ActionMailer::Base.deliveries
  end

  test "ein vorhandenes Scoreboard-Konto bleibt unveraendert" do
    first, = LocalAccounts.ensure_scoreboard!
    digest = first.reload.encrypted_password
    second, created = LocalAccounts.ensure_scoreboard!
    refute created
    assert_equal first.id, second.id
    assert_equal digest, second.reload.encrypted_password
    assert_equal 1, User.where(email: LocalAccounts::SCOREBOARD_EMAIL).count
  end

  test "erster Admin: system_admin, bestaetigt, Passwort gueltig, keine Mail" do
    user, password = LocalAccounts.create_admin!("  Erster.Admin@Verein.test ")
    assert_equal "erster.admin@verein.test", user.email
    assert user.system_admin?
    assert user.confirmed?
    assert user.valid_password?(password)
    assert_operator password.length, :>=, 20
    assert_empty ActionMailer::Base.deliveries
  end

  test "vorhandene E-Mail: Abbruch, Konto unveraendert" do
    existing = User.first || flunk("Fixture-User fehlt")
    before = existing.attributes.slice("role", "encrypted_password")
    assert_raises(ArgumentError) { LocalAccounts.create_admin!(existing.email.upcase) }
    assert_equal before, existing.reload.attributes.slice("role", "encrypted_password")
  end

  test "ungueltige Adresse: Abbruch ohne Datensatz" do
    assert_no_difference -> { User.count } do
      assert_raises(ArgumentError) { LocalAccounts.create_admin!("kein-at-zeichen") }
      assert_raises(ArgumentError) { LocalAccounts.create_admin!("") }
    end
  end
end
