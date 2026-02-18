# frozen_string_literal: true

# Service to translate international player names to standard English format
# Handles Korean, Vietnamese, Turkish and other non-Latin scripts
class PlayerNameTranslator
  # Known player name mappings (various scripts → English)
  PLAYER_NAMES = {
    # Korean (Hangul) → English
    '쿠드롱' => 'Caudron',
    '야스퍼스' => 'Jaspers',
    '딕 야스퍼스' => 'Dick Jaspers',
    '프레데릭 쿠드롱' => 'Frédéric Caudron',
    '토르비욘 블롬달' => 'Torbjörn Blomdahl',
    '다니엘 산체스' => 'Daniel Sanchez',
    '마르코 자네티' => 'Marco Zanetti',
    '에디 메르크스' => 'Eddy Merckx',
    '롤랑 포르톰' => 'Roland Forthomme',
    '사메 시돔' => 'Sameh Sidhom',
    '글렌 호프만' => 'Glenn Hofman',
    '니코스' => 'Nikos',
    '데이브' => 'Dave',
    
    # Turkish → English
    'Tayfun Taşdemir' => 'Tayfun Tasdemir',
    'Murat Naci Çoklu' => 'Murat Naci Coklu',
    
    # Vietnamese → English (if needed)
    'Trần Quyết Chiến' => 'Tran Quyet Chien',
    'Nguyễn' => 'Nguyen',
    
    # Common variations/nicknames
    'Dani' => 'Daniel',
    'Freddy' => 'Frédéric',
    'Marco Z' => 'Marco Zanetti'
  }.freeze

  # Famous players for context-aware translation
  FAMOUS_PLAYERS = [
    'Dick Jaspers', 'Frédéric Caudron', 'Torbjörn Blomdahl', 'Daniel Sanchez',
    'Marco Zanetti', 'Eddy Merckx', 'Dani Sanchez', 'Semih Sayginer',
    'Tayfun Tasdemir', 'Roland Forthomme', 'Sameh Sidhom', 'Glenn Hofman',
    'Nikos Polychronopoulos', 'Dave Christiani', 'Javier Palazon',
    'Martin Horn', 'Filipos Kasidokostas', 'Rui Costa', 'Murat Coklu',
    'Haeng-Jik Kim', 'Myung-Woo Cho', 'Sung-Won Choi'
  ].freeze

  def initialize
    @translated_cache = {}
  end

  # Translate player name from any script to English
  def translate(name)
    return nil if name.blank?
    
    # Check cache first
    return @translated_cache[name] if @translated_cache.key?(name)
    
    # Direct mapping
    translated = PLAYER_NAMES[name]
    
    # If not found, try fuzzy matching with famous players
    unless translated
      translated = fuzzy_match(name)
    end
    
    # Cache and return
    @translated_cache[name] = translated || name
    translated || name
  end

  # Translate array of names
  def translate_array(names)
    return [] if names.blank?
    names.map { |name| translate(name) }
  end

  # Build match string from names
  def build_match_string(names)
    return nil if names.blank? || names.size < 2
    
    translated = translate_array(names)
    "#{translated[0]} vs #{translated[1]}"
  end

  private

  # Fuzzy match against famous players (in case of typos or variations)
  def fuzzy_match(name)
    return nil if name.blank?
    
    # Simple substring matching for now
    name_normalized = normalize_name(name)
    
    FAMOUS_PLAYERS.find do |famous|
      famous_normalized = normalize_name(famous)
      # Check if names are similar (contains or very close)
      famous_normalized.include?(name_normalized) || 
        name_normalized.include?(famous_normalized) ||
        levenshtein_distance(name_normalized, famous_normalized) < 3
    end
  end

  # Normalize name for comparison
  def normalize_name(name)
    name.to_s.downcase.gsub(/[^a-z0-9]/, '')
  end

  # Simple Levenshtein distance for fuzzy matching
  def levenshtein_distance(str1, str2)
    matrix = Array.new(str1.length + 1) { Array.new(str2.length + 1) }
    
    (0..str1.length).each { |i| matrix[i][0] = i }
    (0..str2.length).each { |j| matrix[0][j] = j }
    
    (1..str1.length).each do |i|
      (1..str2.length).each do |j|
        cost = str1[i - 1] == str2[j - 1] ? 0 : 1
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost
        ].min
      end
    end
    
    matrix[str1.length][str2.length]
  end
end
