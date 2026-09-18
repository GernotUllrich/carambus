# frozen_string_literal: true

module TrainingPackage
  # Spielt ein Trainingspaket in das Ziel ein. Standard ist der Trockenlauf; geschrieben
  # wird nur mit `apply: true`.
  #
  #   TrainingPackage::Importer.call(package: hash, role: "staging", apply: false)
  #
  # Ablauf: (1) Vorpruefung — bei jedem Fehler Abbruch, bevor irgendetwas geschrieben
  # wird. (2) Upsert je Datensatz ueber ActiveRecord, Eltern vor Kindern, gespeichert nur
  # bei echter Aenderung: auf einem API-Server entsteht so je Aenderung genau eine
  # PaperTrail-Version, ein wiederholter Import erzeugt keine. (3) Nur mit
  # `prune: true` im Manifest: Datensaetze, die im Ziel, aber nicht im Paket stehen,
  # loeschen — Kinder vor Eltern. Alles in EINER Transaktion. (4) ID-Sequenzen je Rolle.
  class Importer < ApplicationService
    Report = Struct.new(:role, :applied, :prune, :errors, :tables, :sequences, keyword_init: true) do
      def ok?
        errors.empty?
      end
    end

    # Setzt Translatable nach jeder Aenderung eines Quellfelds per update_column zurueck.
    # Der Import ist eine Kopie, kein Autorenvorgang: der Paketwert wird wiederhergestellt.
    CALLBACK_DRIVEN_COLUMNS = %w[translations_synced_at].freeze

    def initialize(kwargs = {})
      @package = kwargs.fetch(:package)
      @role = kwargs.fetch(:role).to_s
      @apply = kwargs.fetch(:apply, false) ? true : false
      @manifest = @package["manifest"] || {}
      @tables = @package["tables"] || {}
      @report = Report.new(role: @role, applied: false, prune: @manifest["prune"] == true, errors: [],
        tables: TABLES.index_with { |_| {new: 0, changed: 0, unchanged: 0, only_in_target: [], deleted: 0} },
        sequences: {})
    end

    def call
      precheck
      return @report unless @report.ok?

      @apply ? apply! : dry_run!
      @report
    end

    private

    # --- Vorpruefung ------------------------------------------------------------

    def precheck
      check_format
      return unless @report.ok? # ohne gueltiges Format sind die folgenden Pruefungen sinnlos

      check_digest
      check_role
      check_schema
      check_rows
      check_references
      check_external_references
      check_unique_keys
    end

    def error(message)
      @report.errors << message
    end

    def check_format
      error("Kein Trainingspaket (format=#{@manifest["format"].inspect})") unless @manifest["format"] == FORMAT
      unless @manifest["format_version"] == FORMAT_VERSION
        error("Paketversion #{@manifest["format_version"].inspect} wird nicht unterstützt (erwartet #{FORMAT_VERSION})")
      end
      return if @tables.keys.sort == TABLES.sort

      error("Tabellen im Paket weichen ab: #{(@tables.keys - TABLES).inspect} zu viel, #{(TABLES - @tables.keys).inspect} fehlen")
    end

    def check_digest
      return if TrainingPackage.digest(@tables) == @manifest["sha256"]

      error("Prüfsumme stimmt nicht — das Paket wurde verändert oder ist beschädigt")
    end

    # Die Rolle bestimmt die Sequenz-Behandlung und, ob Versionen entstehen. Eine
    # Verwechslung soll nicht still durchlaufen.
    def check_role
      return error("Unbekannte Rolle #{@role.inspect} (erlaubt: #{ROLES.join(", ")})") unless ROLES.include?(@role)

      local = ApplicationRecord.local_server?
      basename = Carambus.config.basename.to_s
      case @role
      when "staging"
        error("Rolle staging verlangt einen Local Server (carambus_api_url gesetzt)") unless local
      when "authority"
        if local || basename != "carambus_api"
          error("Rolle authority verlangt die Authority (API-Modus, basename carambus_api; hier: #{basename}, local_server=#{local})")
        end
      when "training_authority"
        if local || basename != "carambus_train"
          error("Rolle training_authority verlangt carambus_train im API-Modus (hier: #{basename}, local_server=#{local})")
        end
      end
    end

    def check_schema
      version = @manifest["schema_version"].to_s
      present = connection.select_value(sql(["SELECT 1 FROM schema_migrations WHERE version = ?", version]))
      return if present

      error("Schema des Ziels kennt die Paket-Migration #{version.inspect} nicht — erst deployen")
    end

    def check_rows
      @tables.each do |table, rows|
        columns = TrainingPackage.model_for(table).column_names
        ids = rows.map { |r| r["id"] }
        error("#{table}: doppelte IDs #{ids.tally.select { |_, n| n > 1 }.keys.inspect}") if ids.uniq.size != ids.size
        local = ids.compact.select { |id| id >= ApplicationRecord::MIN_ID }
        error("#{table}: lokale IDs (>= MIN_ID) im Paket: #{local.first(5).inspect}") if local.any?
        unknown = rows.flat_map(&:keys).uniq - columns
        error("#{table}: Spalten, die das Ziel nicht kennt: #{unknown.inspect}") if unknown.any?
      end
    end

    # Das Paket ist ein Vollbestand: jeder interne Verweis muss ins Paket zeigen.
    def check_references
      ids = @tables.transform_values { |rows| rows.map { |r| r["id"] }.to_set }
      REFERENCES.each do |table, refs|
        @tables.fetch(table, []).each do |row|
          refs.each do |column, target|
            value = row[column]
            next if value.nil? || ids[target].include?(value)

            error("#{table}[#{row["id"]}].#{column} = #{value} zeigt ausserhalb des Pakets (#{target})")
          end
        end
      end
      check_polymorphic(ids)
    end

    def check_polymorphic(ids)
      tables_by_model = MODELS.invert
      @tables.fetch("source_attributions", []).each do |row|
        target = tables_by_model[row["sourceable_type"]]
        next if target && ids[target].include?(row["sourceable_id"])

        error("source_attributions[#{row["id"]}]: sourceable #{row["sourceable_type"]}[#{row["sourceable_id"]}] nicht im Paket")
      end
    end

    def check_external_references
      EXTERNAL_REFERENCES.each do |table, refs|
        refs.each do |column, model_name|
          wanted = @tables.fetch(table, []).filter_map { |r| r[column] }.uniq
          missing = wanted - model_name.constantize.where(id: wanted).pluck(:id)
          error("#{table}.#{column}: #{model_name} #{missing.inspect} fehlt im Ziel") if missing.any?
        end
      end
    end

    def check_unique_keys
      UNIQUE_KEYS.each do |table, column|
        model = TrainingPackage.model_for(table)
        @tables.fetch(table, []).each do |row|
          next if row[column].nil?

          other = model.unscoped.where(column => row[column]).where.not(id: row["id"]).pick(:id)
          error("#{table}.#{column} #{row[column].inspect}: im Ziel unter ID #{other}, im Paket unter ID #{row["id"]}") if other
        end
      end
    end

    # --- Durchlauf -----------------------------------------------------------------

    def dry_run!
      # Auf oberster Ebene zusaetzlich von der Datenbank erzwungen: ein Trockenlauf kann
      # nicht schreiben. In Tests laeuft schon eine Transaktion, dort genuegt der Codepfad.
      if connection.transaction_open?
        classify_all
      else
        ActiveRecord::Base.transaction do
          connection.execute("SET TRANSACTION READ ONLY")
          classify_all
          raise ActiveRecord::Rollback
        end
      end
    end

    def classify_all
      TABLES.each { |table| each_planned(table) { |_record, _row| } }
      collect_orphans
    end

    def apply!
      ActiveRecord::Base.transaction do
        PaperTrail.request(whodunnit: "training_package:import #{@manifest["sha256"].to_s.first(12)}") do
          TABLES.each { |table| each_planned(table) { |record, row| write(record, row) } }
          collect_orphans
          prune! if @report.prune
        end
      end
    rescue ActiveRecord::ActiveRecordError, Error => e
      error("Import abgebrochen, nichts geschrieben: #{e.class}: #{e.message}")
    else
      @report.applied = true
      adjust_sequences # setval ist nicht transaktional — erst nach erfolgreichem Commit
    end

    # Ordnet jede Paketzeile ein (neu/geaendert/unveraendert) und reicht die zu
    # schreibenden an den Block weiter.
    def each_planned(table)
      model = TrainingPackage.model_for(table)
      rows = (table == "training_examples") ? parents_first(@tables[table]) : @tables[table]
      existing = model.unscoped.where(id: rows.map { |r| r["id"] }).index_by(&:id)
      counts = @report.tables[table]

      rows.each do |row|
        record = existing[row["id"]] || model.new
        new_record = record.new_record?
        record.assign_attributes(row)
        if new_record
          counts[:new] += 1
        elsif record.changed?
          counts[:changed] += 1
        else
          counts[:unchanged] += 1
          next
        end
        yield record, row
      end
    end

    def write(record, row)
      record.unprotected = true
      record.record_timestamps = false # Zeitstempel kommen aus dem Paket
      record.save!
      restore_callback_driven_columns(record, row)
    end

    def restore_callback_driven_columns(record, row)
      drift = CALLBACK_DRIVEN_COLUMNS.each_with_object({}) do |column, h|
        next unless row.key?(column)

        expected = record.class.type_for_attribute(column).cast(row[column])
        h[column] = expected unless record.class.unscoped.where(id: record.id).pick(column) == expected
      end
      record.update_columns(drift) if drift.any?
    end

    # Eltern vor Kindern innerhalb von training_examples (selbstbezueglich ueber parent_id).
    def parents_first(rows)
      by_id = rows.index_by { |r| r["id"] }
      placed = {}
      visiting = {}
      ordered = []
      visit = lambda do |row|
        return if placed[row["id"]]
        raise Error, "training_examples: Zyklus über parent_id bei ID #{row["id"]}" if visiting[row["id"]]

        visiting[row["id"]] = true
        parent = by_id[row["parent_id"]]
        visit.call(parent) if parent
        placed[row["id"]] = true
        ordered << row
      end
      rows.each { |row| visit.call(row) }
      ordered
    end

    def collect_orphans
      TABLES.each do |table|
        package_ids = @tables[table].map { |r| r["id"] }
        @report.tables[table][:only_in_target] = TrainingPackage.model_for(table).unscoped
          .where("id < ?", ApplicationRecord::MIN_ID).where.not(id: package_ids).order(:id).pluck(:id)
      end
    end

    # Kinder vor Eltern: der Sync loescht auf den Local Servers per `delete` ohne Callbacks
    # und scheitert bei falscher Reihenfolge still an der FK-Pruefung.
    def prune!
      TABLES.reverse_each do |table|
        model = TrainingPackage.model_for(table)
        records = model.unscoped.where(id: @report.tables[table][:only_in_target]).to_a
        records = children_first(records) if table == "training_examples"
        records.each do |record|
          record.unprotected = true
          record.destroy!
        end
        @report.tables[table][:deleted] = records.size
      end
    end

    def children_first(records)
      rows = records.map { |r| {"id" => r.id, "parent_id" => r.parent_id} }
      by_id = records.index_by(&:id)
      parents_first(rows).reverse.map { |row| by_id[row["id"]] }
    end

    # --- Sequenzen ------------------------------------------------------------------------

    def adjust_sequences
      return if @role == "staging" # Local Server: eigene Sequenzen ab MIN_ID, globale IDs beruehren sie nicht

      TABLES.each do |table|
        sequence = connection.select_value(sql(["SELECT pg_get_serial_sequence(?, 'id')", table]))
        current = connection.select_value("SELECT last_value FROM #{connection.quote_table_name(sequence)}").to_i
        target =
          if @role == "authority"
            [AUTHORITY_ID_BLOCK, max_id(table), current].max
          else
            # Training Authority vergibt die IDs: hinter die hoechste ID unterhalb des
            # Authority-Blocks, niemals zurueck.
            [max_id(table, below: AUTHORITY_ID_BLOCK), current].max
          end
        next if target == current

        connection.execute(sql(["SELECT setval(?, ?)", sequence, Integer(target)]))
        @report.sequences[table] = [current, target]
      end
    end

    def max_id(table, below: ApplicationRecord::MIN_ID)
      TrainingPackage.model_for(table).unscoped.where("id < ?", below).maximum(:id).to_i
    end

    def sql(statement)
      ActiveRecord::Base.sanitize_sql_array(statement)
    end

    def connection
      ActiveRecord::Base.connection
    end
  end
end
