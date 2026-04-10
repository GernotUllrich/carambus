# frozen_string_literal: true

# Kapselt die gesamte create_table_reservation-Logik aus Tournament in einen eigenstaendigen Service.
# Verantwortlichkeiten:
#   - Guard conditions pruefen (location, discipline, date, required tables, available tables)
#   - Google Calendar Event erstellen via GoogleCalendarService
#   - Hilfs-Methoden: format_table_list, build_event_summary, calculate_start_time,
#     calculate_end_time, create_google_calendar_event, fallback_table_count
#
# Die Methoden required_tables_count und available_tables_with_heaters verbleiben
# gemaess D-07 auf dem Tournament-Modell.
#
# Verwendung:
#   Tournament::TableReservationService.call(tournament: tournament)
class Tournament::TableReservationService < ApplicationService
  def initialize(kwargs = {})
    @tournament = kwargs[:tournament]
  end

  def call
    return nil unless @tournament.location.present? && @tournament.discipline.present? && @tournament.date.present?

    tables_needed = @tournament.required_tables_count
    return nil if tables_needed.zero?

    available_tables = @tournament.available_tables_with_heaters(limit: tables_needed)
    return nil if available_tables.empty?

    # Build table list string (e.g., "T1, T2, T3" or "T1-T3")
    table_names = available_tables.map(&:name).sort_by { |name| name.match(/\d+/)[0].to_i }
    table_string = format_table_list(table_names)

    # Build event summary based on tournament details
    summary = build_event_summary(table_string)

    # Calculate event times
    start_time = calculate_start_time
    end_time = calculate_end_time

    # Create Google Calendar event
    create_google_calendar_event(summary, start_time, end_time)
  end

  private

  def fallback_table_count(participant_count)
    # Fallback estimation: half of participants (rounded up)
    # assuming simultaneous matches in first round
    (participant_count / 2.0).ceil
  end

  def format_table_list(table_names)
    return "" if table_names.empty?

    # Extract table numbers
    numbers = table_names.map { |name| name.match(/\d+/)[0].to_i }.sort

    # Single table: just "T5"
    return "T#{numbers.first}" if numbers.length == 1

    # Check if consecutive
    if numbers == (numbers.first..numbers.last).to_a
      # Consecutive: use range format "T5-T8"
      "T#{numbers.first}-T#{numbers.last}"
    else
      # Non-consecutive: list all "T1, T3, T5"
      numbers.map { |n| "T#{n}" }.join(", ")
    end
  end

  def build_event_summary(table_string)
    # Format: "T1, T2, T3 NDM Cadre 35/2 Klasse 5-6"
    # or: "T1-T3 Clubmeisterschaft 8-Ball"
    parts = [table_string]

    # Add tournament title or shortname
    if @tournament.shortname.present?
      parts << @tournament.shortname
    elsif @tournament.title.present?
      parts << @tournament.title
    end

    # Add discipline name if present
    if @tournament.discipline.present?
      parts << @tournament.discipline.name
    end

    # Add player class if present
    if @tournament.player_class.present?
      parts << "Klasse #{@tournament.player_class}"
    end

    parts.join(" ")
  end

  def calculate_start_time
    tournament_date = @tournament.date

    # Use starting_at from tournament_cc if available, otherwise default to 11:00
    if @tournament.tournament_cc.present? && @tournament.tournament_cc.starting_at.present?
      start_hour = @tournament.tournament_cc.starting_at.hour
      start_minute = @tournament.tournament_cc.starting_at.min
    else
      start_hour = 11
      start_minute = 0
    end

    # Combine date with time
    Time.zone.local(
      tournament_date.year,
      tournament_date.month,
      tournament_date.day,
      start_hour,
      start_minute,
      0
    ).utc.iso8601
  end

  def calculate_end_time
    tournament_date = @tournament.date

    # End time: 20:00
    Time.zone.local(
      tournament_date.year,
      tournament_date.month,
      tournament_date.day,
      20,
      0,
      0
    ).utc.iso8601
  end

  def create_google_calendar_event(summary, start_time, end_time)
    return nil unless Rails.application.credentials.dig(:google_service, :private_key).present?

    begin
      # Setup Google Calendar API service
      service = GoogleCalendarService.calendar_service
      calendar_id = GoogleCalendarService.calendar_id

      event_object = Google::Apis::CalendarV3::Event.new(
        summary: summary,
        start: {
          date_time: start_time,
          time_zone: "UTC"
        },
        end: {
          date_time: end_time,
          time_zone: "UTC"
        }
      )

      response = service.insert_event(calendar_id, event_object)
      Rails.logger.info "Tournament ##{@tournament.id}: Created calendar reservation '#{summary}' (Event ID: #{response.id})"
      response
    rescue StandardError => e
      Rails.logger.error "Tournament ##{@tournament.id}: Failed to create calendar reservation: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      nil
    end
  end
end
