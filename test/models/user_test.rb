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
    @user.preferences = { 'theme' => 'system', 'locale' => 'de', 'timezone' => 'Berlin' }
  end

  test 'valid preferences' do
    assert @user.valid?
  end

  test 'invalid theme' do
    @user.preferences['theme'] = 'invalid'
    assert_not @user.valid?
    assert_includes @user.errors[:preferences], I18n.t('errors.messages.invalid_theme')
  end

  test 'invalid locale' do
    @user.preferences['locale'] = 'xx'
    assert_not @user.valid?
    assert_includes @user.errors[:preferences], I18n.t('errors.messages.invalid_locale')
  end

  test 'invalid timezone' do
    @user.preferences['timezone'] = 'Invalid/Timezone'
    assert_not @user.valid?
    assert_includes @user.errors[:preferences], I18n.t('errors.messages.invalid_timezone')
  end

  test 'should accept valid themes' do
    %w[system dark light].each do |theme|
      @user.preferences['theme'] = theme
      assert @user.valid?, "#{theme} should be valid"
    end
  end

  test 'should set default preferences on initialization' do
    user = User.new(
      email: 'new@example.com',
      password: 'password',
      first_name: 'New',
      last_name: 'User'
    )

    assert_equal 'system', user.preferences['theme']
    assert_equal 'de', user.preferences['locale']
    assert_equal 'Berlin', user.preferences['timezone']
  end
end
