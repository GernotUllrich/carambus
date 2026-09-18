# frozen_string_literal: true

module TrainingPackage
  # Liest den Vollbestand der globalen Trainingsdaten (IDs < MIN_ID) und baut daraus
  # ein Paket. Schreibt nichts — laeuft deshalb auch auf der Authority, wenn Datensaetze
  # zur Training Authority zurueckgeholt werden muessen.
  #
  #   TrainingPackage::Exporter.call(prune: true)
  #
  # `prune: true` haelt die Loeschabsicht der Training Authority fest: nur dann loescht
  # der Import Datensaetze, die im Ziel, aber nicht im Paket stehen.
  class Exporter < ApplicationService
    def initialize(kwargs = {})
      @prune = kwargs.fetch(:prune, false) ? true : false
    end

    def call
      refuse_unsupported_data!

      tables = TABLES.index_with { |table| rows(table) }
      {
        "manifest" => {
          "format" => FORMAT,
          "format_version" => FORMAT_VERSION,
          "created_at" => Time.current.utc.iso8601(6),
          "source" => {"basename" => Carambus.config.basename, "commit" => source_commit},
          "schema_version" => connection.select_value("SELECT max(version) FROM schema_migrations"),
          "prune" => @prune,
          "counts" => tables.transform_values(&:size),
          "skipped_local" => TABLES.index_with { |t| global_scope(t, local: true).count },
          "sha256" => TrainingPackage.digest(tables)
        },
        "tables" => tables
      }
    end

    private

    def rows(table)
      global_scope(table).order(:id).map do |record|
        record.attributes.transform_values { |v| TrainingPackage.dump_value(v) }
      end
    end

    def global_scope(table, local: false)
      scope = TrainingPackage.model_for(table).unscoped
      local ? scope.where("id >= ?", ApplicationRecord::MIN_ID) : scope.where("id < ?", ApplicationRecord::MIN_ID)
    end

    # v1 uebertraegt weder Tags noch Dateianhaenge. Statt sie still zu verlieren,
    # bricht der Export ab, sobald ein globaler Trainingsdatensatz welche traegt.
    def refuse_unsupported_data!
      names = TrainingPackage.model_names
      tagged = Tagging.where(taggable_type: names).where("taggable_id < ?", ApplicationRecord::MIN_ID).count
      raise Error, "#{tagged} Tags an Trainingsdatensaetzen — Tags uebertraegt das Paket (v1) nicht" if tagged.positive?

      attached = ActiveStorage::Attachment.where(record_type: names)
        .where("record_id < ?", ApplicationRecord::MIN_ID).count
      return unless attached.positive?

      raise Error, "#{attached} Dateianhaenge an Trainingsdatensaetzen — Anhaenge uebertraegt das Paket (v1) nicht"
    end

    def source_commit
      revision = Rails.root.join("REVISION")
      return revision.read.strip if revision.exist?

      IO.popen(["git", "-C", Rails.root.to_s, "rev-parse", "HEAD"], err: File::NULL, &:read).strip.presence
    rescue SystemCallError
      nil
    end

    def connection
      ActiveRecord::Base.connection
    end
  end
end
