# frozen_string_literal: true

module NuLiga
  # DB-schreibender Struktur-Importer für BBV/NuLiga (Milestone v0.5, Phase 16).
  #
  # Guard-Strategie (Vorbild LigaManager::Importer): Default dry-run; Schreiben nur bei armed:true →
  # instance-level create!/update! → PaperTrail-Version → Regional-Server-Sync; broadcast-frei
  # (skip_cable_ready_updates). LocalProtector schützt globale Records (id < 50_000_000) auf
  # Nicht-Authority-Servern. Keine Migration.
  #
  # KERNUNTERSCHIED zu LigaManager::Importer: die BBV-Saison 2025/26 ist in Carambus LEER →
  # dieser Importer LEGT Leagues + LeagueTeams NEU AN (find-or-create über Natur-Key, idempotent),
  # statt nur bestehende Records zu reconcilieren.
  #
  # 16-01: Struktur-Skelett — reconcile_clubs (VNr↔cc_id/ba_id + Namens-Gegenprobe, keine Neuanlage),
  # create_leagues, create_teams. Players/Seedings = 16-02; Parties/PartyGames = Phase 17.
  #
  # Match-Strategie (Phase 15 belegt):
  # - Clubs:   NuLiga-VNr (clubInfoDisplay) ↔ Carambus cc_id ODER ba_id (PRIMÄR); Namens-Gegenprobe → Review.
  # - Leagues: Branch (Sparte) + normalisierter Name; Discipline = Branch (Discipline.find_by(name:)).
  # - Teams:   League + normalisierter Team-Name; club_id über die VNr des Teams.
  class Importer
    def initialize(federation:, region_id:, season_id:, branches: Scraper::BRANCHES, armed: false, scraper: nil)
      @federation = federation
      @region_id = region_id
      @season_id = season_id
      @branches = branches
      @armed = armed
      @scraper = scraper || Scraper.new(federation: federation, season: Season.find(season_id).name)
      @leagues_by_group = {}
    end

    # Ermittelt die neueste Saison, für die NuLiga tatsächlich Ligen liefert — Probe absteigend ab current_season.
    # NuLiga hält nur ~4 Saisons; current_season (Carambus) ist dort evtl. noch NICHT vorhanden (z.B. 2026/27) →
    # nicht blind current_season nehmen. Rückgabe: Season (oder nil, wenn nichts verfügbar). Für nu_liga:daily_import.
    def self.current_nuliga_season(federation:, branch: Scraper::BRANCHES.first, max_lookback: 5)
      base = Season.current_season&.id || 17
      base.downto([base - max_lookback + 1, 1].max) do |sid|
        season = Season.find_by(id: sid)
        next unless season

        available = begin
          Scraper.new(federation: federation, season: season.name).leagues(branch).any?
        rescue
          false
        end
        return season if available
      end
      nil
    end

    def run
      {clubs: reconcile_clubs, leagues: create_leagues, teams: create_teams,
       players: reconcile_players, seedings: reconcile_seedings,
       parties: reconcile_parties, party_games: import_party_games}
    end

    # Club-Reconcile: NuLiga-VNr ↔ Carambus cc_id/ba_id (PRIMÄR). Setzt source_url der gematchten Clubs
    # (idempotent). Namens-Gegenprobe → name_mismatches (Review, KEIN Write darüber). Keine Club-Neuanlage.
    def reconcile_clubs
      cb = carambus_clubs
      matched = 0
      updated = 0
      name_mismatches = []
      unmatched = []

      nuliga_clubs.each do |c|
        hit = c[:vnr] && (cb[:by_cc][c[:vnr]] || cb[:by_ba][c[:vnr]])
        if hit
          matched += 1
          updated += 1 if apply_source_url(hit, club_source_url(c[:club_id]))
          unless name_matches?(c[:name], hit)
            name_mismatches << {vnr: c[:vnr], nu: c[:name], cb: hit.name}
            mismatch_vnrs << c[:vnr] # 16-02: solche VNr NICHT für Team-club_id verwenden (falscher Verein)
          end
        else
          unmatched << "#{c[:vnr] || "club=#{c[:club_id]}"} — #{c[:name]}"
        end
      end

      {matched: matched, updated: updated, name_mismatches: name_mismatches, unmatched: unmatched.sort}
    end

    # League find-or-create: Natur-Key region/season/Branch|Name. Discipline = Branch (fehlt → skip+melden).
    # Füllt @leagues_by_group (group_id → League) für create_teams.
    def create_leagues
      scope = League.where(region_id: @region_id, season_id: @season_id)
      index = scope.includes(:discipline).index_by { |l| league_key(l.discipline&.name, l.name) }
      # Idempotenz-Index über die STABILE group-ID (nicht den vollen URL-String): übersteht
      # source_url-Formatwechsel (z.B. +championship-Param) — wichtig für kollisions-umbenannte
      # Ligen („VL Nord (Snooker)"), die der Name-Key-Fallback nicht trifft.
      by_group = scope.where.not(source_url: nil)
        .index_by { |l| l.source_url.to_s[/[?&]group=(\d+)/, 1] }
      by_group.delete(nil)
      matched = 0
      created = 0
      updated = 0
      skipped = []

      nuliga_leagues.each do |l|
        src = league_source_url(l[:group_id], l[:branch])
        # Idempotenz PRIMÄR über die NuLiga-group-ID (stabil, sparten-eindeutig), dann Name-Key.
        existing = by_group[l[:group_id].to_s] || index[league_key(l[:branch], l[:name])]
        if existing
          matched += 1
          updated += 1 if apply_source_url(existing, src)
          @leagues_by_group[l[:group_id]] = existing
          next
        end

        discipline = resolve_league_discipline(l)
        unless discipline
          skipped << "#{l[:group_id]} — #{l[:name]} (#{l[:branch]}: keine Discipline)"
          next
        end

        if @armed
          league = create_league(l, discipline)
          if league
            created += 1
            by_group[l[:group_id].to_s] = league
            index[league_key(l[:branch], league.name)] = league
            @leagues_by_group[l[:group_id]] = league
          else
            skipped << "#{l[:group_id]} — #{l[:name]} (create fehlgeschlagen)"
          end
        else
          created += 1
        end
      end

      {matched: matched, created: created, updated: updated, skipped: skipped.sort}
    end

    # LeagueTeam find-or-create: Natur-Key league_id + normalisierter Name. club_id über die Team-VNr.
    # 16-02: bei VNr-Namens-Mismatch KEIN club_id (nil statt falscher Verein) → club_mismatch-Report.
    def create_teams
      created = 0
      updated = 0
      club_unmatched = []
      club_mismatch = []
      league_missing = []

      nuliga_teams.each do |t|
        league = @leagues_by_group[t[:group_id]]
        unless league
          # In dry-run existiert eine neu-anzulegende Liga noch nicht → Team zählt als „würde anlegen".
          if @armed
            league_missing << "#{t[:teamtable_id]} — #{t[:name]} (Liga #{t[:group_id]} fehlt)"
          else
            created += 1
          end
          next
        end

        existing = league_team_index(league.id)[Comparison.normalize_key(t[:name])]
        if existing
          updated += 1 if apply_source_url(existing, team_source_url(t[:teamtable_id]))
          next
        end

        club = carambus_club_for(t[:club_id])
        if club.nil? && mismatch_vnr_for?(t[:club_id])
          club_mismatch << "#{t[:teamtable_id]} — #{t[:name]} (VNr-Namens-Mismatch → club_id nil)"
        elsif club.nil?
          club_unmatched << "#{t[:teamtable_id]} — #{t[:name]} (club=#{t[:club_id]})"
        end
        created += 1
        create_team(league, t, club) if @armed
      end

      {created: created, updated: updated, club_unmatched: club_unmatched.sort,
       club_mismatch: club_mismatch.sort, league_missing: league_missing.sort}
    end

    # Player-Reconcile: Roster je Liga (player_ranking) namensbasiert geschichtet (Club-scoped → Region-
    # Fallback). genau-1 → SeasonParticipation (club/season) mit source_url; >1 → ambiguous (skip);
    # 0 → neuer Player (region, source_url) + SeasonParticipation. Füllt @roster_links für Seedings.
    def reconcile_players
      matched = 0
      created = 0
      ambiguous = []
      sp_updated = 0
      @roster_links = []

      nuliga_roster.each do |r|
        lt = r[:league_team]
        club = lt&.club
        player, kind = resolve_player(r[:name], club, r[:person_id])
        case kind
        when :ambiguous
          ambiguous << "#{r[:name]} (#{club&.name || "?"})"
          next
        when :matched then matched += 1
        when :created then created += 1
        end
        next unless player

        @roster_links << {player: player, league_team: lt} if lt
        sp_updated += 1 if mark_season_participation(player, club, r[:person_id]) == :updated
      end

      {matched: matched, created: created, ambiguous: ambiguous.sort, sp_updated: sp_updated}
    end

    # Seeding-Reconcile: je @roster_links-Paar (Player, LeagueTeam) ein Seeding (Natur-Key, dedupliziert).
    def reconcile_seedings
      seen = Set.new
      seedings_matched = 0
      seedings_created = 0
      unmatched = []

      Array(@roster_links).each do |link|
        lt = link[:league_team]
        player = link[:player]
        key = [lt.id, player.id]
        next if seen.include?(key)

        seen << key
        if Seeding.exists?(league_team_id: lt.id, player_id: player.id)
          seedings_matched += 1
        else
          seedings_created += 1
          create_seeding(lt.id, player.id) if @armed
        end
      end

      {seedings_matched: seedings_matched, seedings_created: seedings_created, unmatched: unmatched.uniq.sort}
    end

    # Party-Reconcile: je Liga die Begegnungen (Scraper#meetings) → Carambus-Party (Heim/Gast-LeagueTeam
    # über den Team-Namen). find-or-create idempotent über (league, a, b, Datum). Bestehende → source_url +
    # leeres Ergebnis füllen (nie überschreiben). Fehlendes LeagueTeam → unmatched. Nur gespielte Begegnungen.
    def reconcile_parties
      cb_party_index = Party.where(league_id: @leagues_by_group.values.map(&:id))
        .index_by { |p| [p.league_id, p.league_team_a_id, p.league_team_b_id, party_date_key(p.date)] }
      matched = 0
      created = 0
      filled = 0
      unmatched = []

      nuliga_leagues.each do |l|
        league = @leagues_by_group[l[:group_id]]
        next unless league

        lt_index = league_team_by_name(league.id)
        @scraper.meetings(l[:group_id], branch: l[:branch]).each do |m|
          a = lt_index[Comparison.normalize_key(m[:home_team])]
          b = lt_index[Comparison.normalize_key(m[:guest_team])]
          date = parse_nuliga_date(m[:date])
          unless a && b
            unmatched << "#{m[:home_team]} vs #{m[:guest_team]} (#{m[:date]}) — Team fehlt"
            next
          end

          party = cb_party_index[[league.id, a.id, b.id, party_date_key(date)]]
          if party
            matched += 1
            apply_source_url(party, party_source_url(m[:meeting_id], league))
            filled += 1 if fill_empty_result(party, m[:result])
          else
            created += 1
            create_party(league, a, b, date, m[:result], m[:meeting_id]) if @armed
          end
        end
      end

      {matched: matched, created: created, filled: filled, unmatched: unmatched.uniq.sort}
    end

    # Einzelspiel-Import: je Party mit meeting-source_url ohne PartyGames den Spielbericht holen und je game
    # ein PartyGame anlegen (seqno=position, discipline via classify, player_a/b namensbasiert im Roster,
    # Doppel = erster Spieler/Seite). Idempotent (party_id, seqno). Keine neuen Player/Teams.
    def import_party_games
      parties_processed = 0
      games_created = 0
      players_unmatched = 0
      disciplines_unmatched = 0
      parties_skipped = 0
      meetings_failed = 0

      carambus_parties_without_games.each do |party|
        # [?&]-Regex: matcht altes (meeting= direkt nach ?) UND neues Format (championship=…&meeting=).
        meeting_id = party.source_url.to_s[/[?&]meeting=(\d+)/, 1]
        group_id = party.league&.source_url.to_s[/[?&]group=(\d+)/, 1]
        # NuLiga-Sparte (Pool/Snooker/Karambol) für die championship — NICHT die feine League-Disziplin
        # (Karambol-Ligen tragen „Karambol großes/kleines Billard", NuLiga kennt nur „Karambol").
        branch = nuliga_branch_for(party.league&.discipline)
        unless meeting_id && group_id && branch
          parties_skipped += 1
          next
        end

        # Ein einzelner fehlgeschlagener Spielbericht (transienter 302/Timeout/Parse-Fehler nach den Client-
        # Retries) darf NIE den ganzen Import abbrechen — überspringen, Party bleibt "ohne Spiele" → ein
        # idempotenter Re-Run holt sie nach.
        begin
          report = @scraper.meeting_report(meeting_id, group_id: group_id, branch: branch)
        rescue => e
          Rails.logger.warn("NuLiga::Importer meeting_report(#{meeting_id}) übersprungen: #{e.message}")
          meetings_failed += 1
          next
        end
        roster_a = roster_by_league_team(party.league_team_a_id)
        roster_b = roster_by_league_team(party.league_team_b_id)
        parties_processed += 1

        Array(report[:games]).each do |g|
          seqno = g[:position]
          next if seqno.nil? || PartyGame.exists?(party_id: party.id, seqno: seqno)

          discipline = discipline_for(g[:discipline])
          disciplines_unmatched += 1 if discipline.nil?
          player_a = unique_roster_player(roster_a, Array(g[:home_players]).first)
          player_b = unique_roster_player(roster_b, Array(g[:guest_players]).first)
          players_unmatched += 1 if player_a.nil?
          players_unmatched += 1 if player_b.nil?

          games_created += 1
          create_party_game(party, seqno, g, discipline, player_a, player_b) if @armed
        end
      end

      {parties_processed: parties_processed, games_created: games_created,
       players_unmatched: players_unmatched, disciplines_unmatched: disciplines_unmatched,
       parties_skipped: parties_skipped, meetings_failed: meetings_failed}
    end

    private

    # --- Schreib-Guard (nur bei @armed; broadcast-frei; instance-level → PaperTrail → Sync) ---

    def apply_source_url(record, url)
      return false if url.blank? # Archiv-Begegnungen ohne meeting_id → keine source_url setzen/überschreiben
      return false if record.source_url == url

      if @armed
        record.class.skip_cable_ready_updates do
          record.update!(source_url: url)
        end
      end
      true
    end

    # Legt eine League an — organizer=Region (konsistent zum BBV-Bestand); shortname aus dem Namen
    # abgeleitet (Validierung verlangt shortname bei organizer_type=='Region'). nil bei Validierungsfehler
    # (z.B. Name-Kollision im uniqueness-Scope) — der Aufrufer meldet den Fehldruck, statt abzubrechen.
    def create_league(nu_league, discipline)
      build_league(display_league_name(nu_league), nu_league, discipline)
    rescue ActiveRecord::RecordInvalid => e
      # League-Uniqueness (name+season+organizer+staffel_text) IGNORIERT die Disziplin. NuLiga nutzt
      # dieselben Kurznamen („VL Nord") in Pool UND Snooker → Kollision. Fix: Sparte an den Namen hängen.
      qualified = "#{display_league_name(nu_league)} (#{nu_league[:branch]})"
      if e.message.include?("unique within the same region") && !display_league_name(nu_league).include?("(#{nu_league[:branch]})")
        begin
          build_league(qualified, nu_league, discipline)
        rescue ActiveRecord::RecordInvalid => e2
          Rails.logger.warn("NuLiga::Importer create_league(#{qualified}) fehlgeschlagen: #{e2.message}")
          nil
        end
      else
        Rails.logger.warn("NuLiga::Importer create_league(#{nu_league[:name]}) fehlgeschlagen: #{e.message}")
        nil
      end
    end

    def build_league(name, nu_league, discipline)
      League.skip_cable_ready_updates do
        League.create!(
          region_id: @region_id,
          season_id: @season_id,
          organizer_type: "Region",
          organizer_id: @region_id,
          discipline_id: discipline.id,
          name: name,
          shortname: name,
          source_url: league_source_url(nu_league[:group_id], nu_league[:branch])
        )
      end
    end

    # --- Karambol: Feindisziplin-Ableitung + Namens-Expansion (BBV-spezifisch) ---
    # NuLiga liefert die generische Sparte „Karambol"; Carambus modelliert fein (großes/kleines
    # Billard, wie der 21/22-CC-Bestand). Ableitung aus dem Liga-Namen per Regel + Override.
    # Nur Karambol — Pool/Snooker laufen unverändert über Discipline.find_by(name: branch).

    # Kürzel → Langname; nur 22/23+23/24 tragen Kürzel, 24/25+25/26 sind schon ausgeschrieben
    # (unbekannte Tokens werden durchgereicht → lange Namen bleiben unverändert).
    KARAMBOL_NAME_TOKENS = {
      "OL" => "Oberliga", "VL" => "Verbandsliga", "LL" => "Landesliga", "BL" => "Bezirksliga",
      "3Bd" => "Dreiband", "MK" => "Mehrkampf", "FP" => "Freie Partie", "4K" => "Vierkampf",
      "Rel" => "Relegation"
    }.freeze

    def resolve_league_discipline(nu_league)
      return karambol_discipline(nu_league[:name]) if nu_league[:branch] == "Karambol"
      Discipline.find_by(name: nu_league[:branch])
    end

    # NuLiga-Sparte (Wurzel-Disziplin) aus einer ggf. feinen League-Disziplin: „Karambol großes
    # Billard" → „Karambol", „Pool" → „Pool". Für die championship-Bildung im meeting_report.
    def nuliga_branch_for(discipline)
      return nil unless discipline
      root = discipline
      root = root.super_discipline while root.super_discipline
      root.name
    end

    # Regel: Dreiband-Ligabetrieb → großes Billard; Freie Partie/Mehrkampf/Vierkampf → kleines.
    # Override (an der 21/22-Referenz belegt): Meisterschaft (BayMM/LMM) mit Dreiband → kleines Billard.
    def karambol_discipline(name)
      n = name.to_s.downcase
      dreiband = n.match?(/3bd|dreiband/)
      meisterschaft = n.match?(/baymm|lmm/)
      fine = (dreiband && !meisterschaft) ? "Karambol großes Billard" : "Karambol kleines Billard"
      Discipline.find_by(name: fine)
    end

    def display_league_name(nu_league)
      return nu_league[:name] unless nu_league[:branch] == "Karambol"
      expand_karambol_name(nu_league[:name])
    end

    KARAMBOL_REGIONS = %w[Nord Süd Mitte Ost West].freeze

    # OL_3Bd → „Oberliga Dreiband"; VL 3Bd Nord → „Verbandsliga Nord Dreiband". Die Region wird
    # direkt hinter die Liga-Ebene gezogen, damit expandierte (22/23+23/24) und native (24/25+25/26)
    # Namen derselben Liga-Reihe identisch sind. Schon-lange Namen bleiben unverändert.
    def expand_karambol_name(name)
      tokens = name.to_s.tr("_", " ").split.map { |tok| KARAMBOL_NAME_TOKENS[tok] || tok }
      if (reg = tokens.find { |t| KARAMBOL_REGIONS.include?(t) })
        tokens.delete_at(tokens.index(reg))
        tokens.insert(1, reg)
      end
      tokens.join(" ")
    end

    def create_team(league, nu_team, club)
      LeagueTeam.skip_cable_ready_updates do
        LeagueTeam.create!(
          league_id: league.id,
          name: nu_team[:name],
          club_id: club&.id,
          source_url: team_source_url(nu_team[:teamtable_id])
        )
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn("NuLiga::Importer create_team(#{nu_team[:name]}) fehlgeschlagen: #{e.message}")
      nil
    end

    # --- Carambus-Seite (read-only-Lookups) ---

    def carambus_clubs
      @carambus_clubs ||= begin
        list = Club.where(region_id: @region_id).to_a
        {list: list, by_cc: list.index_by(&:cc_id), by_ba: list.index_by(&:ba_id)}
      end
    end

    # NuLiga-club_id → Carambus-Club über die VNr (cc_id/ba_id). nil, wenn keine VNr/kein Treffer
    # ODER die VNr ein Namens-Mismatch ist (16-02: dann NICHT den falsch benannten Verein verknüpfen).
    def carambus_club_for(nuliga_club_id)
      vnr = vnr_by_nuliga_id[nuliga_club_id]
      return nil unless vnr
      return nil if mismatch_vnrs.include?(vnr)

      carambus_clubs[:by_cc][vnr] || carambus_clubs[:by_ba][vnr]
    end

    def vnr_by_nuliga_id
      @vnr_by_nuliga_id ||= nuliga_clubs.to_h { |c| [c[:club_id], c[:vnr]] }
    end

    # Set der VNrs, deren Carambus-Club namentlich abweicht (aus reconcile_clubs; leer bis reconcile_clubs lief).
    def mismatch_vnrs
      @mismatch_vnrs ||= Set.new
    end

    # true, wenn die VNr des NuLiga-club_id ein Namens-Mismatch ist (für create_teams-Report).
    def mismatch_vnr_for?(nuliga_club_id)
      vnr = vnr_by_nuliga_id[nuliga_club_id]
      vnr && mismatch_vnrs.include?(vnr)
    end

    def league_team_index(league_id)
      (@league_team_index ||= {})[league_id] ||=
        LeagueTeam.where(league_id: league_id).index_by { |t| Comparison.normalize_key(t.name) }
    end

    def name_matches?(nu_name, cb)
      n = Comparison.normalize_name(nu_name)
      n == Comparison.normalize_name(cb.name) || n == Comparison.normalize_name(cb.shortname)
    end

    def league_key(branch, name)
      "#{Comparison.normalize_name(branch)}|#{Comparison.normalize_key(name)}"
    end

    # --- Parties/PartyGames (Phase 17) ---

    # Frischer LeagueTeam-Index je League (nach der Anlage), Name → LeagueTeam.
    def league_team_by_name(league_id)
      (@lt_by_name ||= {})[league_id] ||=
        LeagueTeam.where(league_id: league_id).index_by { |t| Comparison.normalize_key(t.name) }
    end

    # NuLiga-Datum „DD.MM.YYYY" → Date (nil bei ungültig).
    def parse_nuliga_date(str)
      Date.strptime(str.to_s, "%d.%m.%Y")
    rescue ArgumentError
      nil
    end

    # Normalisiert Party#date / Date auf „YYYY-MM-DD" für den Idempotenz-Key.
    def party_date_key(date)
      date.respond_to?(:to_date) ? date.to_date.to_s : date.to_s[0, 10]
    end

    # Roster (Seeding-Spieler) eines LeagueTeams, gruppiert nach normalisiertem „lastname firstname".
    def roster_by_league_team(league_team_id)
      (@lt_roster ||= {})[league_team_id] ||=
        Seeding.where(league_team_id: league_team_id).includes(:player)
          .filter_map(&:player).group_by { |p| player_key_for(p) }
    end

    # NuLiga-Berichtsname „Nachname, Vorname" → eindeutiger Roster-Spieler (nil bei 0/>1).
    def unique_roster_player(roster, spielername)
      return nil if spielername.to_s.strip.empty?

      candidates = Array(roster[Comparison.normalize_name(spielername)]).uniq
      (candidates.size == 1) ? candidates.first : nil
    end

    # Disziplin über exakten Synonym-Zeilentreffer, Fallback classify_from_title (wie LM).
    def discipline_for(name)
      return nil if name.to_s.strip.empty?

      (@discipline_cache ||= {})[name] ||= begin
        by_syn = Discipline.where("synonyms ilike ?", "%#{name}%").to_a
          .find { |d| d.synonyms.to_s.split("\n").map(&:strip).include?(name.strip) }
        by_syn || Discipline.classify_from_title(name)
      end
    end

    # Carambus-Parties der Zielsaison (region/season) mit NuLiga-source_url ohne Einzelspiele.
    def carambus_parties_without_games
      league_ids = League.where(region_id: @region_id, season_id: @season_id).select(:id)
      Party.where(league_id: league_ids).where("source_url LIKE ?", "%groupMeetingReport%")
        .where.not(id: PartyGame.select(:party_id).distinct)
        .includes(:league)
    end

    # Füllt data["result"] NUR wenn leer (nie überschreiben). result muss selbst nicht-leer sein.
    def fill_empty_result(party, result)
      return false unless blank_result?(party.data)
      return false if result.to_s.gsub(/[^0-9]/, "").empty?

      if @armed
        party.class.skip_cable_ready_updates do
          party.update!(data: (party.data || {}).merge("result" => result))
        end
      end
      true
    end

    def blank_result?(data)
      (data.is_a?(Hash) ? data["result"].to_s : "").gsub(/[^0-9]/, "").empty?
    end

    def create_party(league, home, away, date, result, meeting_id)
      Party.skip_cable_ready_updates do
        Party.create!(
          league_id: league.id,
          league_team_a_id: home.id,
          league_team_b_id: away.id,
          host_league_team_id: home.id,
          date: date,
          data: {"result" => result},
          source_url: party_source_url(meeting_id, league)
        )
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn("NuLiga::Importer create_party(#{home.name} vs #{away.name}) fehlgeschlagen: #{e.message}")
      nil
    end

    def create_party_game(party, seqno, game, discipline, player_a, player_b)
      data = {"result" => game[:set_result]}
      data["match_points"] = game[:match_points] if game[:match_points].present?
      data["stats"] = game[:stats] if game[:stats]
      PartyGame.skip_cable_ready_updates do
        PartyGame.create!(
          party_id: party.id,
          seqno: seqno,
          name: "Spiel #{seqno}::#{game[:discipline]}",
          discipline_id: discipline&.id,
          player_a_id: player_a&.id,
          player_b_id: player_b&.id,
          data: data
        )
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn("NuLiga::Importer create_party_game(#{party.id}/#{seqno}) fehlgeschlagen: #{e.message}")
      nil
    end

    def party_source_url(meeting_id, league = nil)
      if meeting_id.present?
        # groupMeetingReport braucht championship+group als Kontext, sonst „Willkommen"-Fehlerseite.
        # branch = Liga-Disziplin (NuLiga-Ligen tragen die Sparte); group aus der Liga-source_url
        # ([?&]group= matcht altes UND neues Format). Ohne Kontext: nackte URL als Fallback.
        branch = league&.discipline&.name
        group_id = league&.source_url.to_s[/[?&]group=(\d+)/, 1]
        if branch.present? && group_id.present?
          return "#{nuliga_base}/groupMeetingReport?" \
                 "#{URI.encode_www_form(championship: championship_for(branch), group: group_id, meeting: meeting_id)}"
        end
        return "#{nuliga_base}/groupMeetingReport?meeting=#{meeting_id}"
      end
      # Archiv-Begegnung ohne Einzelspiel-Link → groupPage-URL der Liga als NuLiga-Provenienz (statt nil);
      # unterscheidet NuLiga-Archiv-Parties von Legacy-Billardarea (source_url nil). Kein groupMeetingReport →
      # import_party_games/carambus_parties_without_games überspringen sie weiterhin korrekt.
      league&.source_url
    end

    # --- NuLiga-Seite (read-only via Scraper; Fehler je Ebene → überspringen) ---

    def nuliga_leagues
      @nuliga_leagues ||= @branches.flat_map do |branch|
        @scraper.leagues(branch).map { |l| l.merge(branch: branch) }
      rescue => e
        Rails.logger.warn("NuLiga::Importer leagues(#{branch}) übersprungen: #{e.message}")
        []
      end
    end

    # [{group_id:, branch:, teamtable_id:, name:, club_id:}] — Team + NuLiga-club_id (via teamPortrait).
    def nuliga_teams
      @nuliga_teams ||= nuliga_leagues.flat_map do |l|
        @scraper.group(l[:group_id], branch: l[:branch])[:teams].map do |t|
          {group_id: l[:group_id], branch: l[:branch], teamtable_id: t[:teamtable_id], name: t[:name],
           club_id: team_club_id(t[:teamtable_id], l[:group_id], l[:branch])}
        end
      rescue => e
        Rails.logger.warn("NuLiga::Importer group(#{l[:group_id]}) übersprungen: #{e.message}")
        []
      end
    end

    def team_club_id(teamtable_id, group_id, branch)
      @scraper.team(teamtable_id, group_id: group_id, branch: branch)[:club][:club_id]
    rescue => e
      Rails.logger.warn("NuLiga::Importer team(#{teamtable_id}) übersprungen: #{e.message}")
      nil
    end

    # Eindeutige NuLiga-Clubs (mit VNr) über die club_ids der Teams.
    def nuliga_clubs
      @nuliga_clubs ||= nuliga_teams.map { |t| t[:club_id] }.compact.uniq.filter_map do |cid|
        @scraper.club(cid)
      rescue => e
        Rails.logger.warn("NuLiga::Importer club(#{cid}) übersprungen: #{e.message}")
        nil
      end
    end

    # Roster je Liga (player_ranking) mit aufgelöstem Carambus-LeagueTeam (über team_name).
    # [{person_id:, name:, league_team:}] — league_team nil, wenn die Liga (dry-run) noch nicht angelegt ist.
    def nuliga_roster
      @nuliga_roster ||= nuliga_leagues.flat_map do |l|
        league = @leagues_by_group[l[:group_id]]
        # Frischer Team-Index (nach create_teams gebaut) — NICHT die create_teams-Memo (die entstand vor der Anlage).
        lt_index = league ? LeagueTeam.where(league_id: league.id).index_by { |t| Comparison.normalize_key(t.name) } : {}
        @scraper.player_ranking(l[:group_id], branch: l[:branch]).map do |p|
          {person_id: p[:person_id], name: p[:name], league_team: lt_index[Comparison.normalize_key(p[:team_name])]}
        end
      rescue => e
        Rails.logger.warn("NuLiga::Importer player_ranking(#{l[:group_id]}) übersprungen: #{e.message}")
        []
      end
    end

    # --- Player-Match (geschichtet: Club-scoped → Region-Fallback) + Neuanlage ---

    # → [player_or_nil, :matched|:ambiguous|:created]
    def resolve_player(name, club, person_id)
      key = Comparison.normalize_name(name)
      if club
        cands = club_players_by_key(club)[key] || []
        return [cands.first, :matched] if cands.size == 1
        return [nil, :ambiguous] if cands.size > 1
      end

      rcands = region_players_by_key[key] || []
      case rcands.size
      when 1 then [rcands.first, :matched]
      when 0 then [(@armed ? create_player(name, person_id) : nil), :created]
      else [nil, :ambiguous]
      end
    end

    def club_players_by_key(club)
      (@club_players ||= {})[club.id] ||=
        (Player.where(club_id: club.id).to_a + club.players.to_a).uniq
          .group_by { |p| player_key_for(p) }
    end

    def region_players_by_key
      @region_players_by_key ||=
        Player.where(region_id: @region_id).to_a.group_by { |p| player_key_for(p) }
    end

    def player_key_for(player)
      Comparison.normalize_name("#{player.lastname} #{player.firstname}")
    end

    # „Nachname, Vorname" → [lastname, firstname]; ohne Komma → [name, ""].
    def split_name(name)
      last, first = name.to_s.split(",", 2).map(&:strip)
      [last.to_s, first.to_s]
    end

    def create_player(name, person_id)
      last, first = split_name(name)
      player = Player.skip_cable_ready_updates do
        Player.create!(lastname: last, firstname: first, region_id: @region_id,
          source_url: player_source_url(person_id))
      end
      (region_players_by_key[player_key_for(player)] ||= []) << player # Dedup: nicht doppelt anlegen im Lauf
      player
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn("NuLiga::Importer create_player(#{name}) fehlgeschlagen: #{e.message}")
      nil
    end

    # SeasonParticipation find-or-create (Player↔Club↔Season) mit source_url-Provenienz. :updated wenn
    # angelegt/geändert (bzw. im dry-run „würde"), sonst nil.
    def mark_season_participation(player, club, person_id)
      return nil unless player && club

      # Heilt NUR bereits vorhandene NuLiga-playerPortrait-URLs aufs gültige Format (+federation);
      # Player ohne/mit fremder Provenienz bleiben unangetastet (Design 16-02: Provenienz am SP).
      apply_source_url(player, player_source_url(person_id)) if player.source_url.to_s.include?("playerPortrait")

      sp = SeasonParticipation.find_by(player_id: player.id, club_id: club.id, season_id: @season_id)
      if sp
        apply_source_url(sp, player_source_url(person_id)) ? :updated : nil
      elsif @armed
        SeasonParticipation.skip_cable_ready_updates do
          SeasonParticipation.create!(player_id: player.id, club_id: club.id, season_id: @season_id,
            region_id: @region_id, source_url: player_source_url(person_id))
        end
        :updated
      else
        :updated
      end
    end

    def create_seeding(league_team_id, player_id)
      Seeding.skip_cable_ready_updates do
        Seeding.create!(league_team_id: league_team_id, player_id: player_id)
      end
    end

    # --- Provenienz-URLs (NuLiga-Ressourcen; stabil + eindeutig) ---
    # BEFUND 2026-07-17 (carambus.de/leagues/9939): groupPage/groupMeetingReport/playerPortrait sind
    # OHNE Kontext-Parameter als Link ungültig (404 + „Willkommen zu nuLiga"-Fehlerseite) — groupPage/
    # groupMeetingReport brauchen championship=, playerPortrait braucht federation=. Nur clubInfoDisplay
    # und teamPortrait funktionieren mit der ID allein. Idempotenz hängt NICHT am URL-String (Ligen:
    # group-ID-Index + Name-Key; Parties/SPs: Naturschlüssel) — Formatwechsel heilt via apply_source_url.

    def nuliga_base
      "#{Client::DEFAULT_BASE_URL}#{Client::WA_PATH}"
    end

    def championship_for(branch)
      Client.championship(federation: @federation, branch: branch, season_name: season_name)
    end

    def season_name
      @season_name ||= Season.find(@season_id).name
    end

    def club_source_url(club_id)
      "#{nuliga_base}/clubInfoDisplay?club=#{club_id}"
    end

    def league_source_url(group_id, branch)
      "#{nuliga_base}/groupPage?#{URI.encode_www_form(championship: championship_for(branch), group: group_id)}"
    end

    def team_source_url(teamtable_id)
      "#{nuliga_base}/teamPortrait?teamtable=#{teamtable_id}"
    end

    def player_source_url(person_id)
      "#{nuliga_base}/playerPortrait?#{URI.encode_www_form(federation: @federation, person: person_id)}"
    end
  end
end
