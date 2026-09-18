# frozen_string_literal: true

# Kleiner, vollstaendiger Trainingsgraph fuer die TrainingPackage-Tests: jede der
# 13 Tabellen mit mindestens einer Zeile, dazu eine Eltern-Kind-Beziehung bei den
# Beispielen, deren Kind die KLEINERE ID hat (prueft die Import-Reihenfolge).
#
# Alle IDs explizit global (< MIN_ID): die Testumgebung laeuft als Local Server, ihre
# Sequenzen beginnen bei 50 Mio. — ohne explizite ID waere jeder Datensatz lokal.
module TrainingPackageTestHelper
  GRAPH_ID_BASE = 7_000_000

  def gid
    @gid = (@gid || GRAPH_ID_BASE) + 1
  end

  def build_training_graph
    source = TrainingSource.create!(id: gid, title: "Gretillat Band 1", author: "Gretillat", language: "en")
    dominance = TrainingConcept.create!(id: gid, title: "Dominanz", axis: "conception", key: "pkg_dominance")
    dam = TrainingConcept.create!(id: gid, title: "Sperre", axis: "conception", key: "pkg_the_dam")
    child = TrainingExample.create!(id: gid, title: "Kind-Beispiel")
    parent = TrainingExample.create!(id: gid, title: "Eltern-Beispiel")
    child.update!(parent: parent)
    bc = BallConfiguration.create!(id: gid, b1_x: 0.2, b1_y: 0.5, b2_x: 0.5, b2_y: 0.5, b3_x: 0.8, b3_y: 0.3,
      table_variant: "match", gather_state: "pre_gather", position_type: "exact")
    zone = TableZone.create!(id: gid, key: "pkg_zone", label: "Paket-Zone", zone_type: "custom")
    TrainingConceptRelation.create!(id: gid, source_concept: dam, target_concept: dominance, relation: "risk_of")
    TrainingConceptDiscipline.create!(id: gid, training_concept: dominance, discipline: Discipline.first!)
    TrainingConceptExample.create!(id: gid, training_concept: dominance, training_example: parent, weight: 5)
    StartPosition.create!(id: gid, training_example: parent, ball_configuration: bc, description_text: "Aufstellung")
    shot = Shot.create!(id: gid, training_example: parent, shot_type: "ideal", sequence_number: 1, title: "Stoss",
      source_language: "de", end_ball_configuration: bc)
    ShotEvent.create!(id: gid, shot: shot, sequence_number: 1, event_type: "sperre", ball_involved: "b2")
    BallConfigurationZone.create!(id: gid, ball_configuration: bc, table_zone: zone, which_ball: "b2", role: "target")
    SourceAttribution.create!(id: gid, training_source: source, sourceable: parent)
    {source: source, dominance: dominance, dam: dam, child: child, parent: parent, bc: bc, zone: zone, shot: shot}
  end

  # Wie aus einer Datei gelesen: nur String-Schluessel, nur JSON-Typen.
  def via_file(package)
    JSON.parse(JSON.generate(package))
  end

  # Leert alle Trainingstabellen, Kinder vor Eltern.
  def wipe_training_tables!
    TrainingPackage::TABLES.reverse_each do |table|
      if table == "training_examples"
        TrainingExample.unscoped.update_all(parent_id: nil)
      end
      TrainingPackage.model_for(table).unscoped.delete_all
    end
  end

  def training_row_counts
    TrainingPackage::TABLES.index_with { |t| TrainingPackage.model_for(t).unscoped.count }
  end
end
