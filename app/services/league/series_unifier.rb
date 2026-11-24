# frozen_string_literal: true

# Vereinheitlicht Ligen-Reihen: dieselbe Liga einer Region und Disziplin heißt über die Saisons
# verschieden ("Bezirksliga" → "Bezirksliga Pool" → "Bezirksliga - Pool"), die Staffel steht mal als
# "Staffel A", mal als "A", mal im Namen ("Verbandsliga - Mitte" ohne staffel_text).
#
# Regeln:
# - Reihe = gleiche Region (organizer), gleiche Disziplin, gleicher League.series_name_key. Eine Liga, die
#   nur die Oberdisziplin trägt (CC: „Karambol“), gehört zur Reihe einer Unterdisziplin (BA: „Karambol
#   großes Billard“), wenn es genau eine solche Reihe mit demselben Schlüssel gibt (BLVN Oberliga Dreiband).
# - Bezirks-Kürzel als Namens-Präfix („OH - Kreisliga“, CC-Backfill 2021/22) werden zur Staffel; Staffeln
#   in der Schreibweise des Verbands (League.expand_staffel: „WB Mitte“ → „Weserbergland Mitte“).
# - OVERRIDES: Einzelfälle, die keine Regel trägt (Liga-ID → [Name, Staffel]), vom Betreiber entschieden.
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

  # Einzelfälle (Entscheidungen 2026-11-24). BLVN-Kreisliga Osnabrück / Huntegau, zeitweise zweigeteilt: „Kreisliga OH“
  # und „[Pool Kreisliga 1]“ sind dieselben Teams wie die Reihe [Osnabrück / Huntegau], „[2 OH]“ und
  # „Kreisliga 2“ 2016/17 die zweite Staffel, „Kreisliga 1“ 2016/17 die erste.
  OVERRIDES = {
    5774 => ["Kreisliga", "Osnabrück / Huntegau"], 5612 => ["Kreisliga", "Osnabrück / Huntegau"],
    3707 => ["Kreisliga", "Osnabrück / Huntegau"], 5611 => ["Kreisliga", "Osnabrück / Huntegau 2"],
    3706 => ["Kreisliga", "Osnabrück / Huntegau 2"], 6258 => ["Kreisliga", "Osnabrück / Huntegau 1"],
    6263 => ["Kreisliga", "Osnabrück / Huntegau 2"],
    # SBV Landesliga Pool 2026/27: die CC legte die neuen Staffeln mit dem Namen an („Landesliga Nord-West“),
    # die Reihe führte bis 2025/26 [West]/[Ost]. Eigene Staffeln (Teams teils gewechselt); ab jetzt führt die
    # Reihe sie, spätere CC-Anlagen erkennt die Regel „Staffel im Namen“ von selbst.
    10123 => ["Landesliga", "Nord-West"], 10124 => ["Landesliga", "Süd-Ost"],
    # SBV Kegel: „Oberliga Eurokegel“ (BA 2018–2022, CC 2021/22 „(Staffel A)“) = „Eurokegel-Oberliga“ (CC ab
    # 2022/23), dieselben Teams; nur die Wortstellung unterscheidet sich.
    6011 => ["Eurokegel-Oberliga", nil], 5846 => ["Eurokegel-Oberliga", nil], 5684 => ["Eurokegel-Oberliga", nil],
    5509 => ["Eurokegel-Oberliga", nil], 9306 => ["Eurokegel-Oberliga", nil]
  }.freeze

  attr_reader :series, :changes, :errors

  def initialize(region: nil, armed: false, overrides: OVERRIDES)
    @region = region
    @armed = armed
    @overrides = overrides
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
    scope.to_a.group_by { |l| [l.organizer_id, l.discipline.super_discipline_id || l.discipline_id] }.flat_map do |(_, branch_id), leagues|
      series_in_bucket(leagues, branch_id)
    end.compact.sort_by { |s| [s.region.shortname, s.discipline.name, s.canonical] }
  end

  def series_in_bucket(leagues, branch_id)
    @reg = leagues.first.organizer
    entries = leagues.map do |l|
      disc = l.discipline.name
      name, staffel = @overrides[l.id] || split_region_prefix(l.read_attribute(:name).to_s.squish, l.staffel_text.presence)
      staffel = League.expand_staffel(strip_own_name(staffel, name, disc), @reg)
      {league: l, key: League.series_name_key(name, disc, @reg.shortname), base: name, disc_id: l.discipline_id,
       staffel: staffel, skey: League.staffel_key(staffel, @reg), embedded: false}
    end
    # Oberdisziplin-Ligen der einzigen passenden Unterdisziplin-Reihe zuordnen, sonst eigene Reihe.
    subs = entries.reject { |e| e[:disc_id] == branch_id }.group_by { |e| e[:key] }
      .transform_values { |es| es.map { |e| e[:disc_id] }.uniq }
    entries.each do |e|
      e[:group] = (e[:disc_id] == branch_id && subs[e[:key]]&.size == 1) ? subs[e[:key]].first : e[:disc_id]
    end

    entries.group_by { |e| e[:group] }.values.flat_map do |es|
      groups = es.group_by { |e| e[:key] }
      move_embedded_staffeln(groups)
      groups.values.map { |g| plan_series(g) }
    end
  end

  # „OH - Kreisliga“ → [„Kreisliga“, „OH“]; steht der Bezirk schon in der Staffel („WB - Bezirksliga“
  # [„Nord  Weserbergland“]), bleibt die Staffel.
  def split_region_prefix(name, staffel)
    m = name.match(/\A(\S+)\s+-\s+(.+)\z/)
    long = m && League.staffel_abbreviations(@reg).find { |k, _| k.casecmp?(m[1]) }&.last
    return [name, staffel] unless long

    has_long = League.staffel_key(staffel, @reg).to_s.include?(League.staffel_key(long))
    [m[2], has_long ? staffel : [m[1], staffel].compact.join(" ")]
  end

  # "Verbandsliga - Mitte" (ohne Staffel) → Reihe "verbandsliga", Staffel "Mitte" — nur wenn die
  # Reihe die Staffel "mitte" tatsächlich führt. Längster Reihenschlüssel, der die Staffel führt, gewinnt:
  # "Verbandsliga Nord-West" gehört zu "Verbandsliga" [Nord-West], nicht zu "Verbandsliga Nord" (ohne
  # Staffel "West") — sonst fände erst ein zweiter Lauf das Ziel (BVBW: 32 Nachzügler).
  def move_embedded_staffeln(groups)
    groups.keys.each do |key|
      movers = groups[key].select { |e| e[:skey].nil? }
      next if movers.empty?

      target = groups.keys.select { |k| k != key && key.start_with?("#{k} ") }.sort_by(&:length).reverse
        .find { |k| groups[k].any? { |e| e[:skey] == League.staffel_key(key.delete_prefix("#{k} "), @reg) } }
      next unless target

      suffix = key.delete_prefix("#{target} ")
      skey = League.staffel_key(suffix, @reg)

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
    return nil if names.size < 2 && entries.none? { |e| e[:embedded] || e[:staffel] != e[:league].staffel_text.presence } &&
      spellings.group_by { |s| League.staffel_key(s, @reg) }.values.all? { |v| v.uniq.size < 2 }

    # Jüngster Name; bei eingebetteter Staffel der Name ohne sie ("Landesliga Staffel West" → "Landesliga").
    latest = entries.max_by { |e| e[:league].season&.name.to_s }[:league].season&.name.to_s
    canonical = entries.select { |e| e[:league].season&.name.to_s == latest }
      .map { |e| e[:base] }.tally.max_by { |n, c| [c, n] }.first
    # Der Reihenname kann nur als Basis existieren ("Bezirksliga" aus "Bezirksliga A/B"); ohne ihn
    # in `names` trüge erst ein zweiter Lauf ihn als Synonym nach (BVRP: 88 Doppel-Versionen).
    names |= [canonical]
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

  # BA schrieb den Ligennamen ins Staffelfeld (BVS: "Bezirksliga" [Bezirksliga A], "Oberliga Snooker"
  # [Oberliga A Snooker]). Nur wenn der GANZE Name (ohne Disziplinwort und Regionskürzel) vorne steht und
  # etwas übrig bleibt, zählt der Rest als Staffel; sonst bleibt die Staffel unverändert. Das Regionskürzel
  # muss wie im Namensschlüssel wegfallen, sonst greift die Regel erst nach der Umbenennung, also erst im
  # zweiten Lauf (BVNR 2015/16 "Kreisliga" [BVNR Pool Kreisliga Süd] → "BVNR Kreisliga Pool").
  def strip_own_name(staffel, name, disc)
    return staffel if staffel.blank?

    drop_disc = ->(tokens) { tokens.reject { |t| t.casecmp?(disc) || t.casecmp?(@reg.shortname) } }
    name_tokens = drop_disc.call(name.to_s.split)
    staffel_tokens = drop_disc.call(staffel.split)
    return staffel if name_tokens.empty? || staffel_tokens.size <= name_tokens.size
    return staffel unless staffel_tokens.first(name_tokens.size).zip(name_tokens).all? { |a, b| a.casecmp?(b) }

    staffel_tokens.drop(name_tokens.size).join(" ")
  end

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
