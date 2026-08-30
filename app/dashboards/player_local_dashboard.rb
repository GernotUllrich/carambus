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
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    player
    email
    consent_given_at
    consent_revoked_at
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    player
    email
    consent_given_at
    consent_revoked_at
    created_at
    updated_at
  ].freeze

  # `player` bleibt im Formular, damit sich der Bezug beim Anlegen setzen laesst.
  FORM_ATTRIBUTES = %i[
    player
    email
    consent_given_at
    consent_revoked_at
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(player_local)
    [player_local.player&.fl_name, player_local.email].compact.join(" · ").presence ||
      "Kontakt #{player_local.id}"
  end
end
