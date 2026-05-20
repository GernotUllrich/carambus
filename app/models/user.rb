# frozen_string_literal: true

# source: app/models/user.rb
class User < ApplicationRecord
  include Theme
  include SportwartScope

  enum :role, {
    player: 0,
    club_admin: 1,
    system_admin: 2
  }, default: :player

  # D-14-G5: Sportwart-Wirkbereich via M:N-Join-Tables.
  has_many :sportwart_location_assignments, class_name: "SportwartLocation", dependent: :destroy
  has_many :sportwart_locations, through: :sportwart_location_assignments, source: :location
  has_many :sportwart_discipline_assignments, class_name: "SportwartDiscipline", dependent: :destroy
  has_many :sportwart_disciplines, through: :sportwart_discipline_assignments, source: :discipline

  PRIVILEGED = %w[gernot.ullrich@gmx.de nla@ph.at wcauel@gmail.com joerg.unger@hamburg.de].freeze

  attr_accessor :player_ba_id, :terms_of_service

  before_save :set_paper_trail_whodunnit
  before_validation :set_default_role, on: :create

  # Plan 13-06.2 / D-13-06.1-C: JWT-Token-Auth via devise-jwt + JTIMatcher-Revocation.
  # Backwards-Compat: Cookie-Auth (database_authenticatable + Session) bleibt parallel aktiv.
  # MCP-Clients können entweder Cookie-Session ODER `Authorization: Bearer <jwt>` senden;
  # Devise's `authenticate_user!` checkt beide Strategien transparent.
  devise :database_authenticatable, :registerable,
    :recoverable, :rememberable, :validatable, :confirmable,
    :jwt_authenticatable, jwt_revocation_strategy: self

  include Devise::JWT::RevocationStrategies::JTIMatcher

  validates :terms_of_service, acceptance: true, on: :create

  # Add validation for preferences
  validate :valid_preferences

  # D-41-C (Plan 41-03): Hard-Revoke aller JWT bei Passwort-Aenderung (Forgot-Reset
  # + Change-Password + Admin-Update + Console-Update — alle Pfade gehen durch
  # encrypted_password-Save). Routine-Updates (Email, Preferences, Confirmation)
  # triggern den Callback NICHT, daher bleibt der JTI fuer normale Sessions stabil.
  # carambus_bcw-MCP-JWTs sind nur betroffen, wenn der User sein Passwort tatsaechlich
  # aendert — gewolltes Security-Verhalten (kompromittierter Account: bewusster
  # PW-Reset revoked alles).
  after_update :rotate_jti_on_password_change!, if: :saved_change_to_encrypted_password?

  THEMES = %w[system dark light].freeze
  LOCALES = I18n.available_locales.map(&:to_s).freeze

  thread_cattr_accessor :current

  after_initialize :set_default_preferences

  def self.scoreboard
    unless Rails.env == "test"
      User.find_by_email("scoreboard@carambus.de")
    end
  end

  def skip_confirmation!
  end

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

  # D-14-G6: mcp_enabled? / mcp_cc_region / mcp_consent_required? entfernt (mcp_role + cc_credentials + cc_region gedroppt).
  # Authority via Sportwart-Wirkbereich (SportwartScope-Concern) + Tournament.turnier_leiter_user_id in 14-G.2.

  # True wenn User-Einwilligung gespeichert ist (mcp_consent_at-Spalte bleibt erhalten)
  def mcp_consent_given?
    mcp_consent_at.present?
  end

  # Setzt mcp_consent_at = Time.current und persistiert
  def grant_mcp_consent!
    update!(mcp_consent_at: Time.current)
  end

  # v0.3 Plan 13-07 (D-13-01-E DSGVO Auskunfts-Recht Art. 15):
  # Liefert User's McpAuditTrail-Entries als Array von DSGVO-relevanten Hashes.
  # Use-Case: Carambus-Admin gibt User-Auskunft auf Anfrage
  # (`User.find(id).mcp_audit_trail_export.to_json` → an User-Email senden).
  # cc_credentials sind NICHT enthalten (encrypted at rest; Sicherheitsbalance).
  def mcp_audit_trail_export(limit: 1000)
    McpAuditTrail.for_user(self).recent(limit).map do |entry|
      {
        zeitpunkt: entry.created_at.utc.iso8601,
        tool_name: entry.tool_name,
        operator: entry.operator,
        payload: entry.payload,
        result: entry.result,
        pre_validation_results: entry.pre_validation_results,
        read_back_status: entry.read_back_status
      }
    end
  end

  # Plan 41-04 Task 2 (D-41-B): Devise-Mails laufen async ueber DeviseMailJob (Retry+
  # Bounce-Handling). Ueberschreibt Devise's Default-`send_devise_notification`
  # (deliver_now synchron). Mailer-Klasse + Notification-Method + Record-Identitaet
  # werden an Job uebergeben; Job-perform laedt Record per ID neu und liefert
  # deliver_now (in der Job-Worker-Sandbox, mit retry_on/discard_on um SMTP-Errors).
  #
  # Sichtbarkeit: public (Devise's send_devise_notification ist im Default public,
  # wird aus authenticatable.rb#send_devise_notification per .send aufgerufen).
  def send_devise_notification(notification, *args)
    devise_mailer_class = devise_mailer.name
    DeviseMailJob.perform_later(devise_mailer_class, notification.to_s, self.class.name, id, *args)
  end

  private

  # D-41-C (Plan 41-03): JWT-Hard-Revoke bei Passwort-Aenderung.
  # JTIMatcher.revoke_jwt rotiert die jti-Spalte (update_column → bypassed
  # Callbacks/Validations). Damit werden alle vorher ausgestellten JWTs
  # ungueltig (jwt_revoked? prueft payload['jti'] != user.jti).
  def rotate_jti_on_password_change!
    self.class.revoke_jwt(nil, self)
  end

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
      "theme" => (email == "scoreboard@carambus.de") ? "dark" : "system",
      "locale" => I18n.default_locale.to_s,
      "timezone" => "Berlin"
    }
  end
end
