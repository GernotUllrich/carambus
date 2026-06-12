# frozen_string_literal: true

# v1.0 Phase 34-01: Persona-/Capability-Ableitung.
#
# Leitet aus bereits vorhandenen Bausteinen — role-Enum, Sportwart-Wirkbereich
# (SportwartLocation/SportwartDiscipline-Joins) und Tournament.turnier_leiter_user_id —
# die abgeleiteten Personas eines Users ab und das daraus folgende CC-Schreibrecht.
#
# KEIN neues Rollensystem, KEINE neuen Spalten: reine Ableitung. SportwartScope
# (in_sportwart_scope?) bleibt fuer die turnierspezifische Scope-Pruefung zustaendig;
# dieser Concern beantwortet die Frage "welche Persona ist dieser User?".
#
# CC-Schreibrecht (cc_write_access?) = system_admin ODER Sportwart ODER Turnierleiter
# (D-34-1, User-Entscheidung v1.0). club_admin und reiner player sind NICHT
# schreibberechtigt (im Chat read-only).
module UserPersonas
  extend ActiveSupport::Concern

  # True wenn der User einen Sportwart-Wirkbereich gepflegt hat (mind. eine Location
  # ODER mind. eine Disziplin). Identische Datenbasis wie SportwartScope.
  def sportwart?
    sportwart_location_ids.any? || sportwart_discipline_ids.any?
  end

  # True wenn der User turnier_leiter mindestens eines Tournaments ist.
  # Guard gegen id=nil (unsaved User): sonst matcht exists?(turnier_leiter_user_id: nil)
  # alle Tournaments OHNE Turnierleiter und liefert faelschlich true.
  def turnierleiter?
    return @is_turnierleiter if defined?(@is_turnierleiter)
    @is_turnierleiter = id.present? && Tournament.exists?(turnier_leiter_user_id: id)
  end

  # Abgeleitete Personas als Symbol-Array: Basis-Rolle aus dem enum plus
  # :sportwart / :turnierleiter, wenn zutreffend. Stabil, duplikatfrei.
  def personas
    list = [role.to_sym]
    list << :sportwart if sportwart?
    list << :turnierleiter if turnierleiter?
    list.uniq
  end

  # CC-Schreibrecht: Sportwart + Turnierleiter + system_admin (D-34-1).
  # club_admin/player ohne Sportwart-Scope und ohne Turnier-Leitung => false.
  def cc_write_access?
    system_admin? || sportwart? || turnierleiter?
  end
end
