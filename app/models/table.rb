# frozen_string_literal: true

require "net/ping"
# == Schema Information
#
# Table name: tables
#
#  id               :bigint           not null, primary key
#  data             :text
#  ip_address       :string
#  name             :string
#  tpl_ip_address   :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  location_id      :integer
#  table_kind_id    :integer
#  table_monitor_id :integer
#
# Foreign Keys
#
#  fk_rails_...  (location_id => locations.id)
#  fk_rails_...  (table_kind_id => table_kinds.id)
#
class Table < ApplicationRecord
  include LocalProtector
  include RegionTaggable
  include TpLink
  self.ignored_columns = ["region_ids"]
  belongs_to :location
  belongs_to :table_kind
  belongs_to :table_monitor, optional: true
  has_one :table_local, dependent: :destroy
  has_one :stream_configuration, dependent: :destroy
  MIN_ID = 50_000_000
  LOCAL_METHODS = %i[
    ip_address tpl_ip_address event_id event_summary event_start event_end event_creator heater heater_on_reason
    heater_off_reason heater_switched_on_at heater_switched_off_at manual_heater_on_at manual_heater_off_at
    scoreboard scoreboard_on_at scoreboard_off_at
  ].freeze
  DEBUG_CALENDAR = true

  serialize :data, coder: JSON, type: Hash

  LOCAL_METHODS.each do |meth|
    define_method(meth) do
      id.present? && id < Table::MIN_ID && table_local.present? ? table_local.send(meth) : read_attribute(meth)
    end

    define_method(:"#{meth}=") do |value|
      if new_record?
        write_attribute(meth, value)
      elsif id < Table::MIN_ID
        tal = table_local.presence || create_table_local(
          (LOCAL_METHODS.map { |method| [method, read_attribute(method)] }).to_h
        )
        tal.update(meth => value)
      else
        write_attribute(meth, value)
      end
    end
  end

  def number
    m = name.match(/.*(\d+).*/)
    m.present? ? m[1].to_i : 0
  end

  def heater_on!(reason = "")
    # Only log if heater is actually being turned ON (state change)
    was_off = heater_switched_off_at.present? || heater_switched_on_at.blank?
    return unless was_off # Already on, skip
    
    res = {}
    if Rails.env == "production"
      Rails.logger.info "🔥 HEATER ON - #{name} (reason: #{reason})" if DEBUG_CALENDAR
      res = perform("on")
    else
      Rails.logger.info "🔥 HEATER ON (dev) - #{name} (reason: #{reason})" if DEBUG_CALENDAR
    end
    unless res["error"].present?
      self.heater_switched_on_at = DateTime.now
      self.heater_switched_off_at = nil
      self.heater_on_reason = reason
      self.heater = true
      save if id >= Table::MIN_ID # heater is updated on TableLocal record
    end
    res
  end

  def heater_off!(reason = "")
    # Only log if heater is actually being turned OFF (state change)
    was_on = heater_switched_on_at.present? && heater_switched_off_at.blank?
    return unless was_on # Already off, skip
    
    # Enhanced logging with full context for debugging (only on state change)
    if DEBUG_CALENDAR
      context = {
        table: name,
        reason: reason,
        event_id: event_id,
        event_summary: event_summary,
        event_start: event_start,
        event_end: event_end,
        scoreboard: scoreboard,
        scoreboard_off_at: scoreboard_off_at,
        heater_switched_on_at: heater_switched_on_at,
        allow_auto_off: !event_summary.to_s.include?("(!)"),
        time_since_event_start: event_start.present? ? ((DateTime.now.to_i - event_start.to_i) / 1.minute).round(1) : nil,
        time_until_event_end: event_end.present? ? ((event_end.to_i - DateTime.now.to_i) / 1.minute).round(1) : nil
      }
      Rails.logger.warn "🔥 HEATER OFF: #{JSON.pretty_generate(context)}"
    end
    
    res = {}
    if Rails.env == "production"
      res = perform("off")
    end
    unless res["error"].present?
      self.heater_switched_off_at = DateTime.now
      self.heater_off_reason = reason
      self.heater = false
      save if id >= Table::MIN_ID # heater is updated on TableLocal record
    end
    res
  end

  def scoreboard_on?
    # No logging for status checks - only log state changes
    if ip_address.present?
      pt = Net::Ping::External.new(ip_address)
      pt.ping?
    else
      false
    end
  end

  def heater_on?
    # No logging for status checks - only log state changes
    if Rails.env == "production"
      v = perform("info")
      heater_status = nil
      unless v["error"].present?
        heater_status = v["system"]["get_sysinfo"]["relay_state"] == 1
        self.heater = heater_status
        save if id >= Table::MIN_ID # heater is updated on TableLocal record
      end
      heater_status
    else
      heater_switched_on_at.present? && heater_switched_off_at.blank?
    end
  end

  # Start heater when event starts within pre_heating_time_in_hours (2-3h depending on table size)
  # When event already underway but no activity on scoreboard for 30 minutes - heater_off!
  def check_heater_on(event, event_ids: [])
    if ["Snooker", "Match Billard"].include?(table_kind.name) ||
      (((event.start.date || event.start.date_time).to_i - DateTime.now.to_i) / 1.hour) < pre_heating_time_in_hours &&
        ((event.end.date || event.end.date_time).to_i - DateTime.now.to_i).positive?
      
      new_event_start = event.start.date || event.start.date_time
      new_event_end = event.end.date || event.end.date_time
      
      # Check if event is new or has been modified (times or summary changed)
      event_changed = event_id != event.id || 
                      event_start != new_event_start || 
                      event_end != new_event_end ||
                      event_summary != event.summary
      
      if event_changed
        # Log what changed
        if event_id != event.id
          Rails.logger.info "📅 #{name}: New event detected - #{event.summary}" if DEBUG_CALENDAR
        else
          changes = []
          changes << "start: #{event_start} → #{new_event_start}" if event_start != new_event_start
          changes << "end: #{event_end} → #{new_event_end}" if event_end != new_event_end
          changes << "summary: '#{event_summary}' → '#{event.summary}'" if event_summary != event.summary
          Rails.logger.info "📅 #{name}: Event modified - #{changes.join(", ")}" if DEBUG_CALENDAR
        end
        
        self.event_id = event.id
        self.event_summary = event.summary
        self.event_start = new_event_start
        self.event_end = new_event_end
        self.event_creator = event.creator.email
        heater_on!("event") unless table_kind.name == "Pool"
        save if id >= Table::MIN_ID # heater is updated on TableLocal record
      elsif table_kind.name != "Pool" && !heater_on?
        # Heater should be on but isn't - turn it on
        heater_on!("event")
      elsif DateTime.now > event_start + 30.minutes
        # Event started more than 30 minutes ago - check if heater should be turned off due to inactivity
        heater_off_on_idle(event_ids: event_ids) unless table_kind.name == "Pool"
      end
    end
  end

  def heater_auto_off?
    event_summary.andand.include?("(!)")
  end

  def short_event_summary
    return unless event_id.present?

    m = event_summary.match(/(T\d+|T\d+\s*-\s*T\d+)\s+(.*)/)
    if m
      m[1].delete("T").delete(" ") + m[2].split(/\s+/).map { |s| s[0..1] }.join("")
    else
      "err"
    end
  end

  def check_heater_off(event_ids: [])
    # No logging here - heater_off_on_idle will log state changes
    heater_off_on_idle(event_ids: event_ids)
  end

  def pre_heating_time_in_hours
    if %w[Match Billard Snooker].include? self.table_kind.name
      3
    else
      2
    end
  end

  def heater_off_on_idle(event_ids: [])
    # Capture before we may clear it (when event not in event_ids), so "(!)" check still works
    current_event_summary = event_summary
    
    # Check if event has been removed/cancelled (only log on state change)
    if event_id.present? && !event_ids.include?(event_id)
      if event_end < DateTime.now
        Rails.logger.info "📅 #{name}: Event '#{event_summary}' has finished" if DEBUG_CALENDAR
      else
        Rails.logger.warn "📅 #{name}: Event '#{event_summary}' was cancelled!" if DEBUG_CALENDAR
      end
      self.event_id = nil
      self.event_summary = nil
      self.event_start = nil
      self.event_end = nil
      save if id >= Table::MIN_ID # heater is updated on TableLocal record
    end
    
    scoreboard_really_on = scoreboard_on?
    
    # Scoreboard state changes - only log when state actually changes
    if scoreboard_really_on
      unless scoreboard?
        self.scoreboard = true
        self.scoreboard_on_at = DateTime.now
        self.scoreboard_off_at = nil
        Rails.logger.info "📺 #{name}: Scoreboard switched ON" if DEBUG_CALENDAR
        save if id >= Table::MIN_ID # heater is updated on TableLocal record
      end
      heater_on!("activity detected")
    else
      if scoreboard?
        self.scoreboard = false
        self.scoreboard_off_at = DateTime.now
        Rails.logger.info "📺 #{name}: Scoreboard switched OFF" if DEBUG_CALENDAR
        save if id >= Table::MIN_ID # heater is updated on TableLocal record
      end

      if event_id.present?
        # Event noch nicht gestartet und startet in < 120 Minuten: Heizung bleibt an
        # (Vorheizphase - Event wurde erkannt und Heizung ist bereits an)
        # No logging - this is normal operation
        if event_start.to_i > DateTime.now.to_i && (event_start.to_i - DateTime.now.to_i) / 1.minute < 120
          return
        end
        
        # Event bereits gestartet: Heizung nur an lassen, wenn innerhalb der ersten 30 Minuten
        # (gibt dem Spieler Zeit, das Scoreboard einzuschalten)
        # Nach 30 Minuten ohne Scoreboard-Aktivität wird die Heizung ausgeschaltet
        # No logging - this is normal operation
        if event_start.to_i <= DateTime.now.to_i && (DateTime.now.to_i - event_start.to_i) / 1.minute < 30
          return
        end
      end

      # Use current_event_summary (captured at start) so we don't turn off when event had "(!)" even if we cleared it above
      allow_auto_off = !current_event_summary.to_s.include?("(!)")
      if allow_auto_off && heater_switched_on_at.present? && heater_switched_off_at.blank?
        heater_off!("inactivity detected")
      end
    end
  end

  def tpl_get_time
    v = perform("time")
    Time.new(*v["time"]["get_time"].values) unless v["error"].present?
  end

  def terminate_outworn_game
    toumo = table_monitor&.tournament_monitor
    if toumo.present? && toumo.closed? &&
      (DateTime.now.to_i - toumo.updated_at.to_i) / 1.hours > 12 # tournament still underway?
      toumo.tournament&.forced_reset_tournament_monitor!
    elsif toumo.blank? && table_monitor&.game.present? && (DateTime.now.to_i - table_monitor.updated_at.to_i) / 1.hours > 12
      table_monitor.game.table_monitor&.reset_table_monitor
      table_monitor.game&.destroy
    end
  end

  def table_monitor!
    return unless ApplicationRecord.local_server?

    table_monitor_id = read_attribute(:table_monitor_id)
    TableMonitor.transaction do
      tm = TableMonitor.find_by_id(table_monitor_id)
      if tm.blank?
        tm = TableMonitor.create
        update_columns(table_monitor_id: tm.id)
      end
      tm
    end
  end

end
