# frozen_string_literal: true

# == Schema Information
#
# Table name: abandoned_tournament_ccs
#
#  id                      :bigint           not null, primary key
#  cc_id                   :integer          not null
#  context                 :string           not null
#  region_shortname        :string           not null
#  season_name             :string           not null
#  tournament_name         :string           not null
#  abandoned_at            :datetime         not null
#  reason                  :text
#  replaced_by_cc_id       :integer
#  replaced_by_tournament_id :integer
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
# Indexes
#
#  index_abandoned_tournament_ccs_on_abandoned_at  (abandoned_at)
#  index_abandoned_tournament_ccs_on_cc_id_and_context  (cc_id,context) UNIQUE
#  index_abandoned_tournament_ccs_on_region_season_tournament  (region_shortname,season_name,tournament_name)
#
class AbandonedTournamentCc < ApplicationRecord
  include LocalProtector

  validates :cc_id, presence: true, uniqueness: { scope: :context }
  validates :context, presence: true
  validates :region_shortname, presence: true
  validates :season_name, presence: true
  validates :tournament_name, presence: true
  validates :abandoned_at, presence: true

  belongs_to :replaced_by_tournament, class_name: 'Tournament', optional: true

  scope :for_region_season, ->(region_shortname, season_name) {
    where(region_shortname: region_shortname, season_name: season_name)
  }

  scope :recent, ->(days = 30) {
    where('abandoned_at >= ?', days.days.ago)
  }

  def self.is_abandoned?(cc_id, context)
    exists?(cc_id: cc_id, context: context)
  end

  def self.mark_abandoned!(cc_id, context, region_shortname, season_name, tournament_name, reason: nil, replaced_by_cc_id: nil, replaced_by_tournament_id: nil)
    create!(
      cc_id: cc_id,
      context: context,
      region_shortname: region_shortname,
      season_name: season_name,
      tournament_name: tournament_name,
      abandoned_at: Time.current,
      reason: reason,
      replaced_by_cc_id: replaced_by_cc_id,
      replaced_by_tournament_id: replaced_by_tournament_id
    )
  rescue ActiveRecord::RecordNotUnique
    # Already marked as abandoned, update the record
    record = find_by(cc_id: cc_id, context: context)
    record.update!(
      region_shortname: region_shortname,
      season_name: season_name,
      tournament_name: tournament_name,
      abandoned_at: Time.current,
      reason: reason,
      replaced_by_cc_id: replaced_by_cc_id,
      replaced_by_tournament_id: replaced_by_tournament_id
    )
  end

  def self.find_duplicate_tournaments(region_shortname, season_name, tournament_name)
    where(
      region_shortname: region_shortname,
      season_name: season_name,
      tournament_name: tournament_name
    ).order(:abandoned_at)
  end

  def self.cleanup_old_records(days = 365)
    where('abandoned_at < ?', days.days.ago).destroy_all
  end

  def self.analyze_duplicates(region_shortname, season_name)
    region = Region.find_by_shortname(region_shortname)
    season = Season.find_by_name(season_name)
    
    return "Region or season not found" unless region && season
    
    url = region.public_cc_url_base
    return "No public CC URL for region" unless url.present?
    
    einzel_url = url + "sb_meisterschaft.php?eps=100000&s=#{season.name}"
    uri = URI(einzel_url)
    einzel_html = Net::HTTP.get(uri)
    einzel_doc = Nokogiri::HTML(einzel_html)
    
    tournament_groups = {}
    einzel_doc.css("article table.silver").andand[1].andand.css("tr").to_a[2..].to_a.each do |tr|
      tournament_link = tr.css("a")[0].attributes["href"].value
      params = tournament_link.split("p=")[1].split("-")
      cc_id = params[3].to_i
      name = tr.css("a")[0].text.strip
      
      tournament_groups[name] ||= []
      tournament_groups[name] << {
        cc_id: cc_id,
        link: tournament_link,
        name: name
      }
    end
    
    duplicates = tournament_groups.select { |name, tournaments| tournaments.length > 1 }
    
    if duplicates.empty?
      "No duplicates found for #{region_shortname} #{season_name}"
    else
      result = "Duplicates found for #{region_shortname} #{season_name}:\n"
      duplicates.each do |name, tournaments|
        result += "  '#{name}':\n"
        tournaments.each do |t|
          # Do partial scraping to check for seedings and games
          has_seedings, has_games = region.check_tournament_status(t[:link], t[:cc_id])
          is_abandoned = AbandonedTournamentCcSimple.is_abandoned?(t[:cc_id], region.region_cc.context)
          
          result += "    cc_id: #{t[:cc_id]}, has_seedings: #{has_seedings}, has_games: #{has_games}, abandoned: #{is_abandoned}\n"
        end
      end
      result
    end
  rescue StandardError => e
    "Error analyzing duplicates: #{e.message}"
  end
end 