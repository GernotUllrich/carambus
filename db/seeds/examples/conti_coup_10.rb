# v0.9 Phase E+: Zweites End-to-End-Beispiel — Conti Coup 10.
# v0.10 (2026-10-01): Koordinaten, Lauflinien und Ball-Kollisionen aus
# Gernots Caromball-Nachstellung (TRAINING_SOURCES:
# extractions/conti_coup_10_caromball.json, Herleitung in
# mapping/2026-10-01_conti_coup_10_v010_seed_teile.rb).
#
# Profil gegenüber Gabriëls #1:
#   - Quelle vom Matchtisch, proportional über die Diamanten auf das
#     kleine Turnierbillard 210 × 105 übertragen (ONTOLOGY "Tisch-Geometrie")
#   - Amorti als Lehrziel, nicht Übertragungseffet
#   - B 2 sehr voll (8/10) ohne Seiteneffet, Rappel über drei Banden
#   - B 3 minimal verschoben (Heft: 4-5 cm) = "perfekter Amorti"
#
# M2M-Anbindung an vier Concepts mit Gewichtung:
#       · amorti                          (5) — paradigmatisch, der Lehrkern
#       · b2_selection_by_closer_cushion  (4) — Seite-1-Nota angewendet
#       · line_series                     (3) — Einführungs-Coup einer von 10
#       · margin_of_error                 (2) — peripher (Amorti ist Margin)
#
# Voraussetzungen: concepts.rb (v0.9 Phase E mit den drei neuen
# Concepts aus 2026-04-23) ist gelaufen.
#
# Idempotent: find_or_initialize_by auf semantischen Keys; Ball-
# Configurations erkennt der SEED_MARKER im notes-Feld. Kollisionen und
# Ereignisse werden über (Stoß, [Ball,] Nummer) upgesertet, damit
# bestehende Zeilen ihre IDs behalten.
#
# Run: bin/rails runner db/seeds/examples/conti_coup_10.rb

puts "Seed: Conti Coup 10 (v0.9 Phase E+ — 2. End-to-End-Beispiel)"
puts "=" * 60

SEED_MARKER = "[SEED:conti_coup_10]"

# -----------------------------------------------------------------
# 1. TrainingSource
# -----------------------------------------------------------------

source = TrainingSource.find_or_initialize_by(
  title: "Conti-Studienheft — Freie-Partie-Serien-Positionen"
)
source.assign_attributes(
  author: "Annotator (unbekannt), zitiert R. Conti",
  publication_year: 1944,
  publisher: "Studienheft, nicht-kommerziell",
  language: "fr",
  notes: "Handgezeichnetes persönliches Studienheft zu Roger Contis " \
         "Serienspiel-Material. Autor-Identität ungeklärt (Datums-" \
         "Eingravierungen 1944 und 1946). Seiten 1–62 maschinenlesbar " \
         "(orange Annotationen), 63–151 handschriftlich. Umfasst ~151 " \
         "nummerierte Coups, teils mit bis/a-Varianten. Deutsche " \
         "Übersetzung der maschinenlesbaren Teile als `Conti_1_62.de.md`."
)
source.save!
puts "  ✓ TrainingSource  ##{source.id}"

# -----------------------------------------------------------------
# 2. Discipline
# -----------------------------------------------------------------

discipline = Discipline.find_by!(name: "Freie Partie klein")
# Zieltisch 210 × 105: Contis Matchtisch-Stellung ist proportional
# übertragen (ONTOLOGY "Tisch-Geometrie").
puts "  ✓ Discipline      ##{discipline.id} (#{discipline.name})"

# -----------------------------------------------------------------
# 3. BallConfiguration (Start)
# -----------------------------------------------------------------
#
# Caromball-Nachstellung von Heft S. 9 (Basisfassung: Effet 0 %,
# Anspielhöhe 5 %, Neigung 3°, 80 % voll). Normalisiert, proportional
# auf 210 × 105. Abweichung zu Gernots gespeichertem Caromball-Favoriten
# "Conti 10a" ≤ 1,3 cm.

# Lookup über Marker + Rolle, damit sich die notes ändern dürfen, ohne
# eine zweite Konfiguration anzulegen.
def coup10_config(role)
  BallConfiguration.where("notes LIKE ?", "#{SEED_MARKER} Conti Coup 10 — #{role}%").first ||
    BallConfiguration.new
end

start_config = coup10_config("Startstellung")
start_config.assign_attributes(
  notes: "#{SEED_MARKER} Conti Coup 10 — Startstellung " \
         "(Caromball-Nachstellung Heft S. 9, proportional auf 210 × 105)",
  b1_x: 0.8433, b1_y: 0.8796,
  b2_x: 0.7817, b2_y: 0.9465,
  b3_x: 0.8430, b3_y: 0.8056,
  table_variant:  "klein",
  # gather_state hat kein sauberes Semantik-Match für Linienserien;
  # pragmatisch "gathering" (Mapping-Analyse §3.2).
  gather_state:   "gathering",
  flow_direction: nil,
  biais_degrees:  nil,
  biais_class:    "faible",
  orientation:    "gather",
  position_type:  "approximate"
)
start_config.save!
puts "  ✓ BallConfig      ##{start_config.id} (start, approximate, klein)"

# -----------------------------------------------------------------
# 4. BallConfiguration (Ende)
# -----------------------------------------------------------------

end_config = coup10_config("Endstellung")
end_config.assign_attributes(
  notes: "#{SEED_MARKER} Conti Coup 10 — Endstellung " \
         "(B 1 an B 3, B 2 nach drei Banden zurück; Caromball)",
  b1_x: 0.8194, b1_y: 0.8465,   # B 1 bleibt an B 3 liegen
  b2_x: 0.8408, b2_y: 0.7303,   # B 2 nach drei Banden zurück bei der Gruppe
  b3_x: 0.8739, b3_y: 0.8275,   # B 3 wenige cm verschoben
  table_variant:  "klein",
  gather_state:   "gathering",
  orientation:    "gather",
  position_type:  "approximate"
)
end_config.save!
puts "  ✓ BallConfig      ##{end_config.id} (end, approximate, klein)"

# -----------------------------------------------------------------
# 5. TrainingExample (flach, ohne direkte Concept-FK)
# -----------------------------------------------------------------

example = TrainingExample.find_or_initialize_by(
  title: "Conti Coup 10 — 1-Banden-Stoß mit perfektem Amorti"
)
example.assign_attributes(
  source_language: "de",
  source_notes: "Conti-Studienheft Coup 10, Teil 1 (Seiten 1-62, " \
                "maschinenlesbar). Annotator-Stimme, Prinzip-" \
                "Autorität R. Conti. Kapitel-Kontext: Coups 1-10 = " \
                "Einführung der Linien-Serie-Grundregeln.",
  ideal_stroke_parameters_text: <<~PARAMS
    - Effet: Kein Seiteneffet (quellenexplizit "ohne Seiteneffet")
    - Quantität der Bille: ~8/10 (sehr voll, quellenexplizit)
    - Höhe des Angriffs: Knapp über Zentrum (quellenexplizit)
    - Energie: In der Quelle nicht explizit. Implizit dosiert:
      stark genug für 1-Banden-Weg, schwach genug für 5 cm
      B 3-Verschiebung.
    - Amorti-Ziel: 4-5 cm B 3-Verschiebung (quellenexplizit).

    Die Energie-Dosierung ist der Lehrkern dieses Coups — der
    Annotator nennt ihn "1-Banden mit perfektem Amorti", wo
    "perfekt" die Kalibrierung zwischen Bandenweg-Sicherung und
    B 3-Mini-Verschiebung bezeichnet.
  PARAMS
)
example.save!
puts "  ✓ TrainingExample ##{example.id}"

# -----------------------------------------------------------------
# 6. M2M-Anbindung: 4 Concepts mit Gewichtung
# -----------------------------------------------------------------

CONCEPT_LINKS = [
  { key: "amorti",                           weight: 5, sequence_number: 1,
    notes: "Paradigmatisches Lehrbeispiel für Amorti: die Coup-" \
           "Überschrift ist wörtlich '1-Banden mit perfektem Amorti'. " \
           "Die 4-5 cm B 3-Verschiebung ist der Amorti-Zielwert." },
  { key: "b2_selection_by_closer_cushion",   weight: 4, sequence_number: nil,
    notes: "Coup 10 gehört zu den Einführungs-Coups 1-10, die die " \
           "Seite-1-Nota-Grundregel (B 2 = Kugel der Ziel-Bande am " \
           "nächsten) exemplifizieren. Die B 2-Wahl ist hier durch " \
           "Bandennähe bestimmt, nicht beliebig." },
  { key: "line_series",                      weight: 3, sequence_number: 10,
    notes: "Einer von 10 Einführungs-Coups des Linienserien-" \
           "Kapitels. Demonstriert die Linien-Formations-Logik, ist " \
           "aber nicht der paradigmatischste Linienserien-Coup des " \
           "Heftes — dafür sind Coups 1, 5, 6 stärker." },
  { key: "margin_of_error",                  weight: 2, sequence_number: nil,
    notes: "Peripher: die präzise Amorti-Kalibrierung (4-5 cm) IST " \
           "eine Sicherheitsmarge gegen ungewollte B 3-Verschiebung, " \
           "aber Amorti-Technik ist das Thema, nicht margin selbst." }
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
  puts "    · #{link[:key].ljust(32)} weight=#{link[:weight]}"
end

# -----------------------------------------------------------------
# 7. SourceAttribution am Example
# -----------------------------------------------------------------

attribution = SourceAttribution.find_or_initialize_by(
  training_source: source,
  sourceable_type: "TrainingExample",
  sourceable_id:   example.id
)
attribution.reference = "Coup 10, Conti_1_62.pdf S. 9"
attribution.notes = "Textquelle der Annotator-Stimme: '1-Banden mit " \
                    "perfektem Amorti. B 1 knapp über Zentrum ohne " \
                    "Seiteneffet. B 2 sehr voll (~8/10). B 3 verschiebt " \
                    "sich nur 4–5 cm.' Keine Verbatim-Extraktion Conti-" \
                    "Prosa (Lizenz-Policy). Koordinaten aus Caromball-" \
                    "Nachstellung (Gernot, 2026-10-01); Variante mit " \
                    "Linkseffet in TRAINING_SOURCES extractions/" \
                    "conti_coup_10_caromball_variante_effet_links.json."
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
    Kleines Turnierbillard (2,10 × 1,05 m), Stellung proportional über
    die Diamanten von Contis Matchtisch übertragen. Alle drei Bälle
    liegen nahe der unteren langen Bande, knapp ein Viertel vor der
    rechten kurzen Bande: B 2 (rot) dicht an der langen Bande, B 1
    (weiß) schräg darüber, B 3 (gelb) direkt oberhalb von B 1.

    Koordinaten aus Gernots Caromball-Nachstellung des Heft-Diagramms
    (S. 9); position_type=approximate.
  DESC
)
sp.save!
puts "  ✓ StartPosition   ##{sp.id}"

# -----------------------------------------------------------------
# 9. Shot
# -----------------------------------------------------------------

shot = example.shots.find_or_initialize_by(sequence_number: 1)
shot.assign_attributes(
  shot_type: "ideal",
  source_language: "de",
  end_ball_configuration: end_config,
  title: "Conti Coup 10 — 1-Banden mit perfektem Amorti",
  notes: "Zehnter Coup in Contis Studienheft, Schlusspunkt des " \
         "Einführungs-Kapitels der Linien-Serie. Lehrfokus: " \
         "Energie-Kalibrierung für minimale B 3-Verschiebung bei " \
         "voller B 2-Konfrontation.",
  shot_description: <<~DESCR,
    Einbänder mit perfektem Amorti und Rappel der 2 über drei Banden.
    B 1 wird knapp über der Mitte ohne Seiteneffet gespielt und trifft
    B 2 sehr voll (ca. 8/10). B 2 läuft über die nahe lange Bande, die
    kurze Bande und die gegenüberliegende lange Bande zurück und kommt
    wieder bei der Gruppe an. B 1 geht nach dem Treffer über die nahe
    lange Bande und bleibt mit der letzten Energie an B 3 liegen; B 3
    wird nur wenige Zentimeter verschoben.

    Lehrkern: Der Stoß sieht heikel aus, ist aber mit absolutem
    Volltreffer einfach — die volle Treffdicke schickt B 2 auf den
    Drei-Banden-Weg und nimmt B 1 zugleich die Energie (Amorti).
  DESCR
  end_position_description: "Alle drei Bälle wieder beieinander nahe " \
                            "der Ausgangsstellung: B 1 an B 3, B 2 nach " \
                            "drei Banden knapp oberhalb. B 3 nur " \
                            "wenige cm verschoben (Heft: 4-5 cm).",
  shot_parameters: {
    effect: "none",
    quantity_of_ball: 0.8,
    height_of_attack: "slightly_above_center",
    energy: nil,
    amorti_target_cm: 5
  },
  trajectory_polylines: {
    "b1" => [[0.8433, 0.8796], [0.8254, 0.9056], [0.8134, 0.9707], [0.8194, 0.8465]],
    "b2" => [[0.7817, 0.9465], [0.7824, 0.9707], [0.0147, 0.1606], [0.1070, 0.0293], [0.8408, 0.7303]],
    "b3" => [[0.8430, 0.8056], [0.8739, 0.8275]]
  }
)
shot.save!
puts "  ✓ Shot            ##{shot.id}"

# -----------------------------------------------------------------
# 10. BallCollisions + ShotEvents (v0.10)
# -----------------------------------------------------------------
#
# Die Nummern tragen die gemeinsame Zeitachse (Handoff-Reply Paul
# 2026-10-01 §3): Kollision und Ereignis sortieren sich über die Nummer
# ineinander, bei gleicher Nummer kommt die Kollision zuerst.
#   1 B1 trifft B2 · 2 B1 und B2 an der nahen langen Bande ·
#   3 B1 trifft B3 · 4/5 B2 an kurzer und ferner langer Bande
# (Reihenfolge B1 vor B2s zweiter Bande belegt durch das Caromball-Video.)

collision_seeds = [
  {
    sequence_number:   1,
    collision_type:    "primary_impact",
    ball_attacker:     "b1",
    ball_target:       "b2",
    contact_coords_normalized: { "x" => 0.8254, "y" => 0.9056 },
    quantity_of_ball:  0.8,
    speed:             2,
    effect_vertical:   0,
    effect_horizontal: 0,
    properties: {
      "caromball_raw" => {
        "effet_percent" => 0.0, "anspielhoehe_percent" => 5.0,
        "neigung_degrees" => 3.0, "geschwindigkeit_m" => 1.11,
        "hit_percent" => 80.0, "table_size" => "Size200"
      }
    },
    notes: "Sehr voller Treffer (8/10) ohne Seiteneffet. Schickt B 2 " \
           "auf den Drei-Banden-Rappel und nimmt B 1 die Energie."
  },
  {
    sequence_number:   3,
    collision_type:    "carambolage",
    ball_attacker:     "b1",
    ball_target:       "b3",
    contact_coords_normalized: { "x" => 0.8194, "y" => 0.8465 },
    scored:            true,
    notes: "B 1 erreicht B 3 mit der Restenergie und bleibt daran " \
           "liegen — der 'amorti parfait' des Titels."
  }
].freeze

event_seeds = [
  { ball_involved: "b1", sequence_number: 2, event_type: "cushion_contact",
    cushion_involved: "long_near",
    contact_coords_normalized: { "x" => 0.8134, "y" => 0.9707 },
    notes: "Der eine Bandenkontakt des Einbänders." },
  { ball_involved: "b2", sequence_number: 2, event_type: "cushion_contact",
    cushion_involved: "long_near",
    contact_coords_normalized: { "x" => 0.7824, "y" => 0.9707 },
    notes: "1. Rappel-Bande, unmittelbar nach dem Treffer." },
  { ball_involved: "b2", sequence_number: 4, event_type: "cushion_contact",
    cushion_involved: "short_left",
    contact_coords_normalized: { "x" => 0.0147, "y" => 0.1606 },
    notes: "2. Rappel-Bande." },
  { ball_involved: "b2", sequence_number: 5, event_type: "cushion_contact",
    cushion_involved: "long_far",
    contact_coords_normalized: { "x" => 0.1070, "y" => 0.0293 },
    notes: "3. Rappel-Bande; danach Rücklauf zur Gruppe." }
].freeze

# Upsert über die fachlichen Schlüssel: bestehende Zeilen (seit der
# v0.10-Datenmigration) behalten ihre IDs; was nicht mehr im Seed steht,
# wird entfernt.
collisions = collision_seeds.map do |attrs|
  c = shot.ball_collisions.find_or_initialize_by(sequence_number: attrs[:sequence_number])
  c.update!(attrs)
  c
end
shot.ball_collisions.where.not(id: collisions.map(&:id)).destroy_all

events = event_seeds.map do |attrs|
  e = shot.shot_events.find_or_initialize_by(
    ball_involved: attrs[:ball_involved], sequence_number: attrs[:sequence_number]
  )
  e.update!(attrs)
  e
end
shot.shot_events.where.not(id: events.map(&:id)).destroy_all

puts "  ✓ BallCollisions: #{shot.ball_collisions.count}, " \
     "ShotEvents: #{shot.shot_events.count}"

# -----------------------------------------------------------------
# Zusammenfassung
# -----------------------------------------------------------------

example.reload
puts "=" * 60
puts "Conti Coup 10 v0.10 end-to-end gelandet:"
puts "  Example ##{example.id} → " \
     "#{example.training_concepts.count} Concepts " \
     "(weights: #{example.training_concept_examples.pluck(:weight).sort.reverse})"
puts "  Shot    ##{shot.id} mit " \
     "#{shot.ball_collisions.count} Kollisionen, " \
     "#{shot.shot_events.count} Events"
puts "  Start/End BallConfigs: ##{start_config.id}/##{end_config.id}"
puts "  position_type=approximate, table_variant=klein (Caromball)"
puts "=" * 60
