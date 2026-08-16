# frozen_string_literal: true

require "text"

# ApplicationService for confidence-scored video-to-tournament matching.
#
# Scores each unassigned Video against InternationalTournament records using
# three weighted signals:
#   - Date overlap    (0.40): video.published_at within tournament date range (+3 day grace)
#   - Player intersection (0.35): Anteil der im Video erkannten Spieler, die im
#     Turnier antreten (Containment — NICHT Jaccard, siehe player_intersection_score)
#   - Title similarity (0.25): normalized Levenshtein distance
#
# Auto-assigns videos scoring >= CONFIDENCE_THRESHOLD (0.75). D-02: no review
# tier implemented — auto-assign only.
#
# Usage:
#   Video::TournamentMatcher.call
#   Video::TournamentMatcher.call(video_scope: Video.where(id: [1,2,3]))
class Video::TournamentMatcher < ApplicationService
  CONFIDENCE_THRESHOLD = 0.75
  DATE_WEIGHT = 0.40
  PLAYER_WEIGHT = 0.35
  TITLE_WEIGHT = 0.25

  # Sportarten, die es bei der UMB (Karambol) nicht gibt. Nennt ein Videotitel
  # eine davon, gehoert das Video zu einem anderen Ereignis — egal wie gut Datum
  # und Spielernamen passen.
  #
  # Anlass: die Serie "Panamericano de Pool Bola 10 | Mesa 2..5" hing an den
  # "World Championships Artistic", allein ueber den Tag `tran`. Insgesamt 60 der
  # 2.239 automatisch zugeordneten Videos nannten Pool, Snooker oder 9-Ball.
  FOREIGN_DISCIPLINE_PATTERN = /
    \b(
      pool | snooker | carom\s*pool |
      bola\s*\d+ | \d+\s*-?\s*ball | billar\s+de\s+bolas
    )\b
  /xi

  def initialize(kwargs = {})
    @video_scope = kwargs[:video_scope] || Video.unassigned
    @results = []
  end

  def call
    assigned = 0
    skipped = 0

    tournaments = InternationalTournament.where("date >= ?", 2.years.ago).includes(seedings: :player)

    @video_scope.find_each do |video|
      # Skip already-assigned videos (videoable_id set)
      if video.videoable_id.present?
        skipped += 1
        next
      end

      extractor = Video::MetadataExtractor.new(video)
      metadata = extractor.extract_all

      best_tournament = nil
      best_score = 0.0

      tournaments.each do |tournament|
        score = confidence_score(video, tournament, metadata)
        if score > best_score
          best_score = score
          best_tournament = tournament
        end
      end

      if best_score >= CONFIDENCE_THRESHOLD && best_tournament
        video.update(videoable: best_tournament)
        assigned += 1
        @results << {video_id: video.id, tournament_id: best_tournament.id, confidence: best_score}
      else
        skipped += 1
      end
    end

    {assigned_count: assigned, skipped_count: skipped, results: @results}
  end

  # Public so tests can call it directly.
  def confidence_score(video, tournament, metadata = nil)
    metadata ||= Video::MetadataExtractor.new(video).extract_all
    return 0.0 if disqualified?(video, tournament)

    score = 0.0
    score += date_overlap_score(video, tournament) * DATE_WEIGHT
    score += player_intersection_score(metadata[:players], tournament) * PLAYER_WEIGHT
    score += title_similarity_score(video.title, tournament.title) * TITLE_WEIGHT
    score.clamp(0.0, 1.0)
  end

  private

  # Returns 1.0 if video.published_at falls within the tournament date range
  # (with a +3 day grace period after end_date). Falls back to date + 7 days
  # when end_date is nil (D-06 from context: nil end_date fallback).
  # Harte Ausschluesse, unabhaengig vom Score.
  #
  # Noetig, weil Datum (0.40) und Spieler (0.35) zusammen exakt die Schwelle von
  # 0.75 ergeben: ein Video im Turnierfenster mit einem passenden Spielernamen
  # wird zugeordnet, OHNE dass der Titel irgendetwas beitragen muss. Der Titel
  # kann eine Fehlzuordnung also nicht verhindern, nur noch zwischen mehreren
  # Turnieren entscheiden. Diese beiden Regeln geben ihm ein Veto.
  # Quellen, die UMB-Turniere selbst uebertragen. Ihre Highlight-Clips
  # ("7-point high run! S. SIDHOM turns the tables") tragen keinen Turnierbezug
  # im Titel, sind aber trotzdem korrekt zugeordnet — fuer sie entfaellt die
  # Titelbezug-Pflicht.
  #
  # Der Typ trennt sauber: "Kozoom TV" (kozoom) ist der Broadcaster, waehrend
  # "Kozoom Carom" (youtube) ein Kanal mit fremden Inhalten ist (Europameister-
  # schaft, KNBB-Liga) — genau die Videos, die der Titelbezug fangen soll.
  BROADCAST_SOURCE_TYPES = %w[fivesix kozoom].freeze

  # Turniercode der offiziellen Uebertragungen: [WC2025_L32], [LBM2023_Q].
  # Kuerzel + Jahr + Runde; das Jahr muss zum Turnier passen.
  TOURNAMENT_CODE_PATTERN = /\[([A-Z]{2,6})(\d{4})_([A-Z0-9]{1,4})\]/

  # Woerter, die keinen Bezug stiften.
  TITLE_STOPWORDS = %w[the and vs von der die das und les des].freeze

  # Turnierserien neben der UMB, erkannt an Serienname + Turnierwort.
  FOREIGN_SERIES_PATTERN = /
    l?pba [^[:alpha:]]{0,3}
      (?: tour | league | championship | 팀리그 | 리그 | 챔피언십 | 월드챔피언십 )
    |
    (?: 팀리그 | 챔피언십 | 월드챔피언십 ) [^[:alpha:]]{0,3} l?pba
  /xi

  def disqualified?(video, tournament)
    foreign_discipline?(video.title) ||
      foreign_series?(video.title) ||
      conflicting_year?(video.title, tournament) ||
      missing_title_reference?(video, tournament)
  end

  # Mindest-Titelbezug: das Video muss das Turnier im Titel wenigstens
  # streifen — ueber den offiziellen Turniercode oder ein gemeinsames Wort.
  #
  # Grund: Datum (0.40) und Spieler (0.35) reissen zusammen exakt die Schwelle,
  # der Titel konnte bisher nichts verhindern. Dadurch landeten fremde
  # Veranstaltungen an UMB-Turnieren, sobald sie zeitgleich liefen und bekannte
  # Profis zeigten — Europameisterschaft, KNBB-Liga, D1 France und rund 170
  # vietnamesische Lokalturniere.
  #
  # Ausgenommen sind die Broadcaster selbst (BROADCAST_SOURCE_TYPES): ihre
  # Highlight-Clips tragen keinen Titelbezug, gehoeren aber zum Turnier.
  def missing_title_reference?(video, tournament)
    return false if broadcast_source?(video)
    return false if tournament_code_matches?(video.title, tournament)

    shared_title_words(video.title, tournament.title).empty?
  end

  def broadcast_source?(video)
    BROADCAST_SOURCE_TYPES.include?(video.international_source&.source_type)
  end

  # Ein Code belegt den Bezug nur, wenn sein Jahr zum Turnier passt.
  def tournament_code_matches?(title, tournament)
    match = title.to_s.match(TOURNAMENT_CODE_PATTERN)
    return false if match.nil? || tournament.date.blank?

    match[2].to_i == tournament.date.year
  end

  def shared_title_words(video_title, tournament_title)
    significant_words(video_title) & significant_words(tournament_title)
  end

  def significant_words(text)
    text.to_s.downcase
      .gsub(/[^[:alnum:][:space:]]/, " ")
      .split
      .reject { |w| w.size < 3 || TITLE_STOPWORDS.include?(w) }
      .uniq
  end

  # Fremde Turnierserie: die PBA ist zwar Karambol, aber ein eigenes Ligasystem
  # neben der UMB. Ihre Uebertragungen gehoeren nie zu einem UMB-Turnier.
  #
  # Entscheidend ist die Kombination aus Serienname UND Turnierwort — "PBA"
  # allein taugt nicht: in vietnamesischen Videos ist es ein SPIELER-Suffix
  # ("TY NGUYEN PBA vs ...") und bezeichnet dort einen Profi, nicht das Event.
  # Ein Ausschluss auf das blosse Kuerzel wuerde also aus dem falschen Grund
  # greifen.
  #
  # Koreanische Turnierwoerter muessen mit rein: die drei real fehlzugeordneten
  # Videos hiessen "PBA 월드챔피언십" (World Championship), "PBA팀리그"
  # (Teamliga) und "PBA챔피언십". Koreanisch setzt keine Leerzeichen zwischen
  # Serie und Turnierwort, deshalb keine Wortgrenzen im Muster.
  def foreign_series?(title)
    title.to_s.match?(FOREIGN_SERIES_PATTERN)
  end

  def foreign_discipline?(title)
    title.to_s.match?(FOREIGN_DISCIPLINE_PATTERN)
  end

  # Nennt der Videotitel Jahreszahlen und ist das Turnierjahr nicht darunter,
  # stammt das Video von einem anderen Ereignis — typisch fuer Re-Uploads, die
  # zufaellig waehrend eines laufenden Turniers hochgeladen werden
  # ("3-Cushion Lausanne Masters 2019 Final" landete am World Cup 2024).
  #
  # Saison-Schreibweisen zaehlen mit BEIDEN Jahren ("2025-26" deckt 2025 und
  # 2026 ab), sonst wuerde eine korrekte Zuordnung faelschlich verworfen.
  def conflicting_year?(title, tournament)
    return false if tournament.date.blank?

    years = years_in(title)
    years.any? && years.exclude?(tournament.date.year)
  end

  def years_in(title)
    text = title.to_s
    years = text.scan(/\b(20\d{2})\b/).flatten.map(&:to_i)
    # Saison-Spannen: "2025-26", "2025/26", "2025-2026"
    text.scan(%r{\b(20\d{2})\s*[-/]\s*(\d{2}|20\d{2})\b}).each do |from, to|
      start_year = from.to_i
      years << start_year
      years << ((to.length == 2) ? (start_year / 100 * 100) + to.to_i : to.to_i)
    end
    years.uniq
  end

  def date_overlap_score(video, tournament)
    return 0.0 if video.published_at.blank? || tournament.date.blank?

    end_date = tournament.end_date || (tournament.date + 7.days)
    range = tournament.date.to_date..(end_date.to_date + 3.days)
    range.cover?(video.published_at.to_date) ? 1.0 : 0.0
  end

  # Anteil der im Video erkannten Spieler, die im Turnier antreten (Containment).
  #
  # Frueher Jaccard (Schnitt/Vereinigung) — das war fuer diesen Zweck die falsche
  # Metrik: ein Video zeigt zwei bis drei Spieler, ein World-Cup-Feld hat bis zu
  # 300. Die Vereinigung wird also von der Turniergroesse dominiert, und der Wert
  # sinkt, je vollstaendiger die Teilnehmerdaten sind — ausgerechnet gute Daten
  # wurden bestraft.
  #
  # Rechnerisch war die Schwelle von 0.75 damit unerreichbar: bei zwei erkannten
  # Spielern haette das Turnier hoechstens zwei bis drei Tags haben duerfen.
  # Gemessen am World Cup 2024 (292 Seedings, 80 Videos im Zeitfenster): bester
  # Score 0.48, keine einzige Zuordnung. Mit Containment: 20 Zuordnungen, bester
  # Score 0.80 — ein Video mit "D. JASPERS vs M. ABDIN" trifft jetzt 1.0, weil
  # Jaspers tatsaechlich im Feld steht.
  #
  # Bezugsgroesse ist bewusst die VIDEO-Seite: gefragt ist "spielen die gezeigten
  # Spieler in diesem Turnier?", nicht "wie gross ist die Ueberlappung beider
  # Mengen?".
  def player_intersection_score(detected_tags, tournament)
    return 0.0 if detected_tags.blank?

    seeded_tags = tournament_player_tags(tournament)
    return 0.0 if seeded_tags.empty?

    detected = detected_tags.uniq
    (detected & seeded_tags).size.to_f / detected.size
  end

  # Maps tournament seedings to lowercase WORLD_CUP_TOP_32 tag keys.
  def tournament_player_tags(tournament)
    tournament.seedings.map do |seeding|
      lastname = seeding.player&.lastname&.upcase
      next unless lastname

      InternationalHelper::WORLD_CUP_TOP_32.keys.find { |tag| lastname.include?(tag) }
    end.compact.map(&:downcase)
  end

  # Normalized Levenshtein similarity: 1.0 - (distance / max_length).
  def title_similarity_score(str1, str2)
    return 0.0 if str1.blank? || str2.blank?

    s1 = str1.to_s.downcase.strip
    s2 = str2.to_s.downcase.strip
    return 1.0 if s1 == s2

    max_length = [s1.length, s2.length].max
    return 0.0 if max_length == 0

    distance = Text::Levenshtein.distance(s1, s2)
    1.0 - (distance.to_f / max_length)
  end
end
