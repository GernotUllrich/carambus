# frozen_string_literal: true

# 09-01: Generische, spalten-getriebene Scaffold-Ansicht (Foundation v0.3). Liefert die
# anzeigbaren Attribute eines beliebigen ActiveRecords + Label/Wert-Formatierung fuer die
# generische Detail-Card (shared/_detail_card). Read-only, defensiv.
module ScaffoldHelper
  # Technische Spalten, die in der generischen Detail-Card standardmaessig NICHT gezeigt werden.
  # Bewusst NICHT dabei: source_url (haelt oft den ClubCloud-Link -> als Link zeigen).
  SCAFFOLD_HIDDEN_COLUMNS = %w[
    id created_at updated_at global_context source_id sync_date lock_version
  ].freeze

  # Geordnete Liste anzuzeigender Spaltennamen. only: ersetzt die Default-Liste, except: entfernt
  # zusaetzlich. FK-Spalten (*_id) bleiben (werden als Assoziation gerendert).
  def scaffold_show_attributes(record, only: nil, except: nil)
    cols = only.presence&.map(&:to_s) || (record.class.column_names - SCAFFOLD_HIDDEN_COLUMNS)
    cols -= Array(except).map(&:to_s)
    cols
  end

  # 11-02: Klassen-getriebene Spaltenliste fuer den generischen sortierbaren Index-Body
  # (shared/_scaffold_sortable_table, Top-Level-Modus). Wie scaffold_show_attributes, aber KLASSEN-level:
  # heavy-Typen (text/json/jsonb/binary) raus (rendern als Wall-of-Text/JSON -> nicht scanbar) + begrenzt.
  # only: ersetzt die Default-Liste (per-Modell-Override im Rollout ohne Partial-Edit), except: entfernt zusaetzlich.
  def scaffold_index_columns(model_class, only: nil, except: nil, limit: 8)
    cols = only.presence&.map(&:to_s) ||
           model_class.try(:scaffold_index_columns_default)&.map(&:to_s) ||
           (model_class.column_names - SCAFFOLD_HIDDEN_COLUMNS)
    cols -= Array(except).map(&:to_s)
    heavy = %i[text json jsonb binary]
    cols = cols.reject { |c| heavy.include?(model_class.columns_hash[c]&.type) }
    cols.first(limit)
  rescue StandardError
    []
  end

  # 09-02: Name des "fuehrenden" Attributs fuer die Zeilen-Liste (verlinkter Titel je Zeile).
  # Erstes vorhandenes aus name/title/shortname/display_name, sonst die erste String-Spalte,
  # sonst nil (das Shell faellt dann auf record.to_s zurueck).
  def scaffold_primary_attribute(record)
    %w[name title shortname display_name].each do |a|
      return a if record.respond_to?(a) && record.public_send(a).present?
    end
    scaffold_show_attributes(record).find do |a|
      record.class.columns_hash[a]&.type == :string
    end
  rescue StandardError
    nil
  end

  # Label einer Spalte: bei FK (*_id) mit belongs_to der Assoziations-Name, sonst
  # human_attribute_name (nutzt activerecord.attributes.<model>.<attr>-i18n + Humanize-Fallback).
  def scaffold_attribute_label(record, attr)
    reflection = scaffold_belongs_to_for(record, attr)
    name = reflection ? reflection.name.to_s : attr.to_s
    record.class.human_attribute_name(name)
  end

  # HTML-sicherer Wert einer Spalte fuer die Detail-Card.
  def scaffold_attribute_value(record, attr)
    value = record.public_send(attr)

    # FK -> Link auf den assoziierten Record (falls vorhanden)
    if (reflection = scaffold_belongs_to_for(record, attr))
      assoc = record.public_send(reflection.name) rescue nil
      return scaffold_blank if assoc.nil?
      label = scaffold_assoc_label(assoc)
      # STI-Subklassen (z.B. Branch < Discipline) haben keine eigene Route -> ueber die base_class
      # routen (Branch -> discipline_path), sonst faellt custom_link_to auf reinen Text zurueck.
      target = assoc.is_a?(ActiveRecord::Base) ? assoc.becomes(assoc.class.base_class) : assoc
      link = custom_link_to(label, target, class: "text-primary-600 hover:text-primary-700")
      return link.is_a?(String) ? link : label
    end

    return scaffold_blank if value.nil? || (value.respond_to?(:empty?) && value.empty?) || scaffold_zero_year_string?(value)

    case value
    when true then "✓"
    when false then "✗"
    when Hash, Array
      # serialisierte JSON-Hash-Felder (z.B. `data`) lesbar als eingeruecktes JSON statt roh {"k"=>"v"}
      pretty_json(value)
    when Time, Date, ActiveSupport::TimeWithZone
      # H2: nur das Kalenderdatum (TT.MM.JJJJ), ohne Uhrzeit/Zeitzone — to_date normalisiert
      # Datetime/TimeWithZone auf den Tag in der App-Zeitzone.
      (l(value.to_date, format: :default) rescue value.to_date.to_s rescue value.to_s)
    when Float
      # Anzeige-Rundung: Durchschnitte/Quoten (z.B. GD) auf max. 3 Nachkommastellen, ohne Float-Rauschen
      value.round(3).to_s
    else
      str = value.to_s
      if str.match?(%r{\Ahttps?://})
        link_to(truncate(str, length: 60), str, target: "_blank", rel: "noopener",
                class: "text-primary-600 hover:text-primary-700 break-all")
      else
        str
      end
    end
  rescue StandardError => e
    Rails.logger.debug { "scaffold_attribute_value(#{record.class}##{attr}): #{e.message}" }
    scaffold_blank
  end

  # H1: true, wenn dieses Attribut in der Detail-Card kein anzeigbarer Wert waere (nil-FK / nil /
  # leer / "0000"-Jahr-Platzhalter). Spiegelt die Blank-Logik von scaffold_attribute_value, damit
  # _detail_card leere Felder ueberspringen kann. Im Zweifel (Fehler) -> true (ausblenden).
  def scaffold_attribute_blank?(record, attr)
    if (reflection = scaffold_belongs_to_for(record, attr))
      (record.public_send(reflection.name) rescue nil).nil?
    else
      value = record.public_send(attr)
      value.nil? || (value.respond_to?(:empty?) && value.empty?) || scaffold_zero_year_string?(value)
    end
  rescue StandardError
    true
  end

  # H30: true, wenn dieser Record HIER editierbar ist. Auf der Authority (local_server? == false)
  # immer true; auf einem Local-Server nur fuer lokale Records (id >= MIN_ID). Globale Records
  # (id < MIN_ID) sind lokal via LocalProtector nicht editierbar -> Edit-Link ausblenden.
  # Spiegelt ApplicationRecord#disallow_saving_global_records. Im Zweifel (Fehler) -> true.
  def scaffold_editable_here?(record)
    return true unless ApplicationRecord.local_server?

    id = record.try(:id)
    id.present? && id >= ApplicationRecord::MIN_ID
  rescue StandardError
    true
  end

  # 09-03: Generisches Formularfeld — ein `.form-group`-Div mit Label + typ-passendem Token-Input.
  # `form` = FormBuilder, `attr` = Spaltenname. Read-only ausser dem Formular selbst; defensiv.
  def scaffold_form_field(form, attr)
    record = form.object
    reflection = scaffold_belongs_to_for(record, attr)
    type = record.class.columns_hash[attr.to_s]&.type

    # Boolean: Checkbox + Label inline.
    if type == :boolean && reflection.nil?
      return content_tag(:div, class: "form-group flex items-center gap-2") do
        safe_join([form.check_box(attr), form.label(attr, scaffold_attribute_label(record, attr))])
      end
    end

    input =
      if reflection
        scaffold_fk_input(form, attr, reflection)
      else
        case type
        when :text then form.text_area(attr, class: "form-control")
        when :integer then form.number_field(attr, class: "form-control")
        when :decimal, :float then form.number_field(attr, step: :any, class: "form-control")
        when :date then form.date_field(attr, class: "form-control")
        when :datetime, :timestamp then form.datetime_local_field(attr, class: "form-control")
        else form.text_field(attr, class: "form-control")
        end
      end

    content_tag(:div, class: "form-group") do
      safe_join([form.label(attr, scaffold_attribute_label(record, attr)), input])
    end
  rescue StandardError => e
    Rails.logger.debug { "scaffold_form_field(#{attr}): #{e.message}" }
    content_tag(:div, class: "form-group") do
      safe_join([form.label(attr), form.text_field(attr, class: "form-control")])
    end
  end

  private

  # FK-Eingabe: Select der assoziierten Records; bei sehr grosser Zieltabelle Fallback auf number_field.
  def scaffold_fk_input(form, attr, reflection)
    klass = reflection.klass
    if klass.count > 500
      form.number_field(attr, class: "form-control")
    else
      form.select(attr,
                  klass.all.map { |o| [scaffold_assoc_label(o), o.id] },
                  { include_blank: true },
                  class: "form-control")
    end
  rescue StandardError
    form.number_field(attr, class: "form-control")
  end

  def scaffold_blank
    content_tag(:span, "—", class: "text-gray-400 dark:text-gray-500")
  end

  # H3: "0000"-Jahr-Platzhalter (z.B. Club#founded als String "0000") wie leer behandeln.
  def scaffold_zero_year_string?(value)
    value.is_a?(String) && value.strip.match?(/\A0000\b/)
  end

  # belongs_to-Reflection, deren Fremdschluessel diese Spalte ist (oder nil).
  def scaffold_belongs_to_for(record, attr)
    return nil unless attr.to_s.end_with?("_id")

    record.class.reflect_on_all_associations(:belongs_to).find do |r|
      r.foreign_key.to_s == attr.to_s
    end
  end

  # Lesbares Label eines assoziierten Records.
  def scaffold_assoc_label(obj)
    obj.try(:name).presence || obj.try(:title).presence ||
      obj.try(:shortname).presence || obj.to_s
  end
end
