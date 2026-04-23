# frozen_string_literal: true

# Administrate 0.19.0 × Rails 7.1+ Kompatibilitäts-Shim
#
# Problem:
#   Rails 7.1 hat Kernel#warn auf Klassen-Ebene als private markiert.
#   ActiveSupport::Deprecation erbt von Kernel, daher ist
#   `ActiveSupport::Deprecation.warn(...)` als Klassenmethodenaufruf
#   unter Rails 7.1+ privat und wirft NoMethodError.
#
# Betroffen:
#   Administrate 0.19.0 ruft in `app/views/fields/has_many/_show.html.erb`
#   (Zeile 21) direkt `ActiveSupport::Deprecation.warn(...)` auf. Damit
#   crasht jede Admin-Show-Seite, die ein Field::HasMany / HasOne /
#   BelongsTo rendert, mit 500.
#
# Fix (kurzfristig):
#   Sichtbarkeit der `warn`-Klassenmethode auf ActiveSupport::Deprecation
#   wieder public machen. Das wiederholt exakt das Rails-6-/7.0-Verhalten,
#   ohne die Deprecation-Semantik zu ändern (die Meldung landet weiterhin
#   im Standard-Deprecator).
#
# Langfrist-Strategie (deferred, Backlog):
#   - Administrate auf eine Release updaten, die Rails 7.1+ unterstützt
#     (Entscheidung auf Carambus-API-Scope-Ebene, siehe Handoff
#     `.paul/HANDOFF-2026-04-23-admin-views-review.md` P0).
#   - Alternativ: Administrate durch Avo / ActiveAdmin ersetzen oder
#     dedizierte Admin-Views schreiben (z.B. SVG-Partial-Pattern wie
#     `admin/shared/_ball_configuration_diagram.html.erb`).
#
# Dieser Shim ist bewusst klein und rein additiv — er entfernt nichts,
# ändert keine Deprecation-Messages und kann nach einem Administrate-
# Upgrade entfernt werden (mit einem ordentlichen Grep nach dem Namen
# dieses Files).

Rails.application.config.after_initialize do
  # Gate: nur aktiv, wenn die Methode existiert UND derzeit privat ist.
  # So wird der Shim bei zukünftigen Rails- oder Administrate-Versionen
  # automatisch zum No-Op, statt falschen Zustand zu konservieren.
  if defined?(ActiveSupport::Deprecation) &&
     ActiveSupport::Deprecation.respond_to?(:warn, true) &&
     !ActiveSupport::Deprecation.respond_to?(:warn, false)
    class << ActiveSupport::Deprecation
      public :warn
    end
  end
end
