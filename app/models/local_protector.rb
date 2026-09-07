module LocalProtector
  extend ActiveSupport::Concern

  # Modelle, die als Ganzes keiner Region angehoeren (Phase 47-02).
  #
  # Ihre Versionen tragen `global_context = true` statt einer nichtssagenden NULL.
  # **Am Sync aendert das nichts:** `Version.for_region` laesst
  # `region_id IS NULL OR region_id = ? OR global_context = TRUE` passieren — NULL und TRUE
  # sind dort gleichwertig. Der Gewinn ist diagnostisch: eine NULL bedeutet kuenftig "noch
  # nicht eingeordnet" und nicht mehr "vielleicht global, vielleicht vergessen".
  #
  # Das ist kein Widerspruch zur Phase-2-Entscheidung. Dort ging es um die abgeleitete
  # Methode `global_context?`, die fuer Turniere/Ligen/Player international blind ist und
  # deshalb nicht zur Schreibzeit-Quelle werden darf. Diese Liste leitet nichts ab, sie
  # stellt fest: `Video` haengt an einer `international_source` (UMB/Kozoom/YouTube),
  # `InternationalSource` ist per Definition international, die uebrigen sind
  # verbandsuebergreifende Stammdaten.
  GLOBALLY_SCOPED_MODELS = %w[
    Video InternationalSource TournamentPlan DisciplineCc GroupCc
  ].freeze

  # Gueltige Region-IDs fuer den Version-Stempel (Phase 47-01).
  #
  # versions.region_id hat einen Fremdschluessel auf regions; ein Stempel mit
  # unbekannter ID laesst den Version-Insert und damit die gesamte Transaktion
  # scheitern. Regionen sind wenige und aendern sich selten, deshalb memoisiert.
  # Bei einem Fehlschlag wird EINMAL neu geladen, damit frisch angelegte Regionen
  # (Scrape, Tests) sofort greifen.
  def self.known_region_id?(id)
    return false if id.blank?

    # Im Test ohne Memo: der Satz wuerde Transaktions-Rollbacks ueberleben und
    # danach IDs bejahen, die es nicht mehr gibt — eine Flakiness-Quelle, die
    # ausgerechnet als FK-Verletzung auftraete.
    return Region.exists?(id) if Rails.env.test?

    @known_region_ids ||= Region.pluck(:id).to_set
    return true if @known_region_ids.include?(id)

    @known_region_ids = Region.pluck(:id).to_set
    @known_region_ids.include?(id)
  end

  def self.reset_known_region_ids!
    @known_region_ids = nil
  end

  # Die abgeleitete Region eines Records — oder nil, wenn die Ableitung nicht traegt.
  #
  # `Region` ist ausgenommen: fuer sie liefert die Ableitung die EIGENE id
  # (region_taggable.rb, `when Region then id`). Eine so gestempelte Version erreichte
  # per `for_region` nur noch den Server dieser einen Region — heute reisen
  # Regions-Stammdaten mit region_id NULL bewusst an JEDE Instanz und legen dort
  # fehlende Records an (internationale Verbaende, region_taggable_sync_test.rb).
  # Kostet nichts: die Prod-Messung vom 2026-09-07 kennt keine einzige ungetaggte
  # Region-Version.
  #
  # Das `rescue` ist Verhaltenserhalt, nicht Bequemlichkeit: `find_associated_region_id`
  # ist gegen manche real vorkommenden Datenlagen nicht robust — im `when Game`-Zweig
  # etwa nimmt es an, `game.tournament` sei ein Tournament; bei Liga-Spielen
  # (`tournament_type == "Party"`) ist es eine Party und kennt kein `organizer_type`.
  # Das fiel nie auf, weil die Methode bis Phase 47-01 gar nicht aufgerufen wurde. Ein
  # Fehler beim Stempeln darf das Speichern des Records nicht verhindern — anders als
  # frueher wird er aber protokolliert statt verschluckt.
  def self.derived_region_id(record)
    return nil if record.is_a?(Region)
    return nil unless record.respond_to?(:find_associated_region_id)

    record.find_associated_region_id
  rescue StandardError => e
    Rails.logger.warn(
      "LocalProtector: region_id-Ableitung fuer #{record.class.name}[#{record.id}] " \
      "fehlgeschlagen (#{e.class}: #{e.message}) — Version bleibt ungetaggt"
    )
    nil
  end

  included do
    attr_accessor :unprotected

    # Configure PaperTrail - but don't ignore columns, instead skip versions when only timestamps change.
    # This ensures all columns are included in versions (needed for sync) but prevents
    # unnecessary version records during scraping operations.
    #
    # WICHTIG: Das Gate läuft über :unless (von PaperTrail#save_version? je Create/Update
    # ausgewertet), NICHT über :skip — :skip/:ignore erwarten Spaltennamen und steuern nur die
    # Serialisierung, kein bedingtes Versionieren. Ein Lambda an :skip ist wirkungslos.
    has_paper_trail(
      # ACHTUNG: Dieses Gate schluckt auch `touch` (touch aendert nur updated_at). Wer eine
      # Version ERZWINGEN will — z.B. die Redelivery haengengebliebener Records in
      # lib/tasks/region_taggings.rake — muss `record.paper_trail.save_with_version` nutzen;
      # ein blosses `touch` erzeugt hier KEINE Version.
      unless: lambda { |obj|
        # Skip creating a version if only updated_at and/or sync_date changed
        return false unless obj.saved_changes.present?

        changed_attrs = obj.saved_changes.keys.map(&:to_s)
        ignorable_attrs = ['updated_at']
        ignorable_attrs << 'sync_date' if obj.class.column_names.include?('sync_date')

        # Only skip if ALL changes are ignorable (i.e., no substantive changes)
        (changed_attrs - ignorable_attrs).empty?
      },
      # Region-Stempel der Version (Phase 47-01). PaperTrail wertet :meta in ALLEN
      # drei Events aus (events/create.rb, update.rb, destroy.rb rufen jeweils
      # merge_metadata_into) — bei destroy noch, WAEHREND der Record steht. Genau
      # daran scheiterte der fruehere after_destroy-Weg ueber latest_version.item,
      # das dort schon nil ist.
      #
      # Procs, KEINE Symbole: bei einem Symbol, das ein Attribut benennt, greift
      # metadatum_from_model_method fuer event != "create" auf den VORHERIGEN Wert
      # zurueck — und diese Tabellen haben eine Spalte region_id.
      meta: {
        # Ableitung zuerst, Spalte als Fallback: strikt additiv. Wo heute schon ein
        # Wert steht (z.B. international ueber update_all_region_id gesetzt), bleibt
        # er; nur die Luecke wird gefuellt.
        #
        # `known_region_id?` ist kein Schoenheitsfehler, sondern Pflicht: versions.region_id
        # traegt einen Fremdschluessel auf regions (schema.rb, fk_rails_82c584451e). Zeigt
        # die Ableitung auf eine nicht (mehr) existierende Region, scheitert der
        # Version-Insert — und reisst die Transaktion mit, also auch das Speichern des
        # Records selbst. Der frueher hier zustaendige Callback konnte das nicht
        # ausloesen, weil sein `rescue StandardError` solche Faelle verschluckte. Das
        # Tagging darf ein Save nie zum Scheitern bringen.
        region_id: lambda { |record|
          # Region selbst ist ausgenommen: fuer sie liefert die Ableitung die EIGENE id
          # (region_taggable.rb, `when Region then id`). Eine so gestempelte Version
          # erreichte per `for_region` nur noch den Server dieser einen Region — heute
          # reisen Regions-Stammdaten mit region_id NULL bewusst an JEDE Instanz und
          # legen dort fehlende Records an (internationale Verbaende, siehe
          # region_taggable_sync_test.rb). Fuer Region gilt weiterhin allein die Spalte.
          # Kostet nichts: in der Prod-Messung vom 2026-09-07 gibt es keine einzige
          # ungetaggte Region-Version.
          derived = LocalProtector.derived_region_id(record)
          candidate = derived || (record.has_attribute?(:region_id) ? record.region_id : nil)
          candidate if LocalProtector.known_region_id?(candidate)
        },
        # global_context kommt UNVERAENDERT aus der Spalte. global_context? ist laut
        # Phase-2-Research (2026-07-12) international-blind — es liefert fuer alle 18
        # globalen Regionen false; faktische Quelle ist der Task update_all_region_id.
        # Commit f9bdc53d guardet Derivation-Retag genau gegen diese stille Regression.
        global_context: lambda { |record|
          if LocalProtector::GLOBALLY_SCOPED_MODELS.include?(record.class.base_class.name)
            true
          elsif record.has_attribute?(:global_context)
            record.global_context
          end
        }
      }
    ) unless Carambus.config.carambus_api_url.present?
    after_save :disallow_saving_global_records
    before_destroy :disallow_saving_global_records

    # def local_server?
    #   Carambus.config.carambus_api_url.present?
    # end
    def disallow_saving_global_records
      # Skip protection in test environment
      return true if Rails.env.test?
      
      if id < 50_000_000 && ApplicationRecord.local_server? && !unprotected
        Rails.logger.warn("LocalProtector: Blocking save of global #{self.class.name}[#{id}], unprotected=#{unprotected.inspect}")
        raise ActiveRecord::Rollback
      end

      true
    end

    def disallow_saving_local_records
      raise ActiveRecord::Rollback if !ApplicationRecord.local_server? && !unprotected && !(Carambus.config.no_local_protection == 'true')

      true
    end

    def set_paper_trail_whodunnit
      return unless ::PaperTrail.request.enabled?

      ::PaperTrail.request.whodunnit = proc do
        caller.select { |c| c.starts_with? Rails.root.to_s }.join("\n")
      end
      true
    end

    def hash_diff(first, second)
      first
        .dup
        .delete_if { |k, v| second[k] == v }
        .merge!(second.dup.delete_if { |k, _v| first.key?(k) })
    end

    def last_changes(last_n = 1)
      versions.order(id: :desc).limit(last_n).reverse.map do |version|
        h = version.changeset
        h.each_key do |k|
          v = h[k]
          h[k] = v[1].is_a?(Hash) ? [hash_diff(v[0], v[1]), hash_diff(v[1], v[0])] : v
        end
        { version.id => [version.whodunnit, h] }
      end
    end
  end
end
