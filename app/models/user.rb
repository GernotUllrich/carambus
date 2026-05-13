# frozen_string_literal: true

# source: app/models/user.rb
class User < ApplicationRecord
  include Theme

  enum :role, {
    player: 0,
    club_admin: 1,
    system_admin: 2
  }, default: :player

  # MCP Multi-User-Hosting (v0.3, Plan 13-02, D-13-01-D Option-B-Override).
  # Separates Feld neben existierendem Carambus-`role`-Enum — keine Vermischung der Auth-Layer.
  # Siehe lib/mcp_server/role_tool_map.rb für Tool-Subset pro Rolle.
  enum :mcp_role, {
    mcp_public_read: 0,
    mcp_sportwart: 1,
    mcp_turnierleiter: 2,
    mcp_landessportwart: 3,
    mcp_admin: 4
  }, default: :mcp_public_read, prefix: true

  # CC-Credentials verschlüsselt at rest (D-13-01-E DSGVO minimal-pragmatic Pflicht).
  # Erwartetes Format: JSON-String mit { username:, password: } o.ä.; nil = MCP nicht eingerichtet.
  encrypts :cc_credentials

  PRIVILEGED = %w[gernot.ullrich@gmx.de nla@ph.at wcauel@gmail.com joerg.unger@hamburg.de].freeze

  attr_accessor :player_ba_id, :terms_of_service

  before_save :set_paper_trail_whodunnit
  before_validation :set_default_role, on: :create

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable

  validates :terms_of_service, acceptance: true, on: :create

  # Add validation for preferences
  validate :valid_preferences

  THEMES = %w[system dark light].freeze
  LOCALES = I18n.available_locales.map(&:to_s).freeze

  thread_cattr_accessor :current

  after_initialize :set_default_preferences

  def self.scoreboard
    unless Rails.env == "test"
      User.find_by_email("scoreboard@carambus.de")
    end
  end

  def skip_confirmation!; end

  def admin?
    club_admin? || system_admin?
  end

  def super_admin?
    system_admin?
  end

  def display_name
    username.presence || (last_name.present? ? "#{last_name}, #{first_name}" : nil) || email
  end

  def privileged_access?
    system_admin? || PRIVILEGED.include?(email)
  end

  def preferred_language
    preferences["locale"]
  end

  def role_changed?
    role_changed = previous_changes["role"]
    role_changed && role_changed.first != role_changed.last
  end

  def prefers_dark_mode?
    preferences["theme"] == "dark" || false
  end

  def toggle_dark_mode!
    new_mode = !prefers_dark_mode?
    update(preferences: preferences.merge(dark: new_mode))
  end

  # MCP Multi-User-Hosting (v0.3, Plan 13-02).
  # True wenn User MCP nutzen kann (Rolle > public_read UND CC-Credentials vorhanden).
  def mcp_enabled?
    !mcp_role_mcp_public_read? && cc_credentials.present?
  end

  # MCP Region-Fallback-Chain (Per-User → ENV → nil).
  # D-13-01-F Backwards-Compat-Pattern: server_context[:cc_region] > ENV["CC_REGION"].
  def mcp_cc_region
    cc_region.presence || ENV["CC_REGION"]
  end

  private

  def set_default_role
    self.role ||= :player
  end

  def set_paper_trail_whodunnit
    PaperTrail.request.whodunnit = if persisted? && User.current.present?
                                     "#{User.current.id}@#{ENV["DEFAULT_CLUB_ID"]}"
                                   else
                                     "system@#{ENV["DEFAULT_CLUB_ID"]}"
                                   end
  end

  def valid_preferences
    if preferences["theme"].present?
      errors.add(:preferences, :invalid_theme) unless THEMES.include?(preferences["theme"])
    end

    if preferences["locale"].present?
      errors.add(:preferences, :invalid_locale) unless LOCALES.include?(preferences["locale"])
    end

    if preferences["timezone"].present?
      errors.add(:preferences, :invalid_timezone) unless ActiveSupport::TimeZone[preferences["timezone"]]
    end
  end

  def set_default_preferences
    self.preferences ||= {
      "theme" => email == "scoreboard@carambus.de" ? "dark" : "system",
      "locale" => I18n.default_locale.to_s,
      "timezone" => "Berlin"
    }
  end
end
