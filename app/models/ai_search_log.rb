# frozen_string_literal: true

# Log entry for AI search queries
# Tracks user queries, AI responses, and performance metrics
class AiSearchLog < ApplicationRecord
  belongs_to :user, optional: true

  # Validations
  # Note: We allow blank queries to log validation errors
  validates :locale, inclusion: { in: %w[de en], allow_blank: true }

  # Scopes
  scope :successful, -> { where(success: true) }
  scope :failed, -> { where(success: false) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }
  scope :by_entity, ->(entity) { where(entity: entity) }
  scope :high_confidence, -> { where('confidence >= ?', 80) }
  scope :low_confidence, -> { where('confidence < ?', 70) }

  # Class method to create from service response
  def self.create_from_response(query:, response:, user: nil, locale: 'de', raw_response: nil)
    create(
      query: query,
      entity: response[:entity],
      filters: response[:filters],
      confidence: response[:confidence],
      explanation: response[:explanation],
      success: response[:success],
      error_message: response[:error],
      user: user,
      locale: locale,
      raw_response: raw_response
    )
  end

  # Instance methods
  def summary
    if success?
      "#{entity}: #{filters} (#{confidence}%)"
    else
      "Error: #{error_message}"
    end
  end

  def high_confidence?
    confidence && confidence >= 80
  end

  def low_confidence?
    confidence && confidence < 70
  end
end

