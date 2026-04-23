# v0.9 Phase E+: Zweites End-to-End-Beispiel — Conti Coup 10.
#
# Stress-Test der v0.9-Ontologie an einer zweiten Quelle mit bewusst
# anderem Profil als Gabriëls #1:
#   - Qualitative Start- UND Endposition (kein Diagramm-Parser)
#   - Matchtisch statt Kleintisch
#   - Amorti als Lehrziel, nicht Übertragungseffet
#   - B 2 sehr voll (8/10) ohne Seiteneffet
#   - B 3 minimal verschoben (4-5 cm) = "perfekter Amorti"
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
# Configurations erkennt der SEED_MARKER im notes-Feld.
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
# Hinweis: Conti spielt auf französischem Matchtisch, aber in unserer
# aktuellen Discipline-Liste ist "Freie Partie klein" die generische
# Freie-Partie-Referenz. Falls später eine eigene "Freie Partie match"
# -Discipline kommt, wird dieser Seed entsprechend aktualisiert.
puts "  ✓ Discipline      ##{discipline.id} (#{discipline.name})"

# -----------------------------------------------------------------
# 3. BallConfiguration (Start) — qualitativ, geschätzt
# -----------------------------------------------------------------
#
# COORD-ESTIMATE: Die folgenden Koordinaten sind aus der Textbe-
# schreibung abgeleitet und MÜSSEN vor produktiver Nutzung gegen das
# Heft-Diagramm zu Coup 10 abgeglichen werden.
#
# Begründung der Schätzung:
#   - "B 1 knapp über Zentrum" → x≈0.50, y leicht gegen Ziel-Bande.
#     In der Linienserien-Konvention ist die Ziel-Bande eine lange
#     Bande; wir nehmen die "obere" lange Bande (y gegen 1.0) als
#     Zielseite an.
#   - "B 2 sehr voll (~8/10)" → B 2 muss nahe B 1 stehen und so
#     positioniert, dass ein Volltreffer in Richtung der langen Bande
#     möglich ist. Wir setzen B 2 leicht unterhalb von B 1 (Richtung
#     B 3).
#   - B 3: In Linienserie nahe Ziel-Bande, deutlich entfernt von B 1/B 2
#     (sonst wäre der 1-Banden-Weg über die Bande nicht erforderlich).

start_config = BallConfiguration.find_or_initialize_by(
  notes: "#{SEED_MARKER} Conti Coup 10 — Startstellung " \
         "(Linienserie-Nähe, Matchtisch, qualitativ geschätzt)"
)
start_config.assign_attributes(
  # COORD-ESTIMATE — siehe Block oben
  b1_x: 0.50, b1_y: 0.55,
  b2_x: 0.47, b2_y: 0.50,
  b3_x: 0.62, b3_y: 0.88,
  table_variant:  "match",
  # STRESSPUNKT §3.2 der Mapping-Analyse: gather_state hat kein
  # sauberes Semantik-Match für Linienserien. Pragmatisch auf
  # "gathering" mit Notiz; v0.10-Diskussionspunkt.
  gather_state:   "gathering",
  flow_direction: nil,
  biais_degrees:  nil,
  biais_class:    "faible",
  orientation:    "gather",
  position_type:  "qualitative"
)
start_config.save!
puts "  ✓ BallConfig      ##{start_config.id} (start, qualitative, match)"

# -----------------------------------------------------------------
# 4. BallConfiguration (Ende) — B 3 minimal verschoben
# -----------------------------------------------------------------
#
# Quell-Angabe: "B 3 verschiebt sich nur 4–5 cm".
# Matchtisch ist 2.84 m lang → 5 cm ≈ 0.018 normalisiert in x.
# B 1 und B 2 machen eine moderate Bewegung (B 1 zur Bande und
# zurück, B 2 durch Volltreffer verschoben).

end_config = BallConfiguration.find_or_initialize_by(
  notes: "#{SEED_MARKER} Conti Coup 10 — Endstellung " \
         "(B 3 +5 cm, Linienformation erhalten, qualitativ)"
)
end_config.assign_attributes(
  # COORD-ESTIMATE
  b1_x: 0.55, b1_y: 0.70,
  b2_x: 0.52, b2_y: 0.75,
  b3_x: 0.64, b3_y: 0.88,
  table_variant:  "match",
  gather_state:   "gathering",
  orientation:    "gather",
  position_type:  "qualitative"
)
end_config.save!
puts "  ✓ BallConfig      ##{end_config.id} (end, qualitative, B3 minimal)"

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
attribution.reference = "Coup 10 (Teil 1, Seite ca. 5-6 des Heftes)"
attribution.notes = "Textquelle der Annotator-Stimme: '1-Banden mit " \
                    "perfektem Amorti. B 1 knapp über Zentrum ohne " \
                    "Seiteneffet. B 2 sehr voll (~8/10). B 3 verschiebt " \
                    "sich nur 4–5 cm.' Keine Verbatim-Extraktion Conti-" \
                    "Prosa (Lizenz-Policy)."
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
    Französischer Matchtisch (2.84 × 1.42 m), Linienserien-
    Formation nahe der langen Bande. Spielball B 1 liegt knapp
    über Zentrum (etwas zur Ziel-Bande hin); Ball 2 sehr nah an
    B 1 positioniert, sodass ein 8/10-Volltreffer möglich ist.
    Ball 3 nahe der langen Ziel-Bande, deutlich entfernt von
    B 1/B 2 — 1-Banden-Weg erforderlich.

    Die Stellung ist klassische Linienserien-Anordnung: drei Bälle
    à cheval in lockerer Linie entlang der langen Bande. Exakte
    Koordinaten sind aus Quelle nicht überliefert (handge-
    zeichnetes Heft-Diagramm); die Seed-Werte sind Schätzungen
    aus der Textbeschreibung.
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
    Spielball B 1 wird ohne Seiteneffet, knapp über der Mitte der
    Queue-Höhe, mit einer Energie gespielt, die gerade für den
    1-Banden-Weg reicht und B 3 nur minimal bewegt. B 2 wird zu
    8/10 voll getroffen; durch die hohe Quantität und das fehlende
    Seiteneffet wird B 2 klar durchgestoßen und kommt in einer
    neuen, linienserien-kompatiblen Position zum Stehen. B 1 läuft
    zur langen Bande, prallt ab und erreicht B 3. Da die Energie
    bis zum B 3-Kontakt weitgehend verbraucht ist, verschiebt sich
    B 3 nur 4–5 cm — das ist der "perfekte Amorti" des Titels.

    Die drei Bälle bleiben nach dem Karambol in Linienserien-
    Reichweite: die Folgestellung ist wieder eine Linien-
    Konfiguration, die Serie kann fortgesetzt werden.

    Konzeptuell demonstriert der Stoß (a) Amorti als gezielte
    Energiekalibrierung, (b) die B 2-Wahl-Regel der Seite-1-Nota
    (der Ball näher an der Ziel-Bande ist B 2), und (c) das
    Linien-Formations-Prinzip der Einführungs-Coups.
  DESCR
  end_position_description: "Alle drei Bälle in Linienserien-" \
                            "Reichweite entlang der Ziel-Bande. " \
                            "B 3 nur 4-5 cm gegenüber Start " \
                            "verschoben (quellenexplizit). B 1 " \
                            "und B 2 haben die Bandenregion " \
                            "neu besetzt. Exakte Endkoordinaten " \
                            "nicht quellenexplizit — position_type=" \
                            "qualitative.",
  shot_parameters: {
    effect: "none",
    quantity_of_ball: 0.8,
    height_of_attack: "slightly_above_center",
    energy: nil,
    amorti_target_cm: 5
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
    notes:           "B 1 trifft B 2 sehr voll (~8/10). Ohne " \
                     "Seiteneffet keine Effet-Übertragung; B 2 " \
                     "wird geradlinig durchgestoßen und kommt in " \
                     "einer linienserien-kompatiblen Position zum " \
                     "Stehen."
  },
  {
    sequence_number: 2,
    event_type:      "cushion_contact",
    ball_involved:   "b1",
    notes:           "B 1 trifft die lange Ziel-Bande. Ohne " \
                     "Seiteneffet natürlicher Abprallwinkel. Die " \
                     "Energie ist kalibriert, dass B 1 nach dem " \
                     "Bandenkontakt gerade noch B 3 erreicht."
  },
  {
    sequence_number: 3,
    event_type:      "final_carambolage",
    ball_involved:   "b1",
    notes:           "B 1 trifft B 3 mit Rest-Energie. Durch die " \
                     "weitgehend abgegebene Energie (Bandenkontakt " \
                     "+ Weg) verschiebt sich B 3 nur 4–5 cm — " \
                     "'perfekter Amorti'. Linienserie bleibt " \
                     "spielbar."
  }
])
puts "  ✓ ShotEvents: #{shot.shot_events.count} " \
     "(initial → cushion → final)"

# -----------------------------------------------------------------
# Zusammenfassung
# -----------------------------------------------------------------

example.reload
puts "=" * 60
puts "Conti Coup 10 v0.9 end-to-end gelandet:"
puts "  Example ##{example.id} → " \
     "#{example.training_concepts.count} Concepts " \
     "(weights: #{example.training_concept_examples.pluck(:weight).sort.reverse})"
puts "  Shot    ##{shot.id} mit " \
     "#{shot.shot_events.count} Events"
puts "  Start/End BallConfigs: ##{start_config.id}/##{end_config.id}"
puts "  position_type=qualitative auf beiden Configs (Stress-Test v0.9)"
puts "=" * 60
