# frozen_string_literal: true

require_relative "../ui_hex_guard"

namespace :ui do
  desc "Wache: failt bei neuen hartkodierten Farb-Hex / inline color-styles (Phase-7 Hex-Migration)"
  task :no_hardcoded_hex do
    abort("UI-Guardrail: neue Verstöße — Commit blockiert.") unless UiHexGuard.check
  end

  namespace :no_hardcoded_hex do
    desc "Ratchet-Baseline aus dem Ist-Zustand neu erzeugen (config/ui_hex_baseline.yml)"
    task :baseline do
      UiHexGuard.generate_baseline!
    end
  end
end
