# v0.9 Phase E: End-to-End-Beispiel — Gabriëls Stoß 1.
#
# Erste reale Anwendung des v0.9-Modells:
#   - TrainingExample flat (ohne direkte Concept-FK)
#   - M2M-Anbindung an mehrere Concepts über training_concept_examples
#     mit Gewichtung (weight 1-5):
#       · transferred_effect  (5) — paradigmatisch, der Lehrkern
#       · gather_shot         (3) — ein Sammelstoß unter vielen
#       · margin_of_error     (2) — peripher (links vs. rechts-Effet)
#       · dominance           (2) — peripher (Versammlung → Dominance)
#   - StartPosition → BallConfiguration (exact, Kleintisch, pre_gather)
#   - Shot mit Translatable, end_ball_configuration qualitativ
#   - ShotEvents (initial_contact → cushion_contact → final_carambolage)
#   - SourceAttribution am Example (Gabriëls 1944, Kap.1 S.1)
#
# Voraussetzungen: concepts.rb und concept_relations.rb sind gelaufen
# (alle Concepts per key auffindbar).
#
# Idempotent: find_or_initialize_by auf semantischen Keys; Ball-
# Configurations erkennt der SEED_MARKER im notes-Feld.
#
# Run: bin/rails runner db/seeds/examples/gabriels_01.rb

puts "Seed: Gabriëls Stoß 1 (v0.9 Phase E — End-to-End-Beispiel)"
puts "=" * 60

SEED_MARKER = "[SEED:gabriels_01]"

# -----------------------------------------------------------------
# 1. TrainingSource
# -----------------------------------------------------------------

source = TrainingSource.find_or_initialize_by(
  title: "Gabriëls — Vom Großen Spiel zur Amerika-Serie"
)
source.assign_attributes(
  author: "René Gabriëls",
  publication_year: 1944,
  publisher: "Eigenverlag, Antwerpen",
  language: "nl",
  notes: "Belgisches Libre-Positionslehrbuch für den Kleintisch " \
         "(105 × 210 cm), 193 durchnummerierte Stöße in Portrait- und " \
         "Querformat-Diagrammen. Deutsche Übersetzung durch Gernot " \
         "Ullrich (2026)."
)
source.save!
puts "  ✓ TrainingSource  ##{source.id}"

# -----------------------------------------------------------------
# 2. Discipline
# -----------------------------------------------------------------

discipline = Discipline.find_by!(name: "Freie Partie klein")
puts "  ✓ Discipline      ##{discipline.id} (#{discipline.name})"

# -----------------------------------------------------------------
# 3. BallConfiguration (Start) — exakte Gabriëls-Koordinaten
# -----------------------------------------------------------------

start_config = BallConfiguration.find_or_initialize_by(
  notes: "#{SEED_MARKER} Gabriëls Stoß 1 — Startstellung (Kleintisch, exakt)"
)
start_config.assign_attributes(
  b1_x: 0.10952380952380952, b1_y: 0.2571428571428571,
  b2_x: 0.23333333333333334, b2_y: 0.34285714285714286,
  b3_x: 0.02857142857142857, b3_y: 0.9142857142857143,
  table_variant:  "klein",
  gather_state:   "pre_gather",
  flow_direction: "centripetal",
  biais_degrees:  -106.6,
  biais_class:    "extreme",
  orientation:    "gather",
  position_type:  "exact"
)
start_config.save!
puts "  ✓ BallConfig      ##{start_config.id} (start, exact, extreme biais)"

# -----------------------------------------------------------------
# 4. BallConfiguration (Ende) — qualitativer DIN-A4-Cluster
# -----------------------------------------------------------------

end_config = BallConfiguration.find_or_initialize_by(
  notes: "#{SEED_MARKER} Gabriëls Stoß 1 — Endstellung (qualitativ, ~DIN-A4-Cluster)"
)
end_config.assign_attributes(
  b1_x: 0.08, b1_y: 0.85,
  b2_x: 0.06, b2_y: 0.93,
  b3_x: 0.03, b3_y: 0.91,
  table_variant:  "klein",
  gather_state:   "post_gather",
  orientation:    "gather",
  position_type:  "qualitative"
)
end_config.save!
puts "  ✓ BallConfig      ##{end_config.id} (end, qualitative, post_gather cluster)"

# -----------------------------------------------------------------
# 5. TrainingExample (flach, ohne direkte Concept-FK)
# -----------------------------------------------------------------

example = TrainingExample.find_or_initialize_by(
  title: "Gabriëls Stoß 1 — Sammelstoß mit Links-Effet"
)
example.assign_attributes(
  source_language: "de",
  source_notes: "Gabriëls 1944, Kapitel 1 Stoß 1, deutsche " \
                "Übersetzung Ullrich 2026.",
  ideal_stroke_parameters_text: <<~PARAMS
    - Effet: Linker Effet (Gabriëls explizit, Intensität nicht angegeben)
    - Quantität der Bille: in der Quelle nicht explizit
    - Höhe des Angriffs: in der Quelle nicht explizit
    - Energie: in der Quelle nicht explizit
    - Amorti-Ziel (B1↔B3 nach Karambolage): nicht angegeben

    Die Quelle fokussiert ausschließlich auf die Effet-Wahl; die
    übrigen vier Grundparameter bleiben implizit und müssten beim
    konkreten Spiel aus Erfahrung ergänzt werden.
  PARAMS
)
example.save!
puts "  ✓ TrainingExample ##{example.id}"

# -----------------------------------------------------------------
# 6. M2M-Anbindung: 4 Concepts mit Gewichtung
# -----------------------------------------------------------------
#
# Gewichtungs-Logik:
#   5 = paradigmatisch — Lehrbuch-Exemplar für DIESES Concept
#   3 = solide passend — ein Beispiel unter vielen
#   2 = peripher — streift das Concept, aber nicht dessen Lehrkern
#   1 = tangential

CONCEPT_LINKS = [
  { key: "transferred_effect", weight: 5, sequence_number: 1,
    notes: "Gabriëls wählt genau diesen Stoß, um das Übertragungseffet " \
           "pädagogisch einzuführen. Paradigmatisches Lehrbeispiel." },
  { key: "gather_shot",        weight: 3, sequence_number: 1,
    notes: "Ein Sammelstoß unter vielen; als Anfänger-Einstieg in die " \
           "Sammel-Strategie gewählt, nicht als komplexeste Instanz." },
  { key: "margin_of_error",    weight: 2, sequence_number: nil,
    notes: "Links- vs. Rechts-Effet öffnet/schließt den Spielraum für " \
           "B2's Weg zu B3. Peripher — der margin-Kontrast ist Nebenprodukt " \
           "der Effet-Lehre, nicht das Hauptziel." },
  { key: "dominance",          weight: 2, sequence_number: nil,
    notes: "Das Sammel-Ergebnis ist Dominance-Grundlage. Peripher — " \
           "Dominance ist erreichtes Resultat, nicht zu übendes Element." }
]

example.training_concept_examples.destroy_all  # idempotenter Reset

CONCEPT_LINKS.each do |link|
  c = TrainingConcept.find_by!(key: link[:key])
  TrainingConceptExample.create!(
    training_concept: c,
    training_example: example,
    weight:           link[:weight],
    sequence_number:  link[:sequence_number],
    role:             "illustrates",
    notes:            link[:notes]
  )
  puts "    · #{link[:key].ljust(20)} weight=#{link[:weight]}"
end

# -----------------------------------------------------------------
# 7. SourceAttribution am Example
# -----------------------------------------------------------------

attribution = SourceAttribution.find_or_initialize_by(
  training_source: source,
  sourceable_type: "TrainingExample",
  sourceable_id:   example.id
)
attribution.reference = "Kapitel 1, Stoß 1 (S. 1 der deutschen Übersetzung)"
attribution.notes = "Originalpassage: Allgemeine Bemerkungen und " \
                    "Erklärung der Zeichnungen, Einführungsstoß."
attribution.save!
puts "  ✓ SourceAttribution ##{attribution.id} → TrainingExample"

# -----------------------------------------------------------------
# 8. StartPosition
# -----------------------------------------------------------------

sp = StartPosition.find_or_initialize_by(training_example: example)
sp.assign_attributes(
  ball_configuration: start_config,
  source_language: "de",
  description_text: <<~DESC
    Kleintisch-Setup (105 × 210 cm). Spielball (B1) liegt 27 cm von
    der linken langen Bande und 23 cm von der unteren kurzen Bande.
    Ball 2 liegt weiter innen (36 links, 49 unten). Ball 3 liegt in
    der gegenüberliegenden Tischhälfte, sehr nahe an der kurzen Bande
    (6 unten) und nahe der rechten langen Bande (9 rechts).

    Die Stellung hat einen extremen Biais von -106,6° — B3 liegt
    nahezu hinter B1/B2 aus Spielball-Sicht und kann nicht direkt über
    B2 erreicht werden. Typische Sammel-Setup-Signatur.
  DESC
)
sp.save!
puts "  ✓ StartPosition   ##{sp.id}"

# -----------------------------------------------------------------
# 9. Shot
# -----------------------------------------------------------------

# Unique-Index ist (training_example_id, sequence_number) — wir
# nehmen sequence_number=1 als kanonischen ersten (und einzigen) Shot
# für dieses Example.
shot = example.shots.find_or_initialize_by(sequence_number: 1)
shot.assign_attributes(
  shot_type: "ideal",
  source_language: "de",
  end_ball_configuration: end_config,
  title: "Gabriëls Stoß 1 — Sammelstoß mit Links-Effet",
  notes: "Erster Stoß in Gabriëls' Buch. Pedagogische Funktion: " \
         "Übertragungseffet demonstrieren (Zahnrad-Analogie). " \
         "Ausführliche Effet-Theorie folgt im Kap. 1 §20 auf S. 138 ff.",
  shot_description: <<~DESCR,
    Spielball wird mit linkem Effet angespielt. Beim Kontakt überträgt
    sich der Effet gegenläufig auf Ball 2 (Zahnrad-Analogie: linker
    Effet am B1 → rechtsdrehender B2). Der so in Rotation versetzte
    B2 läuft nach Kontakt mit der kurzen Bande zum dritten Ball hin.
    Gabriëls nennt diesen Stoß-Typ einen Sammelstoß (nl. „verzamel-
    stoot", fr. „rappel").

    Regulär für Libre: B1 muss sowohl B2 als auch B3 berühren, um den
    Punkt zu erzielen. Gabriëls beschreibt B2's Weg, weil dort die
    Effet-Steuerung sichtbar wird; B1's Weg zu B3 ergibt sich aus der
    gewählten Linie und wird nicht eigens kommentiert.

    Kontrastvariante (falsch, Anfängerfehler): rechter Effet erzeugt
    linksdrehenden B2, der entlang der im Original gestrichelten Linie
    an B3 vorbei läuft — Versammlung misslingt, Folgestellung zerstört.
  DESCR
  end_position_description: "Alle drei Bälle sind in der unteren " \
                            "Tischhälfte in der Nähe der ursprünglichen " \
                            "B3-Position versammelt (Cluster ~DIN-A4-" \
                            "Fläche). Exakte Endkoordinaten sind von " \
                            "Gabriëls nicht angegeben; die Endkonfiguration " \
                            "trägt position_type=qualitative.",
  shot_parameters: {
    effect: "left",
    quantity_of_ball: nil,
    height_of_attack: nil,
    energy: nil,
    amorti_target_cm: nil
  }
)
shot.save!
puts "  ✓ Shot            ##{shot.id}"

# -----------------------------------------------------------------
# 10. ShotEvents
# -----------------------------------------------------------------

shot.shot_events.destroy_all  # idempotenter Reset
shot.shot_events.create!([
  {
    sequence_number: 1,
    event_type:      "initial_contact",
    ball_involved:   "b1",
    notes:           "B1 trifft B2. Linker Effet am Spielball wird bei " \
                     "diesem Kontakt gegenläufig auf B2 übertragen " \
                     "(Zahnrad-Analogie) — B2 beginnt rechtsdrehend."
  },
  {
    sequence_number: 2,
    event_type:      "cushion_contact",
    ball_involved:   "b2",
    notes:           "B2 trifft die kurze Bande im niedrigen " \
                     "x-Bereich des Tisches. Durch den Rechts-Drehsinn " \
                     "(aus dem übertragenen Effet) wird B2 nach dem " \
                     "Bandenabprall zur B3-Position hin abgelenkt."
  },
  {
    sequence_number: 3,
    event_type:      "final_carambolage",
    ball_involved:   "b1",
    notes:           "B1 trifft B3 — Karambolage erzielt. B1 erreicht " \
                     "B3 auf der aus der gewählten Linie resultierenden " \
                     "Bahn; Gabriëls kommentiert diesen Pfad nicht " \
                     "eigens, weil die pädagogische Aufmerksamkeit auf " \
                     "B2's effet-gesteuertem Weg liegt. Endstellung: " \
                     "alle drei Bälle auf ~DIN-A4-Fläche versammelt."
  }
])
puts "  ✓ ShotEvents: #{shot.shot_events.count} (initial → cushion → final)"

# -----------------------------------------------------------------
# Zusammenfassung
# -----------------------------------------------------------------

example.reload
puts "=" * 60
puts "Gabriëls Stoß 1 v0.9 end-to-end gelandet:"
puts "  Example ##{example.id} → #{example.training_concepts.count} Concepts " \
     "(weights: #{example.training_concept_examples.pluck(:weight).sort.reverse})"
puts "  Shot    ##{shot.id} mit #{shot.shot_events.count} Events"
puts "  Start/End BallConfigs: ##{start_config.id}/##{end_config.id}"
puts "=" * 60
