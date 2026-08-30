# frozen_string_literal: true

# PIN fuer die Anmeldung im Spielerkontext (Plan 02.1-01).
#
# Rein additiv: drei neue Spalten, kein Eingriff in Bestehendes. Die Tabelle traegt
# ausschliesslich lokale Daten und erreicht die Authority nicht — der Guard dafuer haengt an
# der Rolle des Servers (`PlayerLocal#nur_auf_lokalem_server`) und gilt fuer diese Spalten mit.
#
# ⚠️ BEWUSST OHNE `has_paper_trail` (Entscheidung aus Quick-Task 4, 2026-08-30): ein
# geloeschter PIN bliebe sonst in `versions` lesbar — bei personenbezogenen Daten ist das ein
# Loeschen, das nicht loescht.
class AddPinToPlayerLocals < ActiveRecord::Migration[7.2]
  def change
    # bcrypt-Hash aus `has_secure_password :pin`. ⚠️ KEIN Index: ein Hash ist nie
    # Suchkriterium — der Spieler wird ausgewaehlt, der PIN bestaetigt nur.
    add_column :player_locals, :pin_digest, :string

    # Die Sperre nach Fehlversuchen. Sie ist Pflichtbestandteil und nicht Kuer: der Clubserver
    # ist per DynDNS von aussen erreichbar (Betreiber-Auskunft 2026-08-30), und vier Ziffern
    # waeren dort ohne Sperre in Minuten durchprobiert.
    #
    # ⚠️ Der urspruenglich geplante ZWEITE Zaehler pro IP entfaellt bewusst: er braeuchte
    # `Rails.cache`, und der ist in Development `:null_store` (development.rb) — die Sperre
    # haette bei der Abnahme funktionsfaehig ausgesehen und nichts getan. Der Zaehler pro
    # Spieler ist der wirksame Teil, er kappt die Versuche pro Konto unabhaengig von der IP.
    add_column :player_locals, :failed_pin_attempts, :integer, null: false, default: 0
    add_column :player_locals, :pin_locked_until, :datetime
  end
end
