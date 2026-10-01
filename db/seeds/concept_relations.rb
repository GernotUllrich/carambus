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
  },

  # Conti-Tetra: parallels zwischen den vier Werkzeugen ----------------
  #
  # 'parallels' = "verwandt im pädagogischen Korpus", hier: gehört zur
  # selben Werkzeug-Familie.
  {
    source: "the_dam", target: "austauschen", relation: "parallels",
    notes: "Sperre und Austauschen sind verwandte Werkzeuge der " \
           "Conti-Tetra; Austauschen ist die strenge Linien-Spiel-" \
           "Variante mit B1-Re-Hit-Erfordernis, Sperre die " \
           "allgemeinere Form (B2/B3-Brille, Re-Hit anzustreben " \
           "aber nicht zwingend)."
  },
  {
    source: "the_dam", target: "auffangen", relation: "parallels",
    notes: "Sperre und Auffangen sind beide defensive Stellungs-" \
           "werkzeuge der Conti-Tetra; Auffangen agiert zeitlich " \
           "früher (Ball noch in Bewegung), Sperre baut die " \
           "End-Konstellation."
  },
  {
    source: "auffangen", target: "gather_shot", relation: "parallels",
    notes: "Auffangen und Holen sind beide korrektive Werkzeuge " \
           "der Conti-Tetra für Bälle, die aus der Stellung laufen; " \
           "Auffangen wirkt früher (Ball in Bewegung abfangen), " \
           "Holen später (entlaufenen Ball über Bande(n) zurück)."
  },

  # Dominanz-Verlust als Risiko der Stellungs-Werkzeuge -----------------
  {
    source: "the_dam", target: "dominanz_verlust", relation: "risk_of",
    notes: "Misslungene Sperre mündet typisch im Dominanz-Verlust " \
           "(Mapping-Doc §2.2 Rang 5): B1 läuft in den Rücken."
  },
  {
    source: "austauschen", target: "dominanz_verlust", relation: "risk_of",
    notes: "Misslungener Austausch (B2 trifft B1 nicht oder zu " \
           "schwach) → Dominanz-Verlust."
  },
  {
    source: "dominance", target: "dominanz_verlust", relation: "is_inverse_of",
    notes: "Dominanz und Dominanz-Verlust sind das positive und " \
           "negative Konzept derselben Achse."
  },

  # Austauschen wird in Linienserien angewandt -------------------------
  {
    source: "line_series", target: "austauschen", relation: "applies",
    notes: "Linienserie wendet Austauschen als Schlüsselwerkzeug " \
           "an: B2 schließt nach Bandenreise mit B1-Re-Hit auf der " \
           "Linie, B2/B3 in Brille."
  }
].freeze

# Bis 2026-09 waren diese drei Paare behelfsweise als 'parallels' kodiert
# (risk_of / is_inverse_of fehlten im Enum). Der Upsert unten schlüsselt
# auf (source, target, relation) und würde neben den alten Zeilen neue
# anlegen. Deshalb vorher die alten Zeilen umkodieren: so behalten sie
# ihre IDs (< 50M = globales Trainingswissen, siehe ID-Regime) und der
# Sync bekommt eine Änderung statt Löschen + Neuanlage.
RELATION_RECODES = {
  %w[the_dam dominanz_verlust]     => "risk_of",
  %w[austauschen dominanz_verlust] => "risk_of",
  %w[dominance dominanz_verlust]   => "is_inverse_of"
}.freeze

RELATION_RECODES.each do |(source, target), relation|
  TrainingConceptRelation.find_by(
    source_concept: concept(source),
    target_concept: concept(target),
    relation:       "parallels"
  )&.update!(relation: relation)
end

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
