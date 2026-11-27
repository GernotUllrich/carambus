# frozen_string_literal: true

module ClubsHelper
  # Link auf die öffentliche CC-Vereinsseite. Die alte GET-Seite `verein-details.php` liefert seit 11/2026
  # HTTP 410; die neue `cbdet.php` nimmt nur POST an (GET mit Parametern → 400). Darum ein Formular-Knopf
  # mit denselben Feldern wie der Scrape-Client — ohne authenticity_token, das Formular geht an eine fremde Domain.
  def cc_club_page_button(label, base_url:, fed_id:, cc_id:)
    return if base_url.blank? || fed_id.blank? || cc_id.blank?

    base = base_url.to_s.end_with?("/") ? base_url.to_s : "#{base_url}/"
    fields = ClubCloudPublicClient.form_fields(fed_id, a: cc_id).map { |name, value| hidden_field_tag(name, value, id: nil) }
    button = tag.button(label, type: "submit", class: "green_link cursor-pointer p-0 border-0 hover:underline")
    tag.form(action: "#{base}cbdet.php", method: "post", target: "_blank", rel: "noopener", class: "inline") do
      safe_join(fields + [button])
    end
  end
end
