class Shot < ApplicationRecord
  include LocalProtector
  include Translatable
  
  belongs_to :training_example
  belongs_to :end_ball_configuration,
             class_name: "BallConfiguration",
             optional: true,
             inverse_of: :ending_shots
  has_many :shot_events, -> { order(:sequence_number) }, dependent: :destroy
  has_many :ball_collisions, -> { order(:sequence_number) }, dependent: :destroy
  has_one_attached :shot_image
  
  validates :shot_type, presence: true, inclusion: { in: %w[ideal alternative error] }
  validates :sequence_number, presence: true, 
            uniqueness: { scope: :training_example_id }
  
  validate :trajectory_polylines_shape

  before_validation :set_sequence_number
  
  scope :ordered, -> { order(:sequence_number) }
  scope :ideal, -> { where(shot_type: 'ideal') }
  scope :alternative, -> { where(shot_type: 'alternative') }
  scope :errors, -> { where(shot_type: 'error') }
  
  def translatable_fields
    [
      :title,
      :notes,
      :end_position_description,
      :shot_description
    ]
  end
  
  def ideal?
    shot_type == 'ideal'
  end
  
  def alternative?
    shot_type == 'alternative'
  end
  
  def error?
    shot_type == 'error'
  end

  TRAJECTORY_BALLS = %w[b1 b2 b3].freeze

  # Lauflinie eines Balls als Punktfolge [[x, y], ...] (normalisiert 0..1).
  # Vorrang hat die gespeicherte Linie (trajectory_polylines, z. B. aus dem
  # Caromball-Extraktor). Sonst Rueckfall: Start -> Kollisionen/Events -> Ende;
  # Punkte ohne Koordinaten fallen weg.
  #
  # Ohne gemeinsame Zeitachse (`phase`, Backlog) pragmatisch: Kollisionen, in denen
  # der Ball Ziel ist, starten seine Linie; Kollisionen als Angreifer folgen den
  # eigenen Events mit niedrigerer Nummer.
  def trajectory_for(ball, start_configuration: training_example&.start_position&.ball_configuration)
    ball = ball.to_s
    stored = trajectory_polylines.to_h.stringify_keys[ball]
    return stored if stored.present?

    involved = ball_collisions.select { |c| c.ball_attacker == ball || c.ball_target == ball }
    as_target, as_attacker = involved.partition { |c| c.ball_target == ball }
    events = shot_events.select { |e| e.ball_involved == ball }
    along = (as_attacker.map { |c| [c.sequence_number, 0, c] } + events.map { |e| [e.sequence_number, 1, e] })
      .sort_by { |seq, rank, _| [seq, rank] }.map(&:last)

    points = [start_configuration&.balls&.dig(ball.to_sym)]
    points += (as_target.sort_by(&:sequence_number) + along).map { |r| self.class.point(r.contact_coords_normalized) }
    points << end_ball_configuration&.balls&.dig(ball.to_sym)
    points.compact
  end

  # contact_coords_normalized kommt in beiden Formen vor: {"x":, "y":} und [x, y].
  def self.point(coords)
    case coords
    when Hash then coords.stringify_keys.values_at("x", "y").then { |xy| xy if xy.all?(Numeric) }
    when Array then coords if coords.size == 2 && coords.all?(Numeric)
    end
  end

  private

  def trajectory_polylines_shape
    return errors.add(:trajectory_polylines, :invalid, message: "muss ein Objekt {b1: [[x, y], ...]} sein") unless trajectory_polylines.is_a?(Hash)

    unknown = trajectory_polylines.keys.map(&:to_s) - TRAJECTORY_BALLS
    errors.add(:trajectory_polylines, :invalid, message: "unbekannte Baelle: #{unknown.join(", ")}") if unknown.any?
    trajectory_polylines.each do |ball, points|
      next if points.is_a?(Array) && points.all? { |p| normalized_point?(p) }

      errors.add(:trajectory_polylines, :invalid, message: "#{ball}: jeder Punkt ein Paar [x, y] in 0..1")
    end
  end

  def normalized_point?(point)
    point.is_a?(Array) && point.size == 2 && point.all? { |v| v.is_a?(Numeric) && v.between?(0, 1) }
  end
  
  def set_sequence_number
    return if sequence_number.present?
    
    max_sequence = training_example.shots.maximum(:sequence_number) || 0
    self.sequence_number = max_sequence + 1
  end
end
