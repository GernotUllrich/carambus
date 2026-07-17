# frozen_string_literal: true

# Ordnet Disziplinen den Redesign-Chip-Familien zu (Design-Token
# discipline-<familie>-{bg,fg} aus tailwind.config.js). Bewusst konservativ:
# nur die vier definierten Familien werden eingefärbt, alles Übrige (Kegel,
# Pin Billards, unbekannt) bleibt neutral — nie falsch-koloriert.
module DisciplineHelper
  # Familie => [Hintergrund-Utility, Vordergrund-Utility]
  DISCIPLINE_FAMILY_CLASSES = {
    dreiband: %w[bg-discipline-dreiband-bg text-discipline-dreiband-fg],
    snooker: %w[bg-discipline-snooker-bg text-discipline-snooker-fg],
    pool: %w[bg-discipline-pool-bg text-discipline-pool-fg],
    karambol: %w[bg-discipline-karambol-bg text-discipline-karambol-fg]
  }.freeze

  # Liefert die Chip-Familie (:dreiband/:snooker/:pool/:karambol) oder nil.
  # Klassifiziert über die Top-Disziplin (Discipline#root); Dreiband ist als
  # eigene Familie aus der Karambol-Wurzel herausgezogen.
  def discipline_family(discipline)
    return nil if discipline.blank?

    root_name = (discipline.root&.name || discipline.name).to_s
    case root_name
    when /snooker/i then :snooker
    when /pool/i then :pool
    when /karambol|carambol/i
      discipline.name.to_s.match?(/dreiband|3-?band|3-?cushion|trois bandes/i) ? :dreiband : :karambol
    end
  rescue StandardError
    nil
  end

  # Farbiger Disziplin-Chip (neutral, wenn keine Familie zutrifft).
  def discipline_chip(discipline)
    return if discipline.blank?

    bg, fg = DISCIPLINE_FAMILY_CLASSES[discipline_family(discipline)] || %w[bg-gray-100 text-gray-600]
    content_tag(:span, discipline.name,
      class: "inline-flex items-center rounded-pill px-2.5 py-0.5 text-xs font-medium #{bg} #{fg}")
  end
end
