class AddPersonaGrantsToUsers < ActiveRecord::Migration[7.2]
  # D-38 (v1.0): Explizite, nur-system_admin-setzbare Sportwart-Persona-GRANTS als jsonb-Array.
  # Werte: "sportwart" (location-scoped) / "landessportwart" (region-weit, alle Locations).
  #
  # Spaltenname `persona_grants` (NICHT `personas`) wegen Kollision mit der bestehenden
  # abgeleiteten Methode UserPersonas#personas (cc_whoami-Contract: role + abgeleitete Personas).
  # Rein ADDITIV — KEIN Backfill (D-38-5: Grants werden manuell durch system_admin gesetzt;
  # bis dahin Default [] = kein Sportwart = read-only).
  def change
    add_column :users, :persona_grants, :jsonb, default: [], null: false
  end
end
