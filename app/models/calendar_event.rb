# frozen_string_literal: true

# CalendarEvent is currently not used as ActiveRecord
# Just some service methods
class CalendarEvent < ApplicationRecord
  include ApiProtector
  broadcasts_refreshes
  DEBUG = false

  #    handle_event(calendar_id, event_ids, lead_time_in_hours, location, response, service, summaries, tables_to_be_heated_all, upcoming_events, upcoming_events_h)
  # accululation structures summaries[], upcoming_events[], upcoming_events_h{}, event_ids[] managed outside of this method
  def self.handle_event(calendar_id, event, event_ids, lead_time_in_hours, location, service, summaries, upcoming_events, upcoming_events_h)
    tables_to_be_heated = []
    event_ids << event.id
    title = event.summary
    unless event.summary.match(/\A\w+\s*:/)
      tables_to_be_heated = CalendarEvent.tables_from_summary(title, location)
      if tables_to_be_heated.present?
        start = event.start.date || event.start.date_time
        ende = event.end.date || event.end.date_time
        summary_day_hour = "#{title}, #{I18n.l(start, format: "%A")} #{start.strftime("%H:%M")}"
        full_entry = "#{title}, #{(I18n.l start).split(", ").join(", ").gsub(" Uhr",
                                                                             "")} - #{(I18n.l ende).split(", ").last}"
        if summaries.include?(summary_day_hour)
          upcoming_events_h[summary_day_hour][1] = "repeated"
        else
          upcoming_events_h[summary_day_hour] = [full_entry, "single"]
          upcoming_events << full_entry
          summaries << summary_day_hour
        end
        if ((start.to_i - DateTime.now.to_i) / 1.hour) < lead_time_in_hours &&
           (ende.to_i - DateTime.now.to_i).positive?
          tables_to_be_heated.map { |t| t.check_heater_on(event) }
        end

        tables_to_be_heated.map { |t| t.check_heater_on(event) }
      else
        CalendarEvent.remove_event(service, calendar_id, event)
      end
    end
    tables_to_be_heated
  end

  def self.remove_event(service, calendar_id, event)
    ret = service.delete_event(calendar_id, event.id, send_notifications: true)
    Rails.logger.info "Reservations: WARNING - nonconformant event #{event.summary} deleted"
    ret
  rescue Google::Apis::ClientError => e
    Rails.logger.warn "Reservations: WARNING - cannot delete nonconformant event #{event.summary}: #{e.message}"
    nil
  end

  # Tischnummern aus einem Kalender-Titel lesen — tolerant gegenüber den Schreibweisen,
  # die im Vereinsalltag vorkommen (Betreiber-Entscheidung 2026-09-21):
  #   "T5 Hajo"  "Nils T5 (!)"  "Nils T5(!)"  "Nils t5"  "T1,T3"  "T1-T3"  "T1-3"  "T1-T3."
  # Nicht gedeutet werden Formen wie "Tisch 5" — sie könnten in jedem Fließtext stehen.
  #
  # Zwei Dinge sind hier bewusst fehlertolerant, weil ein einzelner Termin sonst den
  # gesamten Heizungslauf abbricht (Vorfall 2026-09-21, alle Tische kalt):
  #   - ein Titel, der nil ist, ergibt eine leere Liste
  #   - eine Tischnummer, die es am Spielort nicht gibt, wird übersprungen statt als nil
  #     zurückgegeben (der Aufrufer ruft `table_kind` darauf)
  def self.tables_from_summary(string, location)
    tables = location.tables.order(:name).to_a
    table_nos = []
    string.to_s.tr(",", " ").gsub("  ", " ").gsub(/\s*-\s*/, "-").split(" ").each do |str|
      # Satzzeichen rund um das Wort ignorieren: "T5(!)" → "T5", "T1-T3." → "T1-T3"
      token = str.sub(/\A[^[:alnum:]]+/, "").sub(/[^[:alnum:]]+\z/, "")
      m = token.match(/\AT(\d+)\z/i)
      m2 = token.match(/\AT(\d+)-T?(\d+)\z/i) # "T1-T3" und die Kurzform "T1-3"
      if m # single table match
        table_nos << m[1].to_i
      elsif m2 # range of tables match
        table_nos += (m2[1].to_i..m2[2].to_i).to_a
      end
    end
    table_nos.filter_map { |no| tables[no - 1] if no.positive? && no <= tables.size }
  end
end
