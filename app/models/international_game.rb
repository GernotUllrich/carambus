# frozen_string_literal: true

# InternationalGame is a STI subclass of Game
# for games from international tournaments
class InternationalGame < Game
  # Inherited from Game:
  # belongs_to :tournament
  # has_many :game_participations
  
  # Helper methods for international-specific data
  def group
    json_data['group']
  end
  
  def round
    json_data['round']
  end
  
  private
  
  def json_data
    @json_data ||= begin
      return {} if data.blank?
      data.is_a?(String) ? JSON.parse(data) : data
    rescue JSON::ParserError
      {}
    end
  end
end
