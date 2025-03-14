# frozen_string_literal: true

# == Schema Information
#
# Table name: locations
#
#  id             :bigint           not null, primary key
#  address        :text
#  data           :text
#  dbu_nr         :integer
#  md5            :string           not null
#  name           :string
#  organizer_type :string
#  source_url     :string
#  sync_date      :datetime
#  synonyms       :text
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  cc_id          :integer
#  club_id        :integer
#  organizer_id   :integer
#
# Indexes
#
#  index_locations_on_md5  (md5) UNIQUE
class Location < ApplicationRecord
  include LocalProtector
  include SourceHandler
  # belongs_to :club
  has_many :club_locations
  has_many :clubs, through: :club_locations
  has_many :parties, foreign_key: :location_id
  belongs_to :organizer, polymorphic: true
  has_many :tables
  has_many :tournaments, foreign_key: :location_id

  self.ignored_columns = ["club_id"]

  cattr_accessor :table_kinds

  serialize :data, coder: JSON, type: Hash

  REFLECTION_KEYS = %w[club region].freeze
  # TODO: Filters
  COLUMN_NAMES = { "Id" => "clubs.id",
                   "Clubs" => "clubs.shortname",
                   "Address" => "locations.address",
                   "Name" => "locations.name" }.freeze
  def self.search_hash(params)
    {
      model: Location,
      sort: params[:sort],
      direction: sort_direction(params[:direction]),
      search: params[:sSearch],
      column_names: Location::COLUMN_NAMES,
      raw_sql: "(locations.name ilike :search)
 or (locations.address ilike :search)
 or (locations.synonyms ilike :search)
 or (clubs.shortname ilike :search)",
      # joins: [{ club_locations: :club }],
      joins: ['LEFT OUTER JOIN "club_locations" ON "club_locations"."location_id" = "locations"."id"', 'LEFT OUTER JOIN "clubs" ON "clubs"."id" = "club_locations"."club_id"']
    }
  end

  before_save :add_md5

  def club
    @club ||= clubs.first
  end

  def add_md5
    self.synonyms = (synonyms.to_s.split("\n") + [name]).reject(&:blank?).sort.uniq.join("\n")
    self.md5 ||= Digest::MD5.hexdigest(attributes.except("synonyms", "updated_at", "created_at").inspect)
  end

  def self.scrape_locations
    Region.where(shortname: Region::SHORTNAMES_CARAMBUS_USERS + Region::SHORTNAMES_OTHERS).all.each(&:scrape_locations)
  end

  def self.merge_locations(location_ok_id, with_location_ids = [])
    with_locations = Location.where(id: with_location_ids)
    raise ArgumentError if with_locations.count == with_location_ids.count

    location_ok = Location[location_ok_id]
    raise ArgumentError unless location_ok.present?

    location_ok.merge_locations(with_location_ids)
  end

  def background_image
    counts = {}
    tables.each { |t| counts[t.table_kind_id] = counts[t.table_kind_id].to_i + 1 }
    max_table_kind_id = counts.max_by { |_k, v| v }.andand[0]
    TableKind::TABLE_KIND_BACKGROUND[TableKind[max_table_kind_id].andand.name] ||
      TableKind::TABLE_KIND_BACKGROUND["Small Billard"]
  rescue StandardError => e
    Rails.logger.info "!!!!!!!!! Problem #{e} #{e.backtrace&.join("\n")}"
    raise StandardError
  end

  def merge_locations(with_location_ids = [])
    cc_id = Location.where(id: with_location_ids).all.map(&:cc_id).compact.uniq.first
    attrs = {
      synonyms: (Location.where(id: with_location_ids).map(&:name) | synonyms.split("\n"))
            .reject(&:blank?).uniq.join("\n")
    }.merge(cc_id: cc_id).compact
    update(attrs)
    Tournament.where(location_id: with_location_ids).all.each { |l| l.update(location_id: id) }
    Table.where(location_id: with_location_ids).all.each { |l| l.update(location_id: id) }
    Location.where(id: with_location_ids).destroy_all
    Rails.logger.info("REPORT Location.merge_locations(#{id}, #{with_location_ids.inspect})")
    reload
  rescue StandardError => e
    Rails.logger.info "===== scrape ===== FATAL ERROR  #{e}, #{e.backtrace&.join("/n")}"
  end

  def tables_status
    hash = {}
    tables.order(:name).each do |t|
      hash[t.name] = {}
      heater_on = t.heater_on?
      sb_on = t.scoreboard_on?
      hash[t.name][:scoreboard] = ["Scoreboard is #{sb_on ? "on" : "off"}"]
      hash[t.name][:heater] = ["Heater is #{heater_on ? "on" : "off"}"]
      if t.event_id.present?
        if (DateTime.now.to_i - t.event_end.to_i) / 1.hour < 1
          end_str = (I18n.l t.event_end.utc.in_time_zone("Berlin")).split(", ").last
          start_str = (I18n.l t.event_start.utc.in_time_zone("Berlin"))
          hash[t.name][:heater] << "Event #{t.event_summary}, #{start_str} - #{end_str} by #{t.event_creator}"
        else
          t.event_id = nil
        end
      end
      sb_off_str = I18n.l t.scoreboard_off_at.utc.in_time_zone("Berlin") if t.scoreboard_off_at.present?
      sb_on_str = I18n.l t.scoreboard_on_at.utc.in_time_zone("Berlin") if t.scoreboard_on_at.present?
      if sb_on
        if sb_on_str && sb_off_str.blank?
          hash[t.name][:scoreboard] << "Scoreboard on at #{sb_on_str}"
        elsif sb_on_str && sb_off_str
          hash[t.name][:scoreboard] << "Inconsistence: Scoreboard off at #{sb_off_str} but is on now!"
          hash[t.name][:scoreboard] << "  Pgm assumes Scoreboard switched on at #{sb_on_str}"
          hash[t.name][:scoreboard] << "  Pgm assumes Scoreboard switched off at #{sb_off_str}"
        end
      elsif sb_on_str
        hash[t.name][:scoreboard] << "Scoreboard switched off at #{sb_off_str}"
      end

      on_str = I18n.l t.heater_switched_on_at.utc.in_time_zone("Berlin") if t.heater_switched_on_at.present?
      off_str = I18n.l t.heater_switched_off_at.utc.in_time_zone("Berlin") if t.heater_switched_off_at.present?
      if heater_on
        if on_str && off_str.blank?
          hash[t.name][:heater] << "Heater on by Program at #{on_str}, reason: #{t.heater_off_reason}"
        elsif on_str && off_str
          hash[t.name][:heater] << "Inconsistence: Heater switched off by Program at #{off_str} but is on now!, \
Off Reason was: #{t.heater_off_reason}"
          hash[t.name][:heater] << "  Pgm assumes Heater switched on at #{on_str}, reason: #{t.heater_on_reason}"
          hash[t.name][:heater] << "  Pgm assumes Heater switched off at #{off_str}, reason: #{t.heater_off_reason}"
        end
      elsif on_str && off_str.blank?
        hash[t.name][:heater] << "Inconsistence: Heater switched on by Program at #{on_str} but is off now! \
On Reason was: #{t.heater_on_reason}"
      elsif on_str && off_str
        hash[t.name][:heater] << "Heater switched off by Program at #{off_str}, Off Reason: #{t.heater_off_reason}"
      end
    end
    hash
  end

  def display_address
    "#{name}<br>#{address.split("\n").join("<br>")}".html_safe
  end

  def display_address_short
    name
  end
end
