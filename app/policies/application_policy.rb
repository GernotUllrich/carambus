# frozen_string_literal: true

# Standard-Pundit-Skeleton. Subclasses überschreiben die Predicates.
# Plan 14-G.1 — First-Time Pundit-Integration in Carambus.
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NotImplementedError, "You must define #resolve in #{self.class}"
    end
  end
end
