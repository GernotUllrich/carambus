# v0.9 Phase E: Concept-Graph. Typisierte Beziehungen zwischen den
# Concepts aus db/seeds/concepts.rb. Die Relationen begründen, warum
# die Principles (jetzt Concepts mit kind ≠ topic) pädagogisch unter
# Topic-Concepts wie "Versammlungsstoß" einsortiert werden.
#
# Idempotent: find_or_create_by auf (source, target, relation).
# Setzt voraus, dass concepts.rb vorher gelaufen ist (alle Concepts
# sind per key auffindbar).
#
# Run: bin/rails runner db/seeds/concept_relations.rb

puts "Seed: Concept Relations (v0.9 Phase E)"
puts "=" * 60

def concept(key)
  TrainingConcept.find_by!(key: key)
end

RELATIONS_SEED = [
  # Versammlungsstoß als Topic wendet diverse Principles an ------------
  {
    source: "gather_shot", target: "transferred_effect", relation: "applies",
    notes: "Sammelstöße stehen und fallen mit der Beherrschung des " \
           "Übertragungseffets — der Effet am B1 steuert, wohin B2 nach " \
           "dem Bandenkontakt läuft und damit die erreichbare " \
           "Versammlungszone."
  },
  {
    source: "gather_shot", target: "dominance", relation: "applies",
    notes: "Die Versammlung ist die geometrische Grundlage für " \
           "Dominance in der Folgestellung."
  },
  {
    source: "gather_shot", target: "margin_of_error", relation: "applies",
    notes: "Die Effet-Wahl beim Sammelstoß öffnet oder schließt den " \
           "margin für B2's Weg zum Zielball."
  },
  {
    source: "gather_shot", target: "the_dam", relation: "applies",
    notes: "Wenn die Versammlung nicht direkt erreichbar ist, gilt der " \
           "Damm: lieber defensiv parken als die Position aufgeben."
  },
  {
    source: "gather_shot", target: "security_primacy", relation: "teaches",
    notes: "Der Sammelstoß ist die praktische Lehre des Sicherungs-" \
           "Primats: die Folgestellung hat Vorrang vor dem Einzelpunkt."
  },

  # Prinzipien-Quervernetzung ------------------------------------------
  {
    source: "risk_factor", target: "margin_of_error", relation: "applies",
    notes: "Risiko-Faktor kombiniert margin_of_error mit den Folge-" \
           "Konsequenzen — beides zusammen ergibt die Stoß-Wahl."
  },
  {
    source: "follow_over_point", target: "security_primacy", relation: "specializes",
    notes: "'Folge über Punkt' ist die operative Zuspitzung des " \
           "allgemeineren Sicherungs-Primats: beide Konzepte sind nicht " \
           "gleichrangig, sondern follow_over_point ist ein konkreter " \
           "Anwendungsfall."
  }
].freeze

RELATIONS_SEED.each do |attrs|
  r = TrainingConceptRelation.find_or_initialize_by(
    source_concept: concept(attrs[:source]),
    target_concept: concept(attrs[:target]),
    relation:       attrs[:relation]
  )
  r.notes = attrs[:notes]
  r.save!
  puts "  ✓ #{attrs[:source].ljust(20)} --#{attrs[:relation].ljust(12)}--> #{attrs[:target]}"
end

puts "=" * 60
puts "Concept Relations seeding completed. Total: " \
     "#{TrainingConceptRelation.count}"
