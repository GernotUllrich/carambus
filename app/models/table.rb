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
  DEBUG_CALENDAR = false

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
    Rails.logger.info "Reservations: #{name} heater_on! ..." if DEBUG_CALENDAR
    res = {}
    if Rails.env == "production"
      Rails.logger.info "Reservations: HEATER ON - #{name}#{reason.present? ? " because of #{reason}" : ""}" if DEBUG_CALENDAR
      res = perform("on")
    else
      Rails.logger.info "Reservations: would do: HEATER ON - #{name}#{reason.present? ? " because of #{reason}" : ""}" if DEBUG_CALENDAR
    end
    unless res["error"].present?
      self.heater_switched_on_at = DateTime.now
      self.heater_switched_off_at = nil
      self.heater_on_reason = reason
      self.heater = true
      Rails.logger.info "Reservations: Heater switch on detected #{JSON.pretty_generate table_local.attributes}" if DEBUG_CALENDAR
      save if id >= Table::MIN_ID # heater is updated on TableLocal record
    end
    res
  end

  def heater_off!(reason = "")
    res = {}
    if Rails.env == "production"
      Rails.logger.info "Reservations: #{name} HEATER OFF - #{name}#{reason.present? ? " because of #{reason}" : ""}" if DEBUG_CALENDAR
      res = perform("off")
    else
      Rails.logger.info "Reservations: #{name} would do: \
HEATER OFF - #{name}#{reason.present? ? " because of #{reason}" : ""}" if DEBUG_CALENDAR
    end
    unless res["error"].present?
      self.heater_switched_off_at = DateTime.now
      self.heater_off_reason = reason
      self.heater = false
      Rails.logger.info "Reservations: #{name} Heater switch off detected \
#{JSON.pretty_generate table_local.attributes}" if DEBUG_CALENDAR
      save if id >= Table::MIN_ID # heater is updated on TableLocal record
    end
    res
  end

  def scoreboard_on?
    Rails.logger.info "Reservations: #{name} scoreboard_on?..." if DEBUG_CALENDAR
    if ip_address.present?
      pt = Net::Ping::External.new(ip_address)
      pt.ping?
    else
      false
    end
  end

  def heater_on?
    Rails.logger.info "Reservations: #{name} heater_on?..." if DEBUG_CALENDAR
    if Rails.env == "production"
      v = perform("info")
      heater_status = nil
      unless v["error"].present?
        heater_status = v["system"]["get_sysinfo"]["relay_state"] == 1
        self.heater = heater_status
        Rails.logger.info "Reservations: #{name} Check Heater Status - is #{heater_status}" if DEBUG_CALENDAR
        save if id >= Table::MIN_ID # heater is updated on TableLocal record
      end
      heater_status
    else
      heater_switched_on_at.present? && heater_switched_off_at.blank?
    end
  end

  # start heater when event starts within lead_time_in_hours hours
  # when event already underway but no activity on scoreboard for 1 hour - heater_off!
  def check_heater_on(event, event_ids: [])
    if ["Snooker", "Match Billard"].include?(table_kind.name) ||
      (((event.start.date || event.start.date_time).to_i - DateTime.now.to_i) / 1.hour) < pre_heating_time_in_hours &&
        ((event.end.date || event.end.date_time).to_i - DateTime.now.to_i).positive?
      Rails.logger.info "Reservations: #{name} check_heater_on \
#{JSON.pretty_generate table_local&.attributes.to_s} #{event.summary}..." if DEBUG_CALENDAR
      if event_id != event.id || (table_kind.name != "Pool" && !heater_on?)
        self.event_id = event.id
        self.event_summary = event.summary
        self.event_start = event.start.date || event.start.date_time
        self.event_end = event.end.date || event.end.date_time
        self.event_creator = event.creator.email
        heater_on!("event") unless table_kind.name == "Pool"
        Rails.logger.info "Reservations: #{name} event detected #{JSON.pretty_generate table_local.attributes}" if DEBUG_CALENDAR
        save if id >= Table::MIN_ID # heater is updated on TableLocal record
      elsif DateTime.now > event_start + 1.hour
        heater_off_on_idle(event_ids: event_ids) unless table_kind.name == "Pool"
      end
    end
  end

  def heater_auto_off?
    event_summary.andand.match(/!/)
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
    Rails.logger.info "Reservations: #{name} check_heater_off..." if DEBUG_CALENDAR
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
    Rails.logger.info "Reservations: #{name} heater_off_on_idle..." if DEBUG_CALENDAR
    if event_id.present? && !event_ids.include?(event_id)
      if event_end < DateTime.now
        Rails.logger.info "Reservations: #{name} Event #{event_summary} has finished!" if DEBUG_CALENDAR
      else
        Rails.logger.info "Reservations: #{name} Event #{event_summary} has been cancelled!" if DEBUG_CALENDAR
      end
      self.event_id = nil
      self.event_summary = nil
      self.event_start = nil
      self.event_end = nil
      save if id >= Table::MIN_ID # heater is updated on TableLocal record
    end
    scoreboard_really_on = scoreboard_on?
    if scoreboard_really_on
      unless scoreboard?
        self.scoreboard = true
        self.scoreboard_on_at = DateTime.now
        self.scoreboard_off_at = nil
        Rails.logger.info "Reservations: #{name} Scoreboard switch on detected - \
#{JSON.pretty_generate table_local.attributes}" if DEBUG_CALENDAR
        save if id >= Table::MIN_ID # heater is updated on TableLocal record
      end
      heater_on!("activity detected")
    else
      if scoreboard?
        self.scoreboard = false
        self.scoreboard_off_at = DateTime.now
        Rails.logger.info "Reservations: #{name} Scoreboard switch off detected - \
#{JSON.pretty_generate table_local.attributes}" if DEBUG_CALENDAR
        save if id >= Table::MIN_ID # heater is updated on TableLocal record
      end

      if event_id.present?
        # Event noch nicht gestartet und startet in < 120 Minuten: Heizung bleibt an
        if event_start.to_i > DateTime.now.to_i && (event_start.to_i - DateTime.now.to_i) / 1.minute < 120
          return
        end
        
        # Event bereits gestartet: Heizung nur an lassen, wenn innerhalb der ersten 30 Minuten
        # (gibt dem Spieler Zeit, das Scoreboard einzuschalten)
        if event_start.to_i <= DateTime.now.to_i && (DateTime.now.to_i - event_start.to_i) / 1.minute < 30
          return
        end
      end

      if !heater_auto_off? && heater_switched_on_at.present? && heater_switched_off_at.blank?
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
