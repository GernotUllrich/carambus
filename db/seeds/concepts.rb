# v0.9 Phase E: Konsolidierter Seed für den Concept-Katalog.
#
# Ersetzt den früheren db/seeds/principles.rb (Phase A hat principles
# als Entity gelöscht, Phase B hat training_concepts um kind/key/refs
# erweitert). Seed erstellt neun Concepts:
#
#   8 ex-Principles (kind ∈ {strategic_maxim, measurable_dimension,
#                            phenomenological}) aus Gretillat, Weingartner,
#                            Conti und Gernots Domain-Einsichten.
#   1 Topic-Concept "gather_shot" (Versammlungsstoß), das als primäres
#     Konzept für die Gabriëls-Beispiele dient.
#
# Idempotent: find_or_initialize_by(key:). Alle Concepts haben keys,
# weil Phase B den partial unique index auf key genau dafür bereitstellt.
#
# Run: bin/rails runner db/seeds/concepts.rb

puts "Seed: Concepts (v0.9 Phase E)"
puts "=" * 60

CONCEPTS_SEED = [
  # --- Measurable dimensions (skalare Mess-Konzepte) -----------------

  {
    key: "dominance",
    title: "Dominanz",
    kind: "measurable_dimension",
    axis: "conception",
    short_description: "Grad, in dem der Spielball im Zielkontakt die " \
                       "Bewegung dominiert.",
    full_description: "Primäres Kriterium ist flow_direction " \
                      "(centrifugal = weg von B2, centripetal = zu B2 " \
                      "hin). Gernots zentrifugale Affordanz (2026-04-19) " \
                      "macht das operational: B1 wird nach AUSSEN gezogen, " \
                      "eröffnet leichteren Weg zu Ecke/Bande, statt langer " \
                      "Holer-Stöße mit unsicherem Ausgang.",
    gretillat_ref: "book 1 Part 2 Conception, S. 285",
    importance_order: 1
  },
  {
    key: "margin_of_error",
    title: "Fehler-Toleranz",
    kind: "measurable_dimension",
    axis: "conception",
    short_description: "Spielraum zwischen gerade-noch-Karambol und " \
                       "klarem Treffer.",
    full_description: "Grundlage von Gretillats Sicherheitskalkül. Ein " \
                      "Stoß mit größerem margin_of_error ist robuster gegen " \
                      "kleine Ausführungsfehler.",
    gretillat_ref: "book 1 Part 2 Conception, S. 296",
    importance_order: 2
  },
  {
    key: "risk_factor",
    title: "Risiko-Faktor",
    kind: "measurable_dimension",
    axis: "conception",
    short_description: "Gesamtrisiko einer Stoßwahl.",
    full_description: "Kombiniert margin_of_error mit den Konsequenzen " \
                      "der Folge-Stellung. Ein Stoß mit kleinem " \
                      "margin_of_error ist nur dann vertretbar, wenn das " \
                      "Risiko der Folgestellung klein ist (oder umgekehrt).",
    gretillat_ref: "book 1 Part 2 Conception, S. 305",
    importance_order: 3
  },

  # --- Strategic maxims (normative Lehrsätze) ------------------------

  {
    key: "the_dam",
    title: "Der Damm",
    kind: "strategic_maxim",
    axis: "conception",
    short_description: "Reserve-Sicherheitsmarge.",
    full_description: "Gretillats Sicherheitsreserve: lieber einen Punkt " \
                      "liegen lassen als die aufgebaute Position aufgeben. " \
                      "'Le barrage' — defensive Grenze, die nicht " \
                      "überschritten wird, auch wenn der direkte Punkt " \
                      "lockt.",
    gretillat_ref: "book 1 Part 2 Conception, S. 282",
    importance_order: 4
  },
  {
    key: "security_primacy",
    title: "Sicherungs-Primat",
    kind: "strategic_maxim",
    axis: "conception",
    short_description: "Sicherung der Folge-Position vor Einzelpunkt-" \
                       "Effizienz.",
    full_description: "Die Sicherung der Folge-Position hat Vorrang vor " \
                      "maximaler Punkteffizienz eines Einzelstoßes. Typi" \
                      "scher Fehler von Anfängern: riskanter Direkt-Punkt " \
                      "statt solider Folgestellung.",
    importance_order: 5
  },
  {
    key: "follow_over_point",
    title: "Folge über Punkt",
    kind: "strategic_maxim",
    axis: "conception",
    short_description: "Wenn Folge und Punkt konkurrieren, gewinnt die " \
                       "Folge.",
    full_description: "Ein gut gestellter nächster Stoß ist mehr wert als " \
                      "ein riskanter Punkt heute. Dies ist die operative " \
                      "Konsequenz aus security_primacy: wenn beide " \
                      "gleichzeitig nicht erreichbar sind, gewinnt die " \
                      "Folgestellung.",
    importance_order: 6
  },

  # --- Phenomenological (beobachtete Muster / Mechanismen) -----------

  {
    key: "mystery_of_close_balls",
    title: "Mysterium der nahen Bälle",
    kind: "phenomenological",
    axis: "technique",
    short_description: "Enge Ballstellungen sind oft schwerer als offene.",
    full_description: "Eng zusammenliegende Bälle sind häufig schwerer " \
                      "zu verwerten als offene Stellungen — gegen die " \
                      "Intuition des Anfängers. Conti: 'le mystère des " \
                      "billes de près'.",
    importance_order: 7
  },
  {
    key: "transferred_effect",
    title: "Übertragungseffet (Zahnrad-Analogie)",
    kind: "phenomenological",
    axis: "technique",
    short_description: "Effet überträgt sich beim Kontakt gegenläufig " \
                       "auf Ball 2.",
    full_description: "Der am Spielball angebrachte Effet überträgt " \
                      "sich beim Kontakt mit Ball 2 in GEGENLÄUFIGER " \
                      "Richtung — wie bei zwei ineinandergreifenden " \
                      "Zahnrädern. Linker Effet am B1 erzeugt rechts" \
                      "drehenden B2 nach dem Kontakt, und umgekehrt. " \
                      "Fundamentales Anfänger-Lernziel: ohne " \
                      "Verständnis des Übertragungseffets ist kontrol" \
                      "lierte B2-Wegsteuerung unmöglich. Gabriëls' " \
                      "Stoß 1 demonstriert es als Einstieg.",
    importance_order: 8
  },

  # --- Topic (Themen-Konzepte, die Beispiele bündeln) ----------------

  {
    key: "gather_shot",
    title: "Versammlungsstoß",
    kind: "topic",
    axis: "conception",
    short_description: "Stoß, der alle drei Bälle auf kleiner Fläche " \
                       "sammelt.",
    full_description: "Zentrales Strategie-Konzept des Großen Spiels " \
                      "(Libre): der Versammlungsstoß (nl. verzamelstoot, " \
                      "fr. rappel) bringt alle drei Bälle auf eine " \
                      "möglichst kleine Fläche — pädagogische Referenz " \
                      "ist DIN-A4-Größe — damit der Folgestoß einfach " \
                      "wird. Die Versammlungszone nach Rohner: 1/32 der " \
                      "Spielfläche (diamant-beschränktes Feld um Ball 3). " \
                      "Ist das primäre Stoß-Thema bei Gabriëls, Gretillat " \
                      "und Weingartner; gegen die 3-Cushion-Orientierung, " \
                      "wo verteilte Stellungen bevorzugt werden.",
    gretillat_ref: "book 1 Part 2 Conception, S. 182-271 (Gather shot grid)",
    weingartner_ref: "Pflichtstoßprogramm, Versammlungszone p. 59",
    importance_order: 9
  }
].freeze

CONCEPTS_SEED.each do |attrs|
  c = TrainingConcept.find_or_initialize_by(key: attrs[:key])
  c.assign_attributes(attrs)
  c.save!
  puts "  ✓ #{c.key.ljust(24)} (#{c.kind}, axis=#{c.axis})"
end

puts "=" * 60
puts "Concepts seeding completed. Total mit key: " \
     "#{TrainingConcept.where.not(key: nil).count}"
