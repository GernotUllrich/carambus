# frozen_string_literal: true

require "net/http"
require "json"

# Client for the billiards.sooplive.com JSON API.
# Discovered in Phase 24 — undocumented tournament/match/results endpoints.
#
# Endpoints covered (D-03):
#   GET /api/games                          — tournament list
#   GET /api/game/{game_no}/matches         — match list with replay_no
#   GET /api/game/{game_no}/results         — tournament rankings
#
# VOD linking (VIDEO-02 / D-05):
#   replay_no from match data → vod.sooplive.com/player/{replay_no}
#   link_match_vods finds pre-existing Video records and assigns to InternationalGame.
#
# Kozoom cross-referencing (VIDEO-03):
#   cross_reference_kozoom_videos matches Video.json_data["eventId"] to
#   InternationalTournament.external_id for Kozoom-sourced records.
class SoopliveBilliardsClient
  BILLIARDS_BASE_URL = "https://billiards.sooplive.com"
  VOD_BASE_URL = "https://vod.sooplive.com/player"

  # Fetch all tournaments from /api/games
  def fetch_games
    fetch_json("#{BILLIARDS_BASE_URL}/api/games")
  end

  # Fetch match list for a tournament from /api/game/{game_no}/matches
  # Each match contains replay_no, match_no, record_yn, player names.
  def fetch_matches(game_no)
    fetch_json("#{BILLIARDS_BASE_URL}/api/game/#{game_no}/matches")
  end

  # Fetch result rankings for a tournament from /api/game/{game_no}/results
  def fetch_results(game_no)
    fetch_json("#{BILLIARDS_BASE_URL}/api/game/#{game_no}/results")
  end

  # Build a VOD URL from a replay_no (D-05).
  # Per Pitfall 4: caller must ensure replay_no != 0 before using the URL.
  def self.vod_url(replay_no)
    "#{VOD_BASE_URL}/#{replay_no}"
  end

  # Link SoopLive match VODs to an InternationalGame via replay_no (VIDEO-02).
  #
  # Looks up pre-existing Video records by external_id == replay_no.to_s
  # and assigns unassigned ones to the provided international_game.
  # New Video record creation is OUT OF SCOPE — this method only links existing records.
  #
  # Per Pitfall 4: skips matches where replay_no == 0 (no VOD available).
  # Skips matches where record_yn != "Y" (not recorded).
  # Skips videos already assigned to another videoable.
  #
  # Returns array of { video_id:, replay_no: } for each video linked.
  def link_match_vods(game_no, international_game: nil)
    matches = fetch_matches(game_no)
    return [] if matches.blank?

    fivesix_source = InternationalSource.find_by(source_type: InternationalSource::FIVESIX)
    return [] unless fivesix_source

    linked = []

    matches.each do |match|
      replay_no = match["replay_no"].to_i

      # Per Pitfall 4: replay_no == 0 means no VOD
      next if replay_no == 0

      # Only link recorded matches
      next unless match["record_yn"] == "Y"

      video = Video.find_by(external_id: replay_no.to_s, international_source: fivesix_source)
      next unless video
      next if video.videoable_id.present?  # Already assigned — skip

      if international_game
        video.update(videoable: international_game)
        linked << {video_id: video.id, replay_no: replay_no}
      end
    end

    linked
  end

  # Cross-reference Kozoom videos to InternationalTournaments via eventId (VIDEO-03).
  #
  # Finds unassigned Kozoom Video records that have json_data["eventId"] set,
  # then matches them to InternationalTournament.external_id for the Kozoom source.
  #
  # Per Pitfall 2: query scoped with data->>'eventId' IS NOT NULL guard.
  # Gracefully returns { assigned_count: 0 } if no Kozoom source exists.
  #
  # Returns { assigned_count: N }
  def self.cross_reference_kozoom_videos
    kozoom_source = InternationalSource.find_by(source_type: InternationalSource::KOZOOM)
    return {assigned_count: 0} unless kozoom_source

    assigned = 0

    Video.where(international_source: kozoom_source)
      .unassigned
      .where("data->>'eventId' IS NOT NULL")
      .find_each do |video|
      event_id = video.json_data["eventId"]
      next if event_id.blank?

      tournament = InternationalTournament
        .where(international_source: kozoom_source)
        .find_by(external_id: event_id.to_s)

      next unless tournament

      video.update(videoable: tournament)
      assigned += 1
    end

    {assigned_count: assigned}
  end

  private

  def fetch_json(url)
    uri = URI(url)
    request = Net::HTTP::Get.new(uri)
    request["Accept"] = "application/json"
    request["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"

    response = Net::HTTP.start(uri.hostname, uri.port,
      use_ssl: true,
      verify_mode: ssl_verify_mode) do |http|
      http.open_timeout = 10
      http.read_timeout = 30
      http.request(request)
    end

    JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
  rescue => e
    Rails.logger.error "[SoopliveBilliardsClient] #{e.class}: #{e.message}"
    nil
  end

  def ssl_verify_mode
    Rails.env.production? ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
  end
end
