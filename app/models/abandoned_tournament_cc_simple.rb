# frozen_string_literal: true

class AbandonedTournamentCcSimple < ApplicationRecord
  validates :cc_id, presence: true, uniqueness: { scope: :context }
  validates :context, presence: true
  validates :abandoned_at, presence: true

  def self.is_abandoned?(cc_id, context)
    exists?(cc_id: cc_id, context: context)
  end

  def self.mark_abandoned!(cc_id, context)
    create!(
      cc_id: cc_id,
      context: context,
      abandoned_at: Time.current
    )
  rescue ActiveRecord::RecordNotUnique
    # Already marked as abandoned
  end
end 