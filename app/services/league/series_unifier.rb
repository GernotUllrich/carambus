# frozen_string_literal: true

# Vereinheitlicht Ligen-Reihen: dieselbe Liga einer Region und Disziplin heißt über die Saisons
# verschieden ("Bezirksliga" → "Bezirksliga Pool" → "Bezirksliga - Pool"), die Staffel steht mal als
# "Staffel A", mal als "A", mal im Namen ("Verbandsliga - Mitte" ohne staffel_text).
#
# Regeln:
# - Reihe = gleiche Region (organizer), gleiche Disziplin, gleicher League.series_name_key.
# - Staffel im Namen: Liga ohne Staffel, deren Schlüssel "<Reihe> <x>" ist, wobei x eine Staffel
#   derselben Reihe ist → wandert in diese Reihe, x wird staffel_text.
# - Alle Ligen der Reihe bekommen den Namen der jüngsten Saison; jede Staffel die Schreibweise der
#   jüngsten Saison, in der sie vorkommt. "Nord" und "A" sind verschiedene Staffeln (kein Mapping).
# - synonyms: alle Namen der Reihe, der eigene Ursprungsname zuerst (bleibt bei Wiederholung erhalten).
# - Zwei Ligen, die nach der Änderung in derselben Saison gleich hießen (Name + Staffel), werden
#   NICHT angefasst und als Dublette gemeldet. Ebenso gemeldet: Saisons, in denen die Reihe eine Liga
#   ohne und eine mit Staffel hat (Verdacht BA/CC-Doppelanlage beim Quellwechsel).
#
# Schreibt nur mit armed: true, broadcast-frei, über save! (PaperTrail-Version → Sync an alle Server).
class League::SeriesUnifier
  Change = Struct.new(:league, :season, :old_name, :new_name, :old_staffel, :new_staffel, :old_synonyms, :synonyms, keyword_init: true) do
    def renamed? = old_name != new_name
    def restaffeled? = old_staffel.to_s != new_staffel.to_s
    def synonyms_changed? = old_synonyms.to_s != synonyms.to_s
    def changed? = renamed? || restaffeled? || synonyms_changed?
  end

  Series = Struct.new(:region, :discipline, :canonical, :changes, :duplicates, :mixed_seasons, keyword_init: true)

  attr_reader :series, :changes, :errors

  def initialize(region: nil, armed: false)
    @region = region
    @armed = armed
    @errors = []
  end

  def call
    @series = build_series
    # Vor dem Schreiben festhalten: der Bericht soll auch nach ARMED die geplanten Änderungen zeigen.
    @changes = @series.flat_map(&:changes).select(&:changed?)
    apply if @armed
    self
  end

  private

  def scope
    rel = League.where(organizer_type: "Region").where.not(discipline_id: nil)
    rel = rel.where(organizer_id: @region.id) if @region
    rel.includes(:season, :discipline, :organizer)
  end

  def build_series
    scope.to_a.group_by { |l| [l.organizer_id, l.discipline_id] }.flat_map do |_, leagues|
      series_in_bucket(leagues)
    end.compact.sort_by { |s| [s.region.shortname, s.discipline.name, s.canonical] }
  end

  def series_in_bucket(leagues)
    disc = leagues.first.discipline.name
    @reg = leagues.first.organizer
    entries = leagues.map do |l|
      {league: l, key: League.series_name_key(l.read_attribute(:name), disc), base: l.read_attribute(:name).to_s.squish,
       staffel: l.staffel_text.presence, skey: League.staffel_key(l.staffel_text, @reg), embedded: false}
    end
    groups = entries.group_by { |e| e[:key] }
    move_embedded_staffeln(groups)
    groups.values.map { |es| plan_series(es) }
  end

  # "Verbandsliga - Mitte" (ohne Staffel) → Reihe "verbandsliga", Staffel "Mitte" — nur wenn die
  # Reihe die Staffel "mitte" tatsächlich führt. Längster passender Reihenschlüssel gewinnt.
  def move_embedded_staffeln(groups)
    groups.keys.each do |key|
      movers = groups[key].select { |e| e[:skey].nil? }
      next if movers.empty?

      target = groups.keys.select { |k| k != key && key.start_with?("#{k} ") }.max_by(&:length)
      next unless target

      suffix = key.delete_prefix("#{target} ")
      skey = League.staffel_key(suffix, @reg)
      next unless groups[target].any? { |e| e[:skey] == skey }

      # Nicht verschieben, wenn die Reihe die Staffel in derselben Saison schon führt UND die Liga
      # eine eigene Reihe mit Staffeln hat: dann ist es eine eigene Liga (BLVN 2019/20 "Kreisliga OH"
      # neben "Pool Kreisliga [1 OH]", später "Kreisliga OH [2 OH]"). Ohne eigene Reihe ist es eine
      # Doppelanlage und wird verschoben, damit sie als Dublette gemeldet wird.
      if groups[key].any? { |e| e[:skey] }
        taken = groups[target].select { |e| e[:skey] == skey }.map { |e| e[:league].season_id }
        movers = movers.reject { |e| taken.include?(e[:league].season_id) }
        next if movers.empty?
      end

      movers.each do |e|
        e.merge!(skey: skey, embedded: true, base: strip_staffel(e[:base], suffix))
        groups[target] << e
      end
      groups[key] -= movers
      groups.delete(key) if groups[key].empty?
    end
  end

  def plan_series(entries)
    names = entries.map { |e| original_name(e[:league]) } | entries.flat_map { |e| e[:league].synonym_list }
    names |= entries.map { |e| e[:league].read_attribute(:name) }
    spellings = entries.reject { |e| e[:embedded] }.map { |e| e[:staffel] }.compact
    return nil if names.size < 2 && entries.none? { |e| e[:embedded] } &&
      spellings.group_by { |s| League.staffel_key(s, @reg) }.values.all? { |v| v.uniq.size < 2 }

    # Jüngster Name; bei eingebetteter Staffel der Name ohne sie ("Landesliga Staffel West" → "Landesliga").
    latest = entries.max_by { |e| e[:league].season&.name.to_s }[:league].season&.name.to_s
    canonical = entries.select { |e| e[:league].season&.name.to_s == latest }
      .map { |e| e[:base] }.tally.max_by { |n, c| [c, n] }.first
    staffel_spelling = canonical_staffeln(entries)

    changes = entries.map do |e|
      l = e[:league]
      own = original_name(l)
      Change.new(league: l, season: l.season&.name.to_s,
        old_name: l.read_attribute(:name), new_name: canonical,
        old_staffel: l.staffel_text, new_staffel: e[:skey] && staffel_spelling.fetch(e[:skey]), old_synonyms: l.synonyms,
        synonyms: (names.size > 1) ? ([own] + (names - [own]).sort).join("\n") : l.synonyms)
    end

    dup_ids = changes.group_by { |c| [c.season, League.staffel_key(c.new_staffel, @reg)] }
      .values.select { |cs| cs.size > 1 }.flatten.map { |c| c.league.id }.to_set
    mixed = changes.group_by(&:season).select { |_, cs| cs.map { |c| c.new_staffel.nil? }.uniq.size > 1 }.keys.sort

    Series.new(region: entries.first[:league].organizer, discipline: entries.first[:league].discipline,
      canonical: canonical, changes: changes.reject { |c| dup_ids.include?(c.league.id) }.sort_by { |c| [c.season, c.new_staffel.to_s] }.reverse,
      duplicates: changes.select { |c| dup_ids.include?(c.league.id) }, mixed_seasons: mixed)
  end

  # Schreibweise je Staffel-Schlüssel aus der jüngsten Saison, in der sie als staffel_text vorkommt.
  # Eingebettete Staffeln gibt es nur, wenn die Reihe dieselbe Staffel auch als staffel_text führt.
  def canonical_staffeln(entries)
    entries.select { |e| e[:skey] }.group_by { |e| e[:skey] }.transform_values do |es|
      real = es.reject { |e| e[:embedded] }
      # "OH" vor "1 OH": die implizite erste Staffel ohne Nummer schreiben, wenn es sie so gibt.
      real = real.reject { |e| e[:staffel].match?(/\A1\s/) }.presence || real
      real.max_by { |e| e[:league].season&.name.to_s }[:staffel]
    end
  end

  def original_name(league) = league.synonym_list.first || league.read_attribute(:name)

  # Schlüssel-Suffix ("staffel west") am Namensende entfernen, Schreibweise und Trenner tolerant.
  def strip_staffel(name, suffix_key)
    tokens = suffix_key.split.map { |t| Regexp.escape(t) }
    tokens.shift if tokens.first == "staffel"
    name.sub(/[\s\-–\/]*(?:staffel\s+)?#{tokens.join("[\\s\\-–/]+")}\z/i, "").strip
  end

  def apply
    League.skip_cable_ready_updates do
      changes.each do |c|
        l = c.league
        l[:name] = c.new_name
        l.staffel_text = c.new_staffel
        l.synonyms = c.synonyms
        l.save!
      rescue => e
        @errors << "League[#{l.id}] #{c.old_name} (#{c.season}): #{e.class}: #{e.message}"
      end
    end
  end
end
