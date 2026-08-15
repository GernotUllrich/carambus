# frozen_string_literal: true

# Fail-silent-Wächter für Scrape-Listen (Befund 2026-07-21, SBV-Clubs): die Change-Gate-Zähler
# (deep/skipped_unchanged) werden PRO Listeneintrag hochgezählt — eine LEERE Liste ist damit von
# "alles unverändert" nicht unterscheidbar und lief bisher stumm durch (`deep=0 skipped_unchanged=0`).
# Dieser Guard schlägt an, wenn eine Liste 0 Einträge liefert, obwohl in der DB bereits Einträge
# stehen (> 0 also erwartbar waren). Reines Log-Signal — kein Einfluss auf den Scrape-Ablauf.
module ScrapeListGuard
  module_function

  # true, wenn gewarnt wurde (leere Liste trotz Erwartung), sonst false.
  def warn_if_empty(label, scraped_count, expected_count)
    return false unless scraped_count.to_i.zero? && expected_count.to_i.positive?

    Rails.logger.warn "===== scrape ===== LEERE LISTE #{label}: 0 Einträge gescrapet, " \
                      "#{expected_count} in der DB — Quelle vermutlich defekt (fail-silent-Verdacht)"
    true
  end
end
