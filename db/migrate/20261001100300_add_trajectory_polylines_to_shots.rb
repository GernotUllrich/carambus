# frozen_string_literal: true

class AddTrajectoryPolylinesToShots < ActiveRecord::Migration[7.2]
  # v0.10 (Design-Doc §8 Punkt 1): Lauflinie je Ball als Daten, z. B. aus dem
  # Caromball-Extraktor. Format {"b1": [[x, y], …], "b2": […], "b3": […]},
  # normalisiert wie ball_configurations (x lange, y kurze Achse, jeweils 0..1).
  # Einzelne Baelle duerfen fehlen — das Diagramm konstruiert die Linie dann aus
  # Start → Kollisionen/Events → Ende.
  def change
    add_column :shots, :trajectory_polylines, :jsonb, default: {}, null: false
  end
end
