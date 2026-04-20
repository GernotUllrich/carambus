# Training Concepts Seed Data
# Example training concepts for billiards.
# Updated for ontology v0.7: ball positions live in typed BallConfiguration
# records (normalized coords 0..1, table_variant, gather_state).
#
# v0.8 Tier 2C: Translatable-Blocker auf `shots` behoben. Die Raw-Spalten
# title / notes / end_position_description / shot_description existieren
# jetzt, sync_source_language_fields arbeitet korrekt. Shot-Seeds können
# nach Bedarf hinzugefügt werden (kein Muss — dieses Seed hält sich auf
# Concept/Example/BallConfiguration-Ebene).

puts "Creating training concepts..."

dreiband = Discipline.find_or_create_by!(name: "Dreiband klein") do |d|
  d.table_kind = TableKind.find_by(name: "Small Billard")
end

# Example 1: Konterspiel (Counter-play)
konterspiel = TrainingConcept.create!(
  title: "Konterspiel",
  short_description: "Grundlagen des Konterspiels beim Dreiband",
  full_description: <<~DESC,
    Das Konterspiel ist eine fundamentale Technik im Dreiband-Billard.
    Dabei wird der erste Ball so angespielt, dass der Spielball über zwei
    Banden zum zweiten Ball läuft.

    Wichtig ist dabei:
    - Die richtige Bandenwahl
    - Die korrekte Kraftdosierung
    - Der optimale Effet
  DESC
  source_language: 'de',
  disciplines: [dreiband]
)

example1 = konterspiel.training_examples.create!(
  title: "Einfaches Konterspiel mit kurzer Linie",
  sequence_number: 1,
  ideal_stroke_parameters_text: <<~PARAMS
    - Effet: Rechtseffet (ca. 1 Spitze)
    - Kraft: Mittel (ca. 60%)
    - Zielpunkt am Ball 1: Voll
    - Lauflinie: Kurze Bande -> Lange Bande
  PARAMS
)

start_config_1 = BallConfiguration.create!(
  b1_x: 0.18, b1_y: 0.50,
  b2_x: 0.50, b2_y: 0.50,
  b3_x: 0.82, b3_y: 0.30,
  table_variant: "match",
  gather_state: "pre_gather",
  notes: "Konterspiel, kurze Linie, Ausgangsposition"
)

example1.create_start_position!(
  description_text: <<~DESC,
    Ball 1 (Weiß): Position nahe der kurzen Bande, ca. 30cm vom Rand
    Ball 2 (Gelb): In der Mitte des Tisches
    Ball 3 (Rot): Nahe der gegenüberliegenden langen Bande
  DESC
  ball_configuration: start_config_1
)

puts "✓ Created training concept: #{konterspiel.title}"
puts "  - #{konterspiel.training_examples.count} example(s)"

# Example 2: Rückläufer
ruecklaufer = TrainingConcept.create!(
  title: "Rückläufer",
  short_description: "Technik des Rücklaufs mit Rückwärtseffet",
  full_description: <<~DESC,
    Der Rückläufer ist eine Technik, bei der der Spielball nach dem
    Treffen der Objektbälle zurückläuft. Dies wird durch starkes
    Rückwärtseffet erreicht.

    Anwendung:
    - Positionsspiel
    - Defensive Stöße
    - Bandenspiel
  DESC
  source_language: 'de',
  disciplines: [dreiband]
)

example2 = ruecklaufer.training_examples.create!(
  title: "Einfacher Rückläufer",
  sequence_number: 1,
  ideal_stroke_parameters_text: <<~PARAMS
    - Effet: Starkes Rückwärtseffet (untere Hälfte des Balls)
    - Kraft: Kräftig (ca. 75%)
    - Zielpunkt: Voll auf Ball 1
    - Queue-Haltung: Leicht nach unten geneigt
  PARAMS
)

start_config_2 = BallConfiguration.create!(
  b1_x: 0.35, b1_y: 0.50,
  b2_x: 0.50, b2_y: 0.50,
  b3_x: 0.65, b3_y: 0.50,
  table_variant: "match",
  gather_state: "pre_gather",
  notes: "Rückläufer-Linienstellung"
)

example2.create_start_position!(
  description_text: "Drei Bälle in einer Linie, mittlerer Abstand",
  ball_configuration: start_config_2
)

puts "✓ Created training concept: #{ruecklaufer.title}"
puts "  - #{ruecklaufer.training_examples.count} example(s)"

puts "\n" + "=" * 50
puts "Training Concepts seeding completed!"
puts "Total concepts:            #{TrainingConcept.count}"
puts "Total examples:            #{TrainingExample.count}"
puts "Total start_positions:     #{StartPosition.count}"
puts "Total ball_configurations: #{BallConfiguration.count}"
puts "=" * 50
