# frozen_string_literal: true

module Calendar
  # Ein Termin im Kalender — Turnier ODER Liga-Spieltag.
  #
  # Bewusst ein Wertobjekt und KEIN ActiveRecord: `Tournament` und `Party` haben kein gemeinsames
  # Interface (verschiedene Titel-Wege, Party traegt die Paarung, Tournament die Disziplin), und
  # sie brauchen auch keines — die Gemeinsamkeit existiert nur fuer die Dauer einer Kalenderseite.
  # Eine Tabelle dafuer waere eine zweite Wahrheit neben zwei bestehenden.
  Entry = Struct.new(
    :starts_on,      # Date — der Tag, an dem der Eintrag im Kalender steht
    :ends_on,        # Date oder nil — nur bei mehrtaegigen Turnieren gesetzt
    :time,           # String "HH:MM" oder nil
    :title,          # "1. Vorgabepokal" bzw. "Oberliga Snooker"
    :subtitle,       # Disziplin bzw. "Heim - Gast"
    :branch_name,    # "Karambol" | "Pool" | "Snooker" | "Kegel" | nil
    :league_name,    # nur bei Spieltagen — die Gruppierungsachse der Ansicht
    :location_name,
    :kind,           # :tournament | :party
    :source,         # :region | :dbu
    :record,         # das Original, fuer den Link
    keyword_init: true
  ) do
    def tournament? = kind == :tournament

    def party? = kind == :party

    def dbu? = source == :dbu

    # Mehrtaegig ist der Randfall (15 von 379 Turnieren tragen ueberhaupt ein `end_date`,
    # 14 davon enden spaeter als sie beginnen) — die Ansicht entscheidet, was sie damit tut.
    def multi_day? = ends_on.present? && ends_on > starts_on

    def days = multi_day? ? (starts_on..ends_on).to_a : [starts_on]
  end
end
