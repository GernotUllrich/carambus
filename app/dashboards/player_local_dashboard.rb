require "administrate/base_dashboard"

# Lokale Kontaktdaten der Clubmitglieder. Nur fuer System-Admins erreichbar —
# `Admin::ApplicationController#authenticate_admin` laesst ausschliesslich `system_admin?`
# durch. Das ist hier keine Formalie: es sind personenbezogene Daten.
class PlayerLocalDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,

    # ⚠️ Die Auswahl MUSS eingeschraenkt werden. Administrate rendert `Field::BelongsTo` als
    # `<select>` mit ALLEN Records der Zielklasse — `players` hat 47.716 Zeilen (gemessen
    # 2026-08-30). Ohne Scope waere das Formular unbenutzbar und der Seitenaufbau langsam.
    #
    # Der Scope sind die Mitglieder des konfigurierten Clubs in der laufenden Saison, also
    # genau der Personenkreis, um den es geht (BC Wedel: 23).
    player: Field::BelongsTo.with_options(scope: -> { PlayerLocal.selectable_players }),

    email: Field::String,
    consent_given_at: Field::DateTime,
    consent_revoked_at: Field::DateTime,

    # PIN-Erstvergabe (Plan 02.1-01). `Field::Password` rendert immer LEER und spielt den Hash
    # nicht zurueck ins Formular.
    #
    # ⚠️ Ein leeres Feld darf den vorhandenen PIN nicht loeschen — dafuer sorgt der Setter-Guard
    # `PlayerLocal#pin=`. Ohne ihn verloere jedes Speichern der Adresse den PIN gleich mit.
    pin: Field::Password,

    # Damit der Admin sieht, wer sich ausgesperrt hat. Nur lesend — die Sperre faellt von selbst.
    pin_locked_until: Field::DateTime,

    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  # ⚠️ `pin` steht hier bewusst NICHT — ein PIN gehoert in keine Liste, auch nicht als Hash.
  COLLECTION_ATTRIBUTES = %i[
    player
    email
    consent_given_at
    consent_revoked_at
    pin_locked_until
  ].freeze

  # ⚠️ Ebenfalls ohne `pin`: die Detailseite zeigt den Sperrzustand, nicht das Geheimnis.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    player
    email
    consent_given_at
    consent_revoked_at
    pin_locked_until
    created_at
    updated_at
  ].freeze

  # `player` bleibt im Formular, damit sich der Bezug beim Anlegen setzen laesst.
  # `pin` ist die Erstvergabe durch den System-Admin; das Mitglied aendert ihn spaeter selbst.
  FORM_ATTRIBUTES = %i[
    player
    email
    consent_given_at
    consent_revoked_at
    pin
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(player_local)
    [player_local.player&.fl_name, player_local.email].compact.join(" · ").presence ||
      "Kontakt #{player_local.id}"
  end
end
