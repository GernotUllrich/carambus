# frozen_string_literal: true

# D-14-G4 + D-14-G5: Authority-Layer-Policy für Tournament-Sub-Operationen.
#
# Vier Predicates:
# - `assign_leiter?` — Sportwart (im Wirkbereich) kann TL für „sein" Turnier benennen
# - `update_deadline?` — TL für sein Turnier ODER Sportwart im Wirkbereich
# - `manage_teilnehmerliste?` — TL für sein Turnier ODER Sportwart im Wirkbereich
# - `enter_results?` — nur TL für sein Turnier (Sportwart darf KEINE Ergebnisse eintragen)
#
# 14-G.2 nutzt diese Policy in BaseTool-Authorization-Layer.
class TournamentPolicy < ApplicationPolicy
  def assign_leiter?
    return false if user.nil?
    user.in_sportwart_scope?(record)
  end

  def update_deadline?
    tl_or_sportwart?
  end

  def manage_teilnehmerliste?
    tl_or_sportwart?
  end

  def enter_results?
    return false if user.nil?
    record.leiter?(user)
  end

  private

  def tl_or_sportwart?
    return false if user.nil?
    record.leiter?(user) || user.in_sportwart_scope?(record)
  end
end
