# frozen_string_literal: true

module InternationalHelper
  # Discipline groups with IDs for hierarchical filtering
  DISCIPLINE_GROUPS = {
    "3-Cushion (Dreiband)" => ["Dreiband halb", "Dreiband groß", "Dreiband klein"],
    "1-Cushion (Einband)" => ["Einband halb", "Einband groß", "Einband klein"],
    "Straight Rail (Freie Partie)" => ["Freie Partie klein", "Freie Partie groß"],
    "Cadre / Balkline" => ["Cadre 35/2", "Cadre 47/2", "Cadre 52/2", "Cadre 57/2", "Cadre 71/2"],
    "5-Pin Billards" => ["5-Pin Billards"],
    "Pool Billard" => ["Pool"],
    "Snooker" => ["Snooker"]
  }.freeze

  # World Cup Top 32 Players for video tagging
  WORLD_CUP_TOP_32 = {
    "CHO" => { full_name: "CHO Myung Woo", country: "KR", rank: 1 },
    "JASPERS" => { full_name: "Dick JASPERS", country: "NL", rank: 2 },
    "TASDEMIR" => { full_name: "Tayfun TASDEMIR", country: "TR", rank: 3 },
    "MERCKX" => { full_name: "Eddy MERCKX", country: "BE", rank: 4 },
    "ZANETTI" => { full_name: "Marco ZANETTI", country: "IT", rank: 5 },
    "SIDHOM" => { full_name: "Sameh SIDHOM", country: "EG", rank: 6 },
    "KARAKURT" => { full_name: "Berkay KARAKURT", country: "TR", rank: 7 },
    "HORN" => { full_name: "Martin HORN", country: "DE", rank: 8 },
    "KIM" => { full_name: "KIM Haeng Jik", country: "KR", rank: 9 },
    "BURY" => { full_name: "Jeremy BURY", country: "FR", rank: 10 },
    "TRAN" => { full_name: "TRAN Quyet Chien", country: "VN", rank: 11 },
    "HOFMAN" => { full_name: "Glenn HOFMAN", country: "NL", rank: 12 },
    "HEO" => { full_name: "HEO Jung Han", country: "KR", rank: 14 },
    "CEULEMANS" => { full_name: "Peter CEULEMANS", country: "BE", rank: 15 },
    "LEGAZPI" => { full_name: "Ruben LEGAZPI", country: "ES", rank: 16 },
    "KIRAZ" => { full_name: "Tolgahan KIRAZ", country: "TR", rank: 17 },
    "CAUDRON" => { full_name: "Frederic CAUDRON", country: "BE", rank: 18 },
    "BAO" => { full_name: "BAO Phuong Vinh", country: "VN", rank: 19 },
    "JIMENEZ" => { full_name: "Sergio JIMENEZ", country: "ES", rank: 20 },
    "HWANG" => { full_name: "HWANG Bong Joo", country: "KR", rank: 21 },
    "SALMAN" => { full_name: "Gokhan SALMAN", country: "TR", rank: 22 },
    "THAI" => { full_name: "THAI Hong Chiem", country: "VN", rank: 23 },
    # 'CHA' => { full_name: 'CHA Myeong Jong', country: 'KR', rank: 24 }, # Disabled: too many false positives (Championship, etc.)
    "POLYCHRONOPOULOS" => { full_name: "Nikos POLYCHRONOPOULOS", country: "GR", rank: 25 },
    "FORTHOMME" => { full_name: "Roland FORTHOMME", country: "BE", rank: 26 },
    "DAO" => { full_name: "DAO Van Ly", country: "VN", rank: 27 },
    "UYMAZ" => { full_name: "Birol UYMAZ", country: "TR", rank: 28 },
    "KANG" => { full_name: "KANG Ja In", country: "KR", rank: 30 },
    "COSTA" => { full_name: "Rui Manuel COSTA", country: "PT", rank: 31 },
    "BLOMDAHL" => { full_name: "Torbjorn BLOMDAHL", country: "SE", rank: 32 },

    # Weitere World-Cup-3C-Halbfinalisten (aus geparsten KO-Daten ermittelt).
    # Ohne aktuelles Weltranking, daher rank: nil. Nur eindeutige Nachnamen —
    # kurze/häufige (NGUYEN, CHA, SEO, NGO) bewusst ausgelassen, da der
    # Substring-Match in detect_player_tags sonst zu viele Fehltreffer erzeugt.
    "SANCHEZ" => { full_name: "Daniel SANCHEZ", country: "ES", rank: nil },
    "SAYGINER" => { full_name: "Semih SAYGINER", country: "TR", rank: nil },
    "COKLU" => { full_name: "Murat Naci COKLU", country: "TR", rank: nil },
    "CENET" => { full_name: "Lütfi CENET", country: "TR", rank: nil },
    "HASHAS" => { full_name: "Burak HASHAS", country: "TR", rank: nil },
    "DE BRUIJN" => { full_name: "Jean Paul DE BRUIJN", country: "NL", rank: nil },
    "PALAZON" => { full_name: "Javier PALAZON", country: "ES", rank: nil },
    "MONTES" => { full_name: "Antonio MONTES", country: "ES", rank: nil },
    "MORALES" => { full_name: "Robinson MORALES", country: "CO", rank: nil },
    "MARECHAL" => { full_name: "Gwendal MARECHAL", country: "FR", rank: nil },
    "KASIDOKOSTAS" => { full_name: "Filipos KASIDOKOSTAS", country: "GR", rank: nil },
    "JEONG" => { full_name: "JEONG Ye Sung", country: "KR", rank: nil }
  }.freeze

  # Wandelt einen ISO-3166-1-alpha-2-Ländercode ("KR", "NL") in ein Flaggen-Emoji.
  # Gibt nil zurück, wenn kein gültiger 2-Buchstaben-Code vorliegt.
  def country_flag_emoji(code)
    return nil if code.blank?

    cc = code.to_s.strip.upcase
    return nil unless cc.match?(/\A[A-Z]{2}\z/)

    cc.codepoints.map { |cp| (cp - 65 + 0x1F1E6) }.pack("U*")
  end

  # Get all discipline IDs for a group name
  def self.discipline_ids_for_group(group_name)
    discipline_names = DISCIPLINE_GROUPS[group_name]
    return [] if discipline_names.blank?

    Discipline.where(name: discipline_names).pluck(:id)
  end

  # Grouped disciplines for select dropdown (flat list for now)
  def grouped_disciplines_for_select
    groups = []

    DISCIPLINE_GROUPS.each do |group_name, discipline_names|
      disciplines = Discipline.where(name: discipline_names).pluck(:name, :id)
      next if disciplines.empty?

      # Add group option (special value: "group:GroupName")
      group_value = "group:#{group_name}"
      groups << [group_name, [[group_name + " (All)", group_value]]]

      # Add individual disciplines under group
      disciplines.each do |name, id|
        groups.last[1] << ["  → #{name}", id]
      end
    end

    groups
  end

  # Helper to get discipline IDs by names
  def discipline_ids_by_names(names)
    Discipline.where(name: names).pluck(:name, :id).map { |name, id| { name: name, id: id } }
  end

  # Video tag groups for hierarchical filtering
  VIDEO_TAG_GROUPS = {
    "Content Type" => {
      tags: %w[full_game shot_of_the_day high_run training highlights],
      icon: "🎬"
    },
    "Top Players" => {
      tags: WORLD_CUP_TOP_32.keys.sort,
      icon: "⭐",
      grouped_by_country: true
    },
    "Quality" => {
      tags: %w[hd 4k slow_motion multi_angle],
      icon: "🎥"
    }
  }.freeze

  # Get player tags grouped by country
  def self.player_tags_by_country
    grouped = {}
    WORLD_CUP_TOP_32.each do |tag, info|
      country = info[:country]
      grouped[country] ||= []
      grouped[country] << { tag: tag, name: info[:full_name], rank: info[:rank] }
    end
    # rank kann nil sein (Halbfinalisten ohne Weltranking) → ans Ende sortieren
    grouped.transform_values { |players| players.sort_by { |p| p[:rank] || Float::INFINITY } }
  end

  # Badge colors for tournament types
  def tournament_type_badge_class(type)
    case type&.to_s
    when "world_cup"
      "bg-purple-100 text-purple-800"
    when "world_championship"
      "bg-red-100 text-red-800"
    when "european_championship"
      "bg-blue-100 text-blue-800"
    when "masters"
      "bg-yellow-100 text-yellow-800"
    when "grand_prix"
      "bg-green-100 text-green-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end

  # Badge colors for video content types
  def video_tag_badge_class(tag)
    case tag.to_s.downcase
    when "full_game"
      "bg-blue-100 text-blue-800"
    when "shot_of_the_day"
      "bg-yellow-100 text-yellow-800"
    when "high_run"
      "bg-red-100 text-red-800"
    when "training"
      "bg-green-100 text-green-800"
    when "highlights"
      "bg-purple-100 text-purple-800"
    when "hd", "4k"
      "bg-indigo-100 text-indigo-800"
    else
      if tag.to_s.start_with?("player_")
        "bg-yellow-100 text-yellow-800"
      else
        "bg-gray-100 text-gray-800"
      end
    end
  end

  # Display label for video tag
  def format_video_tag(tag)
    tag_str = tag.to_s
    if tag_str.start_with?("player_")
      player_id = tag_str.split("_").last
      @_player_cache ||= {}
      @_player_cache[player_id] ||= Player.find_by(id: player_id)&.fl_name || "Unknown Player"
    else
      tag_str.titleize
    end
  end
end
