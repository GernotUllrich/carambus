class AddRiskOfAndIsInverseOfToTrainingConceptRelations < ActiveRecord::Migration[7.2]
  # Erweitert das Relations-Vokabular um risk_of und is_inverse_of.
  #
  # Bisher mussten vier semantisch verschiedene Beziehungen als parallels
  # kodiert werden (dokumentiert als Notbehelf in db/seeds/concept_relations.rb):
  #
  #   austauschen --> dominanz_verlust   misslungener Austausch riskiert den
  #   the_dam     --> dominanz_verlust   Verlust der Dominante   → risk_of
  #   dominance   --> dominanz_verlust   positives/negatives Konzept derselben
  #                                      Achse                   → is_inverse_of
  #
  # Vorgesehen im Handoff 2026-05-12 (§Out-of-Scope), bestätigt 2026-07-19/20.
  #
  # Der Check-Constraint muss dafür ersetzt werden. Auf einer Tabelle mit
  # zweistelliger Zeilenzahl ist die Validierung im selben Schritt unkritisch,
  # deshalb safety_assured statt add/validate in zwei Migrationen.

  CONSTRAINT = "training_concept_relations_relation_check".freeze
  OLD = "relation IN ('teaches','applies','exemplifies','specializes','parallels')".freeze
  NEW = "relation IN ('teaches','applies','exemplifies','specializes','parallels'," \
        "'risk_of','is_inverse_of')".freeze

  def up
    safety_assured do
      remove_check_constraint :training_concept_relations, name: CONSTRAINT
      add_check_constraint :training_concept_relations, NEW, name: CONSTRAINT
    end
  end

  def down
    # Rückwärts nur möglich, solange keine Zeile die neuen Werte nutzt.
    offending = TrainingConceptRelation.where(relation: %w[risk_of is_inverse_of]).count
    if offending.positive?
      raise ActiveRecord::IrreversibleMigration,
        "#{offending} Relation(en) nutzen risk_of/is_inverse_of — erst umkodieren."
    end

    safety_assured do
      remove_check_constraint :training_concept_relations, name: CONSTRAINT
      add_check_constraint :training_concept_relations, OLD, name: CONSTRAINT
    end
  end
end
