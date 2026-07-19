# frozen_string_literal: true

# Kompatibilitäts-Shim: Administrate 0.19.0 unter Rails 7.2
#
# Problem
#   Rails 7.2 hat den klassenseitigen Delegator ActiveSupport::Deprecation.warn
#   entfernt (in 7.1 deprecated). Deprecations laufen jetzt ausschließlich über
#   Instanzen (ActiveSupport::Deprecation.new bzw. Rails.application.deprecators).
#   Ein Aufruf der alten Klassen-API landet dadurch beim privaten Kernel#warn
#   und wirft:
#     NoMethodError: private method `warn' called for ActiveSupport::Deprecation:Class
#
# Auswirkung
#   Administrate 0.19.0 nutzt an sechs Stellen noch die alte Klassen-API:
#     lib/administrate.rb  -> warn_of_missing_resource_class,
#                             warn_of_deprecated_option,
#                             warn_of_deprecated_method,
#                             warn_of_deprecated_authorization_method
#     lib/administrate/field/deferred.rb#searchable_field
#     app/controllers/concerns/administrate/punditize.rb
#   Beim Rendern von has_many-Feldern auf Administrate-Show-Seiten feuert
#   Field::Associative#deprecated_option(:class_name) — ausgelöst durch
#   `Administrate::Field::HasMany.with_options(class_name: ...)` in unseren
#   Dashboards — und die Seite quittiert mit HTTP 500, z.B.
#   GET /admin/training_examples/:id.
#
# Fix
#   Administrate 0.20 löst das intern, indem es auf eine Deprecator-Instanz
#   umstellt: ActiveSupport::Deprecation.new(VERSION, "Administrate").
#   Da wir auf ~> 0.19.0 gepinnt sind, backporten wir genau diese Semantik —
#   ein öffentliches klassenseitiges #warn, das an eine Administrate-attribuierte
#   Deprecator-Instanz delegiert. Damit greifen alle sechs Call-Sites wieder,
#   und das Verhalten folgt weiterhin config.active_support.deprecation
#   (:log in development, :stderr in test, :notify in staging).
#
# Entfernen
#   Sobald administrate auf >= 0.20 angehoben wird. Der Guard deaktiviert den
#   Shim zusätzlich automatisch, falls Rails die öffentliche Klassen-API je
#   wieder bereitstellt.
unless ActiveSupport::Deprecation.respond_to?(:warn)
  ActiveSupport::Deprecation.singleton_class.class_eval do
    def warn(message = nil, callstack = nil)
      @administrate_compat_deprecator ||= begin
        horizon = defined?(Administrate::VERSION) ? Administrate::VERSION : "0.20"
        deprecator = ActiveSupport::Deprecation.new(horizon, "Administrate")
        configured_behavior = Rails.application.config.active_support.deprecation
        deprecator.behavior = configured_behavior if configured_behavior
        deprecator
      end

      @administrate_compat_deprecator.warn(message, callstack || caller_locations)
    end
  end
end
