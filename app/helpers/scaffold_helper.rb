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
      return custom_link_to(scaffold_assoc_label(assoc), assoc,
                            class: "text-primary-600 hover:text-primary-700")
    end

    return scaffold_blank if value.nil? || (value.respond_to?(:empty?) && value.empty?)

    case value
    when true then "✓"
    when false then "✗"
    when Time, Date, ActiveSupport::TimeWithZone
      (l(value, format: :short) rescue value.to_s)
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

  private

  def scaffold_blank
    content_tag(:span, "—", class: "text-gray-400 dark:text-gray-500")
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
