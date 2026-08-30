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

  # Einwilligung erteilen — auch nach einem frueheren Widerruf.
  #
  # ⚠️ `consent_revoked_at` MUSS dabei zurueckgesetzt werden. Der Scope `contactable` (oben)
  # verlangt `consent_revoked_at IS NULL`; ohne das Zuruecksetzen bliebe ein einmal
  # Widerrufener dauerhaft nicht anschreibbar, obwohl er gerade erneut zugestimmt hat.
  def grant_consent!
    update!(consent_given_at: Time.current, consent_revoked_at: nil)
  end

  # Widerruf. ⚠️ Die Adresse bleibt bewusst stehen — der Widerruf sagt „nicht mehr
  # anschreiben", nicht „Daten loeschen". Wer die Adresse entfernen will, leert das Feld.
  def revoke_consent!
    update!(consent_revoked_at: Time.current)
  end

  # ---------------------------------------------------------------------------------------
  # Anmeldung im Spielerkontext (Plan 02.1-01)
  #
  # Der PIN ist KEINE Benutzeranmeldung, sondern eine Bestaetigung: der Spieler ist zu diesem
  # Zeitpunkt bereits ausgewaehlt. Deshalb gibt es hier bewusst keinen zweiten Devise-Scope.
  #
  # ⚠️ Warum nicht `players.pin4`? Die Spalte war untauglich — und ist mit Plan 02.1-04
  # inzwischen entfernt. Sie war GLOBAL
  # (LocalProtector verhindert, dass ein Clubserver sie ueberhaupt setzt), global EINDEUTIG
  # validiert (bei vier Stellen waeren systemweit hoechstens ~9.980 PINs vergebbar, und ein
  # erratener PIN identifizierte einen Spieler), sie speichert im KLARTEXT, und sie ist
  # vollstaendig ungenutzt (0 von 47.774 Spielern). Hier entfaellt beides: der PIN muss nicht
  # eindeutig sein, und er liegt als bcrypt-Hash.
  # ---------------------------------------------------------------------------------------

  # `validations: false` ist noetig: die Standard-Validierungen von `has_secure_password`
  # verlangen Anwesenheit und eine `pin_confirmation`. Der PIN ist hier aber OPTIONAL — nicht
  # jedes Mitglied hat einen, und die Adresspflege muss ohne ihn funktionieren.
  has_secure_password :pin, validations: false

  # 4 bis 8 Ziffern, Standard 4 (Betreiber-Entscheidung 2026-08-30). Der laengere PIN ist der
  # Ausgleich dafuer, dass der Clubserver per DynDNS von aussen erreichbar ist; der Ziffernblock
  # traegt jede Laenge, es braucht also keine zusaetzliche Oberflaeche.
  PIN_FORMAT = /\A\d{4,8}\z/

  # ⚠️ BEWUSST KOPIERT aus der Inline-Liste in player.rb (Validierung von `pin4`), statt sie
  # dort herauszuziehen: `player.rb` ist ein globales Modell und funktioniert — ein Refactoring
  # dort braechte keinen funktionalen Gewinn und beruehrte Authority-Hoheit.
  TRIVIAL_PINS = %w[1234 1111 0000 1212 7777 1004 2000 4444 2222 6969 9999 3333 5555 6666
    1122 1313 8888 4321 2001 1010].freeze

  # Ab dem fuenften Fehlversuch wird gesperrt.
  PIN_ATTEMPTS_BEFORE_LOCK = 5
  # Die erste Sperre dauert eine Minute und verdoppelt sich mit jedem weiteren Fehlversuch.
  PIN_LOCK_BASE = 1.minute
  # ⚠️ Gedeckelt: eine unbegrenzte Verdopplung waere aus Versehen eine dauerhafte Aussperrung,
  # und die Sperre ist auch ein Aergernis-Hebel (jeder kann fremde Konten sperren).
  PIN_LOCK_MAX = 1.hour

  # Ein leeres Formularfeld darf den vorhandenen PIN NICHT loeschen. Administrate rendert
  # `Field::Password` immer leer; ohne diesen Guard verloere jedes Speichern der Adresse den
  # PIN gleich mit. Zum Entfernen dient `clear_pin!`, nicht das leere Feld.
  def pin=(wert)
    return if wert.blank?

    super
  end

  validate :pin_format_und_nicht_trivial, if: -> { pin_digest_changed? && pin.present? }

  def pin_format_und_nicht_trivial
    unless pin.match?(PIN_FORMAT)
      errors.add(:pin, I18n.t("player_local.pin_format",
        default: "Der PIN besteht aus 4 bis 8 Ziffern."))
      return
    end

    if TRIVIAL_PINS.include?(pin)
      errors.add(:pin, I18n.t("player_local.pin_trivial",
        default: "Dieser PIN ist zu leicht zu erraten."))
    end
  end
  private :pin_format_und_nicht_trivial

  def pin_set?
    pin_digest.present?
  end

  def pin_locked?
    pin_locked_until.present? && pin_locked_until > Time.current
  end

  # Sekunden bis die Sperre faellt — fuer die Rueckmeldung an der Oberflaeche.
  def pin_lock_remaining
    return 0 unless pin_locked?

    (pin_locked_until - Time.current).ceil
  end

  # Der einzige Weg, einen PIN zu pruefen. Wer `authenticate_pin` von `has_secure_password`
  # direkt aufruft, umgeht die Sperre — deshalb hier ein eigener Name.
  #
  # Rueckgabe: true bei Erfolg, sonst false. Bei Sperre ebenfalls false, ohne den PIN
  # ueberhaupt zu pruefen (sonst liesse sich waehrend der Sperre weiter durchprobieren).
  def verify_pin(kandidat)
    return false if pin_locked? || !pin_set?

    if authenticate_pin(kandidat.to_s)
      reset_pin_attempts!
      true
    else
      register_failed_pin_attempt!
      false
    end
  end

  def reset_pin_attempts!
    update!(failed_pin_attempts: 0, pin_locked_until: nil)
  end

  def register_failed_pin_attempt!
    versuche = failed_pin_attempts + 1
    attrs = {failed_pin_attempts: versuche}

    if versuche >= PIN_ATTEMPTS_BEFORE_LOCK
      # Der erste sperrende Fehlversuch gibt PIN_LOCK_BASE, jeder weitere verdoppelt.
      faktor = 2**(versuche - PIN_ATTEMPTS_BEFORE_LOCK)
      attrs[:pin_locked_until] = Time.current + [PIN_LOCK_BASE * faktor, PIN_LOCK_MAX].min
    end

    # ⚠️ `update!`, NICHT `update_columns`: letzteres umginge `nur_auf_lokalem_server` und
    # liesse Zaehlerstaende auf der Authority entstehen.
    update!(attrs)

    # ⚠️ NIEMALS den eingegebenen PIN protokollieren.
    Rails.logger.warn(
      "[PlayerLocal] fehlgeschlagene PIN-Eingabe: player_id=#{player_id} " \
      "versuche=#{versuche} gesperrt_bis=#{pin_locked_until&.iso8601 || "-"}"
    )
  end

  # ---------------------------------------------------------------------------------------
  # Einladung: das Mitglied setzt seinen PIN selbst (Plan 02.2-01)
  #
  # ⚠️ Der PIN wird NICHT gemailt. Er laege sonst dauerhaft im Klartext im Postfach — und der
  # Login gilt seit Plan 02.1-01 auch ueber das offene Netz. Verschickt wird ein Einmal-Link.
  # ---------------------------------------------------------------------------------------

  PIN_SETUP_TOKEN_VALIDITY = 7.days

  # ⚠️ KEINE Spalte noetig: `generates_token_for` erzeugt einen SIGNIERTEN Token, der seinen
  # Ablauf selbst traegt. Kein Aufraeum-Job, kein Zustand, der gepflegt werden muss.
  #
  # ⚠️ Der Block ist der Kern der Einmaligkeit: der Token bindet sich an `pin_digest`. Sobald
  # ein PIN gesetzt wird, aendert sich der Digest — und JEDER frueher erzeugte Link wird damit
  # ungueltig. Einmaligkeit entsteht aus der Konstruktion, nicht aus einem Flag, das jemand
  # zuruecksetzen muesste.
  generates_token_for :pin_setup, expires_in: PIN_SETUP_TOKEN_VALIDITY do
    pin_digest
  end

  # Einen PIN wieder entfernen. Bewusst ein eigener Weg — ein leeres Formularfeld tut es nicht.
  def clear_pin!
    update!(pin_digest: nil, failed_pin_attempts: 0, pin_locked_until: nil)
  end
end
