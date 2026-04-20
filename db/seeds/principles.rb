# v0.8 Tier 2 seed: seven foundational principles distilled from Gretillat
# (book 1 Part 2 Conception), Weingartner, and domain insights captured
# during the ontology scoping (Memory #91 / #92, 2026-04-20).
#
# Principle categories:
#   - measurable_dimension: quantifiable shot-level scores
#   - strategic_maxim: high-level gameplay heuristics
#   - phenomenological: observed patterns that defy the naive reading

puts "Creating principles..."

PRINCIPLES_SEED = [
  {
    key: "dominance",
    label: "Dominanz",
    principle_type: "measurable_dimension",
    description: "Grad, in dem der Spielball im Zielkontakt die Bewegung " \
                 "dominiert. Primäres Kriterium ist flow_direction " \
                 "(centrifugal = weg von B2, centripetal = zu B2 hin).",
    gretillat_ref: "book 1, Part 2 Conception",
    importance_order: 1
  },
  {
    key: "margin_of_error",
    label: "Fehler-Toleranz",
    principle_type: "measurable_dimension",
    description: "Spielraum zwischen gerade-noch-Karambol und klarem " \
                 "Treffer. Grundlage von Gretillats Sicherheitskalkül.",
    gretillat_ref: "book 1, Part 2 Conception",
    importance_order: 2
  },
  {
    key: "risk_factor",
    label: "Risiko-Faktor",
    principle_type: "measurable_dimension",
    description: "Gesamtrisiko einer Stoßwahl — kombiniert margin_of_error " \
                 "mit den Konsequenzen der Folge-Stellung.",
    importance_order: 3
  },
  {
    key: "the_dam",
    label: "Der Damm",
    principle_type: "strategic_maxim",
    description: "Gretillats Reserve-Sicherheitsmarge: lieber einen Punkt " \
                 "liegen lassen als die aufgebaute Position aufgeben.",
    gretillat_ref: "book 1, Part 2 Conception",
    importance_order: 4
  },
  {
    key: "security_primacy",
    label: "Sicherungs-Primat",
    principle_type: "strategic_maxim",
    description: "Sicherung der Folge-Position hat Vorrang vor maximaler " \
                 "Punkteffizienz eines Einzelstoßes.",
    importance_order: 5
  },
  {
    key: "follow_over_point",
    label: "Folge über Punkt",
    principle_type: "strategic_maxim",
    description: "Wenn Folge und Punkt konkurrieren, gewinnt die Folge — " \
                 "ein gut gestellter nächster Stoß ist mehr wert als ein " \
                 "riskanter Punkt heute.",
    importance_order: 6
  },
  {
    key: "mystery_of_close_balls",
    label: "Mysterium der nahen Bälle",
    principle_type: "phenomenological",
    description: "Eng zusammenliegende Bälle sind häufig schwerer zu " \
                 "verwerten als offene Stellungen — gegen die Intuition " \
                 "des Anfängers.",
    importance_order: 7
  }
].freeze

PRINCIPLES_SEED.each do |attrs|
  p = Principle.find_or_initialize_by(key: attrs[:key])
  p.assign_attributes(attrs)
  p.save!
  puts "  ✓ #{p.key.ljust(24)} (#{p.principle_type})"
end

puts "\nPrinciples seeding completed. Total: #{Principle.count}"
