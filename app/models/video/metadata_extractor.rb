# frozen_string_literal: true

# PORO for extracting structured metadata from video titles and descriptions.
#
# Strategy: Regex-first (D-09). Known patterns from GAME_TYPE_MAPPINGS,
# WORLD_CUP_TOP_32, and tournament type keywords are checked first.
# Falls back to AI extraction (GPT-4) only when regex returns empty AND
# ai_extraction_enabled is explicitly set to true (D-10).
#
# Threat T-27-01: All patterns use simple anchored regex — no user-controlled
# regex input and no catastrophic backtracking.
# Threat T-27-02: AI fallback guarded by ai_extraction_enabled flag; default false.
class Video::MetadataExtractor
  ROUND_PATTERNS = Umb::DetailsScraper::GAME_TYPE_MAPPINGS.keys.freeze

  TOURNAMENT_TYPE_PATTERNS = {
    "world_cup" => /world\s*cup/i,
    "world_championship" => /world\s*championship/i,
    "european_championship" => /european\s*championship/i,
    "masters" => /\bmasters\b/i,
    "grand_prix" => /grand\s*prix/i
  }.freeze

  attr_reader :video

  def initialize(video)
    @video = video
  end

  # Returns all extracted metadata as a hash.
  def extract_all
    {
      players: extract_players,
      round: extract_round,
      tournament_type: extract_tournament_type,
      year: extract_year
    }
  end

  # Delegates to Video#detect_player_tags — no duplicated logic.
  def extract_players
    video.detect_player_tags
  end

  # Matches round labels from Umb::DetailsScraper::GAME_TYPE_MAPPINGS keys
  # against the video title using word-boundary anchors.
  def extract_round
    text = video.title.to_s
    ROUND_PATTERNS.each do |pattern|
      return pattern if text.match?(/\b#{Regexp.escape(pattern)}\b/i)
    end
    nil
  end

  # Detects tournament type (world_cup, world_championship, european_championship, etc.)
  # from combined title + description text.
  def extract_tournament_type
    text = "#{video.title} #{video.description}".to_s
    TOURNAMENT_TYPE_PATTERNS.each do |type, regex|
      return type if text.match?(regex)
    end
    nil
  end

  # Detects a 4-digit year (2010–2029) from the video title.
  def extract_year
    match = video.title.to_s.match(/\b(20[12]\d)\b/)
    match ? match[1].to_i : nil
  end

  # Returns regex-extracted metadata; falls back to AI extraction only when
  # all regex values are blank AND ai_extraction_enabled is true.
  #
  # Threat T-27-02: ai_extraction_enabled defaults to false to prevent
  # unexpected OpenAI calls in batch/background contexts.
  def extract_with_ai_fallback(ai_extraction_enabled: false)
    result = extract_all
    if result.values.all?(&:blank?) && ai_extraction_enabled
      result = ai_extract
    end
    result
  end

  private

  # AI extraction via GPT-4o-mini for non-English or unusual titles.
  # Only called by extract_with_ai_fallback when regex returns empty.
  # Rescue guard ensures failures return empty hash without raising.
  def ai_extract
    client = OpenAI::Client.new(access_token: Rails.application.credentials.dig(:openai, :api_key))

    prompt = <<~PROMPT
      Extract structured metadata from this billiards video title.
      Return JSON with keys: players (array of uppercase surname strings),
      round (e.g. "Final", "Semi_Final", "R16", "Q"), tournament_type
      (one of: world_cup, world_championship, european_championship, masters, grand_prix),
      year (integer 4-digit year or null).
      Title: #{video.title}
    PROMPT

    response = client.chat(
      parameters: {
        model: "gpt-4o-mini",
        response_format: { type: "json_object" },
        messages: [{ role: "user", content: prompt }],
        temperature: 0.0
      }
    )

    content = response.dig("choices", 0, "message", "content")
    return empty_result if content.blank?

    parsed = JSON.parse(content)
    {
      players: Array(parsed["players"]).map(&:downcase),
      round: parsed["round"].presence,
      tournament_type: parsed["tournament_type"].presence,
      year: parsed["year"]&.to_i
    }
  rescue StandardError => e
    Rails.logger.error("Video::MetadataExtractor AI fallback failed: #{e.message}")
    empty_result
  end

  def empty_result
    { players: [], round: nil, tournament_type: nil, year: nil }
  end
end
