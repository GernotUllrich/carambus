# frozen_string_literal: true

# Plan 20-02: Rechte an einer Liga-Begegnung (Party) und ihrem PartyMonitor.
#
# Betreiber-Vorgabe 2026-09-18: wie beim Einzelturnier. Der zustaendige Sportwart setzt einen
# Begegnungsleiter ein (UserParty); bedienen duerfen Leiter, Sportwart und Admin.
# - `assign_leiter?` — Admin ODER Sportwart im Wirkbereich (vgl. TournamentPolicy#assign_leiter?)
# - `operate?`       — dazu der Begegnungsleiter (vgl. TournamentPolicy#prepare_tournament?):
#                      PartyMonitor starten, aufstellen, Runden, Ergebnisse, Abschluss
class PartyPolicy < ApplicationPolicy
  def assign_leiter?
    return false if user.nil?

    user.admin? || user.in_sportwart_party_scope?(record)
  end

  def operate?
    return false if user.nil?

    assign_leiter? || record.leiter?(user)
  end
end
