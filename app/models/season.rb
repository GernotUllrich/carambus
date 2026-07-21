# == Schema Information
#
# Table name: seasons
#
#  id         :bigint           not null, primary key
#  data       :text
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  ba_id      :integer
#
# Indexes
#
#  index_seasons_on_ba_id  (ba_id) UNIQUE
#  index_seasons_on_name   (name) UNIQUE
#
class Season < ApplicationRecord
  include LocalProtector
  has_many :tournaments
  has_many :season_participations
  has_many :player_rankings
  has_many :season_ccs
  has_many :leagues

  @year = (Date.today - 6.month).year
  @current_season = Season.find_by_name("#{@year}/#{@year + 1}")

  REFLECTION_KEYS = %w[tournaments season_participations]
  MAX_BA_SEASON = "2021/2022"

  # Verlässlicher Recency-Anker: NUR der Name im Format "yyyy/yyyy+1" ist verlässlich.
  # id und ba_id sind durch das Scrapen internationaler Turniere verrutscht; Platzhalter-/
  # Fremd-Saisons ("Unknown Season", leere Zukunfts-Saisons) haben ba_id = nil und ungültige
  # Namen. Recency-Logik muss daher über den Namen laufen, nicht über id/ba_id.
  VALID_NAME_REGEX = %r{\A\d{4}/\d{4}\z}
  VALID_NAME_SQL = "seasons.name ~ '^[0-9]{4}/[0-9]{4}$'"

  # Nur Saisons mit gültigem Namen (schließt "Unknown Season" & Fremd-Platzhalter aus).
  scope :with_valid_name, -> { where(Arel.sql(VALID_NAME_SQL)) }

  # Die neuesten `limit` Saisons mit gültigem Namen bis einschließlich `up_to`
  # (Default: current_season), chronologisch aufsteigend (älteste zuerst).
  # Ersetzt das unzuverlässige `where("id <= ?", current.id).order(id: :desc).limit(n).reverse`.
  def self.recent_valid(limit, up_to: current_season)
    rel = with_valid_name.order(name: :desc)
    rel = rel.where("seasons.name <= ?", up_to.name) if up_to&.name
    rel.limit(limit).to_a.reverse
  end

  def self.current_season
    if (Date.today - 6.month).year != @year
      @year = (Date.today - 6.month).year
      @current_season = Season.find_by_name("#{@year}/#{@year + 1}")
      unless @current_season.present?
        Season.update_seasons
        @current_season = Season.find_by_name("#{@year}/#{@year + 1}")
      end
    end
    @current_season
  end

  def self.season_from_date(date)
    year = (date - 6.month).year
    Season.find_by_name("#{year}/#{year + 1}")
  end

  def self.update_seasons
    (2009..(Date.today.year)).each_with_index do |year, ix|
      Season.find_by_name("#{year}/#{year + 1}") || Season.create(ba_id: ix + 1, name: "#{year}/#{year + 1}")
    end
  end

  def scrape_single_tournaments_public_cc(opts = {})
    (Region::SHORTNAMES_ROOF_ORGANIZATION + Region::SHORTNAMES_CARAMBUS_USERS + Region::SHORTNAMES_OTHERS).each do |shortname|
      #next unless shortname == "NBV"
      region = Region.find_by_shortname(shortname)
      region&.scrape_single_tournament_public(self, opts)
    end
  end

  def previous
    @previous || adjacent_season(-1)
  end

  def includes_date(date)
    @start_date ||= Date.parse("#{name.split("/")[0]}-07-01")
    @end_date ||= Date.parse("#{name.split("/")[1]}-06-30")
    date.is_a?(Date) && date >= @start_date && date <= @end_date
  end

  def next_season
    @pnext_season || adjacent_season(1)
  end

  # H28: seasons/index zeigt nur den (selbsterklaerenden) Namen — keine Subzeile.
  # Verhindert den Leak von `data` (Scraper-Freitext) bzw. `ba_id` (interne Sync-ID) in
  # die oeffentliche Liste. Leerer Override wird vom Index-Partial autoritativ behandelt.
  def scaffold_row_subtitle
    nil
  end

  def copy_season_participations_to_next_season
    new_season = next_season
    unless new_season.season_participations.present?
      season_participations.each do |sp|
        sp_new = SeasonParticipation.create(
          player_id: sp.player_id,
          season_id: new_season.id,
          club_id: sp.club_id,
          status: "temporary",
          region_id: sp.region_id,
          global_context: false
        )
      end
    end
  end

  private

  # Nachbar-Saison verlässlich über den Namen ("yyyy/yyyy+1" um `delta` Jahre versetzt);
  # nur wenn der eigene Name gültig ist. Fallback auf ba_id (nil-sicher), wenn kein
  # name-basierter Treffer existiert — deckt Alt-/Randfälle ab.
  def adjacent_season(delta)
    if VALID_NAME_REGEX.match?(name.to_s)
      start_year = name[0, 4].to_i + delta
      found = Season.find_by_name("#{start_year}/#{start_year + 1}")
      return found if found
    end
    ba_id && Season.find_by_ba_id(ba_id + delta)
  end
end
