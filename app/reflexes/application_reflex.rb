# frozen_string_literal: true

class ApplicationReflex < StimulusReflex::Reflex
  # Put application-wide Reflex behavior and callbacks in this file.
  #
  # Learn more at: https://docs.stimulusreflex.com/rtfm/reflex-classes
  #
  # If your ActionCable connection is: `identified_by :current_user`
  delegate :current_user, to: :connection

  # Plan 40-01: Reflexes laufen ausserhalb des Request-Zyklus — `before_action :set_locale`
  # greift hier NICHT. Bis hierher stand der Hinweis im generierten Geruest nur als
  # auskommentiertes Beispiel, und jeder Reflex renderte in der Prozess-Locale. Zusammen mit
  # demselben Problem im TableMonitorJob war das der Grund, warum ein per `?locale=en`
  # aufgerufenes Scoreboard beim ersten Live-Update auf Deutsch zurueckfiel.
  #
  # Aufgeloest wird ueber dieselbe Stelle wie in Controller und Job: TableMonitor#display_locale.
  # Ist nichts konfiguriert oder das Element keinem TableMonitor zuzuordnen, bleibt die Locale
  # unangetastet — nicht raten.
  around_reflex do |_reflex, block|
    locale = reflex_display_locale
    locale ? I18n.with_locale(locale, &block) : block.call
  end

  private

  # `element.dataset[:id]` ist die Konvention, mit der die Scoreboard-Elemente ihren
  # TableMonitor mitgeben (table_monitors/_scoreboard.html.erb, party_monitors/_game_row.html.erb,
  # tournament_monitors/_current_games.html.erb — alle drei fuehren dort eine TableMonitor-ID).
  #
  # Bewusst an den Reflex-TYP gebunden statt allein an die data-id: `data-id` ist eine
  # allgemeine Konvention, und ein anderer Reflex koennte dort etwas anderes fuehren. Dann
  # wuerde `find_by(id:)` einen fremden TableMonitor treffen und die Sprache eines
  # unbeteiligten Scoreboards ziehen. Nur bei TableMonitorReflex ist die Bedeutung garantiert.
  def reflex_display_locale
    return nil unless is_a?(TableMonitorReflex)

    id = element&.dataset&.[](:id)
    return nil if id.blank?

    TableMonitor.find_by(id: id)&.display_locale
  rescue => e
    Rails.logger.warn("ApplicationReflex: Locale nicht aufloesbar (#{e.class}: #{e.message})")
    nil
  end
end
