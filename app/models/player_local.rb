# frozen_string_literal: true

# Lokale Kontaktdaten zu einem Spieler — Adresse und Einwilligung in die Vereinskommunikation.
#
# ⚠️ Diese Daten verlassen den lokalen Server NICHT. `players` ist global und wird von der
# Authority gesynct; eine Adresse dort waere auf allen Servern sichtbar. Deshalb eine eigene
# Tabelle mit `ApiProtector`: auf der Authority rollt dessen after_save-Guard jedes Schreiben
# zurueck (api_protector.rb), und der Sync selbst ist ein reiner Pull von dort — es gibt keinen
# Pfad, auf dem diese Zeilen nach oben wandern.
#
# Vorbild: `TableLocal` (ortsgebundene Tischkonfiguration, gleiches Muster).
class PlayerLocal < ApplicationRecord
  belongs_to :player

  # ⚠️ BEWUSST OHNE `ApiProtector`, anders als `TableLocal` — aus zwei Gruenden:
  #
  # 1. Dessen Guard entscheidet ueber die ID (`id > Seeding::MIN_ID`, api_protector.rb:36). Das
  #    passt fuer Tabellen, die BEIDE Arten von Records tragen. Diese hier traegt ausschliesslich
  #    lokale — und der ID-Weg ist zerbrechlich: der Startwert der Sequence steht nicht in
  #    `schema.rb`, ein `db:schema:load` setzt sie auf 1 zurueck und der Schutz laeuft ins Leere
  #    (real beobachtet: der erste Datensatz bekam id=15). Hier entscheidet deshalb allein die
  #    Rolle des Servers.
  # 2. `ApiProtector` schaltet auf lokalen Servern `has_paper_trail` ein. Eine geloeschte
  #    Adresse bliebe dann in `versions` erhalten — bei personenbezogenen Daten ist das keine
  #    Versionierung, sondern ein Loeschen, das nicht loescht.
  before_save :nur_auf_lokalem_server

  # Der Grund fuer diese Tabelle: die Adressen sollen die Authority nie erreichen. Hier wird das
  # durchgesetzt, statt sich darauf zu verlassen, dass niemand dort schreibt.
  def nur_auf_lokalem_server
    return true if ApplicationRecord.local_server?

    errors.add(:base, I18n.t("player_local.authority_write_denied",
      default: "Kontaktdaten werden nur lokal gefuehrt und koennen auf dem zentralen Server nicht angelegt werden."))
    throw :abort
  end
  private :nur_auf_lokalem_server

  # Gegenstueck zum Unique-Index: macht den Konflikt in der Oberflaeche als Fehlermeldung
  # sichtbar statt als 500.
  validates :player_id, uniqueness: true

  # Ein leeres Formularfeld liefert "", nicht nil. Ohne Normalisierung liesse sich eine einmal
  # eingetragene Adresse nicht wieder loeschen (die Formatpruefung unten wuerde "" verwerfen),
  # und "Max@Example.COM" und "max@example.com" waeren zwei verschiedene Adressen.
  normalizes :email, with: ->(value) { value.to_s.strip.downcase.presence }

  # Bewusst eine schlichte Pruefung: sie faengt Tippfehler wie fehlendes @ ab, ohne zu
  # behaupten, die Adresse existiere. Ob sie zustellbar ist, zeigt erst der Versand.
  validates :email, format: {with: /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/}, allow_nil: true

  # Anschreibbar ist nur, wer eine Adresse hat, zugestimmt hat und nicht widerrufen hat.
  # ⚠️ Diese Bedingung ist die EINZIGE Stelle, an der ueber Anschreibbarkeit entschieden wird —
  # wer eine Empfaengerliste baut, nutzt sie, statt die drei Felder erneut zu pruefen.
  scope :contactable, lambda {
    where.not(email: nil).where.not(consent_given_at: nil).where(consent_revoked_at: nil)
  }

  # Die Spieler, die im Admin-Formular zur Auswahl stehen: die Mitglieder des konfigurierten
  # Clubs in der laufenden Saison.
  #
  # ⚠️ Ohne diese Einschraenkung waere das Formular unbenutzbar — Administrate rendert
  # `Field::BelongsTo` als `<select>` mit ALLEN Records, und `players` hat 47.716 Zeilen.
  #
  # Ist kein Club konfiguriert (Authority, `Carambus.config.club_id` leer), bleibt die Auswahl
  # leer: dort gibt es keine Clubmitglieder zu pflegen, und dort duerfen diese Daten auch gar
  # nicht entstehen (siehe `nur_auf_lokalem_server`).
  #
  # ⚠️ Ausgeschlossen werden GAESTE, nicht "alles ausser aktiv":
  # `SeasonParticipation.status = "guest"` sind fluechtige Datensaetze —
  # `Player.remove_inactive_guests` loescht sie nach zwei Wochen ohne Spiel (player.rb), und
  # mit ihnen verschwaende die Adresse. Passive Mitglieder zaehlen mit (dauerhaft, Konvention
  # aus Plan 02-04), ebenso Teilnahmen OHNE gesetzten Status — der ist ein freies Feld ohne
  # Validierung und in den Daten oft leer; sie deshalb auszuschliessen waere willkuerlich.
  #
  # `IS DISTINCT FROM` statt `!=`: in SQL ist `NULL != 'guest'` nicht wahr, sondern NULL —
  # ein schlichtes `where.not` liesse also genau die statuslosen Teilnahmen herausfallen.
  EXCLUDED_STATUS = "guest"

  def self.selectable_players
    club_id = Carambus.config.club_id
    return Player.none if club_id.blank?

    # ⚠️ Subquery statt `joins(...).distinct`: mit DISTINCT verlangt PostgreSQL, dass der
    # ORDER-BY-Ausdruck in der Select-Liste steht — `Player.sort_key_sql` ist ein
    # `regexp_replace(...)` und tut das nicht. Ein `joins` ohne `distinct` wiederum lieferte
    # Spieler mehrfach, wenn sie mehrere Teilnahmen im selben Club fuehren.
    mitglieder = SeasonParticipation
      .where(club_id: club_id, season_id: Season.current_season&.id)
      .where("season_participations.status IS DISTINCT FROM ?", EXCLUDED_STATUS)
      .select(:player_id)

    Player.where(id: mitglieder).order(Player.sort_key_sql)
  end

  def contactable?
    email.present? && consent_given_at.present? && consent_revoked_at.nil?
  end

  # Der Widerruf loescht die Adresse nicht: er haelt fest, dass nicht mehr angeschrieben werden
  # darf. Wer die Adresse ganz entfernen will, leert das Feld.
  def revoked?
    consent_revoked_at.present?
  end
end
