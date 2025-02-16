module Theme
  extend ActiveSupport::Concern

  THEMES = %w[light dark system].freeze

  included do
    validates :theme, inclusion: { in: THEMES }, allow_nil: true
  end

  def self.themes
    THEMES
  end
end 