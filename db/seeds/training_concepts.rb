# Training Concepts Seed Data
# This file contains example training concepts for billiards

puts "Creating training concepts..."

# Find or create a discipline (Dreiband)
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

# Add a training example
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

# Add starting position
example1.create_starting_position!(
  description_text: <<~DESC,
    Ball 1 (Weiß): Position nahe der kurzen Bande, ca. 30cm vom Rand
    Ball 2 (Gelb): In der Mitte des Tisches
    Ball 3 (Rot): Nahe der gegenüberliegenden langen Bande
  DESC
  ball_measurements: {
    b1: { x: 50, y: 150, description: "Spielball nahe kurzer Bande" },
    b2: { x: 142, y: 142, description: "Ball 2 in Tischmitte" },
    b3: { x: 234, y: 50, description: "Ball 3 nahe langer Bande" }
  },
  position_variants: [
    {
      name: "Variant A - Engerer Winkel",
      b1: { x: 45, y: 145 },
      b2: { x: 140, y: 145 }
    },
    {
      name: "Variant B - Weiterer Winkel",
      b1: { x: 55, y: 155 },
      b2: { x: 145, y: 140 }
    }
  ]
)

# Add target position
example1.create_target_position!(
  description_text: <<~DESC,
    Nach dem Stoß sollte der Spielball:
    - Von Ball 1 zur kurzen Bande laufen
    - Dann zur langen Bande
    - Anschließend Ball 2 treffen
    - Und schließlich Ball 3 karambolieren
  DESC
  ball_measurements: {
    b1: { x: 50, y: 150, description: "Ball 1 bleibt stehen" },
    b2: { x: 142, y: 142, description: "Ball 2 wurde getroffen" },
    b3: { x: 234, y: 50, description: "Ball 3 wurde karamboliert" },
    cue_ball_path: [
      { x: 50, y: 150 },
      { x: 30, y: 50 },
      { x: 180, y: 30 },
      { x: 142, y: 142 },
      { x: 234, y: 50 }
    ]
  }
)

# Add error examples
example1.error_examples.create!(
  title: "Zu wenig Effet",
  sequence_number: 1,
  stroke_parameters_text: <<~PARAMS,
    - Effet: Zu wenig oder gar kein Rechtseffet
    - Kraft: Mittel (60%)
    - Folge: Der Ball läuft nicht weit genug zur zweiten Bande
  PARAMS
  end_position_description: "Der Spielball erreicht Ball 2 nicht und bleibt auf halber Strecke stehen."
)

example1.error_examples.create!(
  title: "Zu viel Kraft",
  sequence_number: 2,
  stroke_parameters_text: <<~PARAMS,
    - Effet: Korrekt (Rechtseffet)
    - Kraft: Zu stark (über 80%)
    - Folge: Der Ball läuft zu weit und verfehlt Ball 3
  PARAMS
  end_position_description: "Der Spielball trifft Ball 2, aber läuft zu weit über Ball 3 hinaus."
)

puts "✓ Created training concept: #{konterspiel.title}"
puts "  - #{konterspiel.training_examples.count} example(s)"
puts "  - #{example1.error_examples.count} error example(s)"

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

example2.create_starting_position!(
  description_text: "Drei Bälle in einer Linie, mittlerer Abstand",
  ball_measurements: {
    b1: { x: 100, y: 142, description: "Ball 1" },
    b2: { x: 142, y: 142, description: "Ball 2" },
    b3: { x: 184, y: 142, description: "Ball 3" }
  }
)

example2.create_target_position!(
  description_text: "Spielball läuft zurück nach dem Treffer",
  ball_measurements: {
    b1: { x: 100, y: 142 },
    b2: { x: 142, y: 142 },
    b3: { x: 184, y: 142 },
    cue_ball_final: { x: 60, y: 142, description: "Spielball Position nach Rücklauf" }
  }
)

puts "✓ Created training concept: #{ruecklaufer.title}"
puts "  - #{ruecklaufer.training_examples.count} example(s)"

puts "\n" + "="*50
puts "Training Concepts seeding completed!"
puts "Total concepts: #{TrainingConcept.count}"
puts "Total examples: #{TrainingExample.count}"
puts "="*50
