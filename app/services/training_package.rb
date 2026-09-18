# frozen_string_literal: true

# Trainingspaket: Uebertragung globaler Trainingsvorlagen zwischen Training Authority
# (carambus_train), Staging (Local Server) und Authority (api.carambus.de).
#
# Ein Paket ist der Vollbestand aller Trainingstabellen mit IDs < MIN_ID plus Manifest.
# Das Delta berechnet der Import gegen das Ziel — dadurch ist er idempotent, und das
# Staging testet byte-gleich, was die Authority bekommt. Entwurf und Entscheidungen:
# .paul/STATE.md, "Plan Schritt 3: Promotion-Werkzeug" (2026-09-18).
module TrainingPackage
  FORMAT = "carambus-training-package"
  FORMAT_VERSION = 1

  # Eigener ID-Block der Authority fuer Trainingstabellen. Die Authority vergibt keine
  # Trainings-IDs; ein dort versehentlich angelegter Datensatz landet hier und kollidiert
  # nie mit IDs der Training Authority.
  AUTHORITY_ID_BLOCK = 49_000_000

  ROLES = %w[staging authority training_authority].freeze

  # Import-Reihenfolge: Eltern vor Kindern. Loeschen laeuft umgekehrt — der Sync loescht
  # auf den Local Servers per `delete` ohne Callbacks und scheitert bei falscher
  # Reihenfolge still an der FK-Pruefung.
  MODELS = {
    "training_sources" => "TrainingSource",
    "training_concepts" => "TrainingConcept",
    "training_examples" => "TrainingExample",
    "ball_configurations" => "BallConfiguration",
    "table_zones" => "TableZone",
    "training_concept_relations" => "TrainingConceptRelation",
    "training_concept_disciplines" => "TrainingConceptDiscipline",
    "training_concept_examples" => "TrainingConceptExample",
    "starting_positions" => "StartPosition",
    "shots" => "Shot",
    "shot_events" => "ShotEvent",
    "ball_configuration_zones" => "BallConfigurationZone",
    "source_attributions" => "SourceAttribution"
  }.freeze
  TABLES = MODELS.keys.freeze

  # Fremdschluessel innerhalb des Pakets: Spalte => Zieltabelle.
  REFERENCES = {
    "training_examples" => {"parent_id" => "training_examples"},
    "training_concept_relations" => {"source_concept_id" => "training_concepts",
                                     "target_concept_id" => "training_concepts"},
    "training_concept_disciplines" => {"training_concept_id" => "training_concepts"},
    "training_concept_examples" => {"training_concept_id" => "training_concepts",
                                    "training_example_id" => "training_examples"},
    "starting_positions" => {"training_example_id" => "training_examples",
                             "ball_configuration_id" => "ball_configurations"},
    "shots" => {"training_example_id" => "training_examples",
                "end_ball_configuration_id" => "ball_configurations"},
    "shot_events" => {"shot_id" => "shots"},
    "ball_configuration_zones" => {"ball_configuration_id" => "ball_configurations",
                                   "table_zone_id" => "table_zones"},
    "source_attributions" => {"training_source_id" => "training_sources"}
  }.freeze

  # Der einzige Verweis nach aussen: muss im Ziel existieren.
  EXTERNAL_REFERENCES = {"training_concept_disciplines" => {"discipline_id" => "Discipline"}}.freeze

  # Eindeutige fachliche Schluessel — gleicher Schluessel mit anderer ID ist ein Konflikt.
  UNIQUE_KEYS = {"training_concepts" => "key", "table_zones" => "key"}.freeze

  class Error < StandardError; end

  def self.model_for(table)
    MODELS.fetch(table).constantize
  end

  def self.model_names
    MODELS.values
  end

  # Verlustfreie Darstellung: Zeitstempel mit Mikrosekunden, sonst sieht jeder
  # zweite Import scheinbare Aenderungen.
  def self.dump_value(value)
    case value
    when ActiveSupport::TimeWithZone, Time, DateTime then value.utc.iso8601(6)
    else value
    end
  end

  def self.digest(tables)
    Digest::SHA256.hexdigest(JSON.generate(tables))
  end
end
