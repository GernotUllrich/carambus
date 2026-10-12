# frozen_string_literal: true

require "test_helper"

# Sync-Vertrag der Trainingsmodelle (Staging-Pipeline, 2026-09-18).
#
# Trainingsvorlagen entstehen global (id < 50 Mio.) und erreichen die Local Servers
# nur ueber PaperTrail-Versionen der Authority. Jedes Trainingsmodell braucht dafuer
# zwei Dinge, beide aus LocalProtector:
#   1. has_paper_trail — ohne Version hat der Sync nichts zu verteilen.
#   2. das Attribut `unprotected` — Version.update_from_carambus_api legt fehlende
#      Records mit `create(args.merge(unprotected: true))` an und scheitert ohne es.
#
# Bis 2026-09-18 fehlte LocalProtector sechs Modellen, darunter den Relations und den
# Concept↔Beispiel-Gewichten — dem Kern der Ontologie.
class TrainingSyncTest < ActiveSupport::TestCase
  TRAINING_MODELS = [
    TrainingConcept, TrainingConceptRelation, TrainingConceptExample, TrainingConceptDiscipline,
    TrainingExample, TrainingSource, SourceAttribution,
    Shot, ShotEvent, StartPosition,
    BallConfiguration, BallConfigurationZone, TableZone
  ].freeze

  # Die sechs, die bis 2026-09-18 nicht synchronisiert wurden.
  NEWLY_SYNCED = [
    TrainingConceptRelation, TrainingConceptExample, ShotEvent,
    BallConfiguration, BallConfigurationZone, TableZone
  ].freeze

  test "every training model includes LocalProtector" do
    missing = TRAINING_MODELS.reject { |m| m.include?(LocalProtector) }
    assert_empty missing.map(&:name), "ohne LocalProtector erreicht das Modell keinen Local Server"
  end

  test "every training model accepts the unprotected attribute the sync sets on create" do
    rejected = TRAINING_MODELS.reject do |model|
      model.new(unprotected: true)
      true
    rescue ActiveModel::UnknownAttributeError
      false
    end
    assert_empty rejected.map(&:name), "der Sync-create-Zweig scheiterte hier mit UnknownAttributeError"
  end

  # Der Sync hat zwei Haelften auf zwei Servern. Sie werden getrennt geprueft, weil die
  # Testumgebung eines Checkouts nur EINE davon abbildet: PaperTrail ist per LocalProtector
  # nur aktiv, wenn carambus_api_url leer ist (API-Server). In carambus_train erbt `test`
  # die Authority-URL aus dem default-Block und laeuft deshalb als Local Server.
  NEWLY_SYNCED.each do |model|
    # Sendeseite (Authority): jeder neue Record hinterlaesst eine create-Version.
    test "#{model.name} writes a create version on the authority" do
      skip_unless_api_server

      record = build_record(model)
      version = record.versions.last
      assert_equal "create", version&.event, "#{model.name}: keine create-Version"
      assert_equal record.id, sync_args(version.object_changes)["id"]
    end

    # Empfangsseite (Local Server): der create-Zweig von Version.update_from_carambus_api
    # stellt den Record aus den uebertragenen Werten identisch wieder her.
    test "#{model.name} is recreated by the sync create path" do
      original = build_record(model)
      # So sieht object_changes einer create-Version aus: jedes Attribut von nil auf seinen Wert.
      object_changes = original.attributes.transform_values { |v| [nil, v] }.to_yaml
      args = sync_args(object_changes)

      # Auf dem empfangenden Server gibt es den Record noch nicht.
      model.where(id: original.id).delete_all

      recreated = model.create(args.merge(unprotected: true))
      assert recreated.persisted?, "#{model.name}: #{recreated.errors.full_messages.inspect}"
      assert_equal original.attributes, recreated.reload.attributes
    end
  end

  private

  # Wie Version.update_from_carambus_api (create-Zweig): je Attribut der neue Wert.
  def sync_args(object_changes)
    YAML.load(object_changes).to_a.map { |v| [v[0], v[1][1]] }.to_h
  end

  def build_record(model)
    case model.name
    when "TrainingConceptRelation"
      TrainingConceptRelation.create!(source_concept: concept("sync_a"), target_concept: concept("sync_b"),
        relation: "risk_of")
    when "TrainingConceptExample"
      TrainingConceptExample.create!(training_concept: concept("sync_a"), training_example: example, weight: 4)
    when "ShotEvent"
      shot.shot_events.create!(sequence_number: 1, event_type: "sperre", ball_involved: "b2")
    when "BallConfiguration"
      ball_configuration
    when "BallConfigurationZone"
      BallConfigurationZone.create!(ball_configuration: ball_configuration, table_zone: table_zone,
        which_ball: "b2", role: "target")
    when "TableZone"
      table_zone
    end
  end

  def concept(key)
    TrainingConcept.find_by(key: key) || TrainingConcept.create!(title: key.humanize, axis: "conception", key: key)
  end

  def example
    @example ||= TrainingExample.create!(title: "Sync-Beispiel")
  end

  def shot
    @shot ||= example.shots.create!(shot_type: "ideal", sequence_number: 1, title: "Sync-Stoss",
      source_language: "de")
  end

  def ball_configuration
    @ball_configuration ||= BallConfiguration.create!(
      b1_x: 0.2, b1_y: 0.5, b2_x: 0.5, b2_y: 0.5, b3_x: 0.8, b3_y: 0.3,
      table_variant: "match", gather_state: "pre_gather", position_type: "exact"
    )
  end

  def table_zone
    @table_zone ||= TableZone.create!(key: "sync_zone", label: "Sync-Zone", zone_type: "custom")
  end
end
