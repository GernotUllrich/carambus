# frozen_string_literal: true

# v0.10: Ball-Ball-Treffpunkt innerhalb eines Stosses — die Realisierung, waehrend
# Shot#shot_parameters die Intention traegt. Eigene Sequenz je Stoss; die
# gemeinsame Zeitachse mit ShotEvent (`phase`) bleibt Backlog, bis ein Beispiel sie
# braucht. Design-Doc: TRAINING_SOURCES/mapping/2026-04-25_shot_trajectory_design.md §6/§8.
class BallCollision < ApplicationRecord
  include LocalProtector

  COLLISION_TYPES = %w[primary_impact secondary_impact carambolage].freeze
  BALLS = %w[b1 b2 b3].freeze

  enum :collision_type, COLLISION_TYPES.index_with(&:itself), prefix: :collision
  enum :ball_attacker, BALLS.index_with(&:itself), prefix: :attacker
  enum :ball_target, BALLS.index_with(&:itself), prefix: :target

  belongs_to :shot

  validates :sequence_number, presence: true,
    numericality: {only_integer: true, greater_than: 0},
    uniqueness: {scope: :shot_id}
  validates :collision_type, :ball_attacker, :ball_target, presence: true
  validates :quantity_of_ball, numericality: {in: 0..1}, allow_nil: true
  validates :force, :speed, numericality: {only_integer: true, in: 1..4}, allow_nil: true
  validates :effect_vertical, :effect_horizontal, numericality: {only_integer: true, in: -3..3}, allow_nil: true
  validate :attacker_differs_from_target
  validate :scored_only_for_carambolage

  scope :ordered, -> { order(:sequence_number) }

  private

  def attacker_differs_from_target
    errors.add(:ball_target, :same_as_attacker, message: "darf nicht der Angreifer sein") if ball_attacker.present? && ball_attacker == ball_target
  end

  def scored_only_for_carambolage
    errors.add(:scored, :only_for_carambolage, message: "nur bei carambolage") if !scored.nil? && !collision_carambolage?
  end
end
