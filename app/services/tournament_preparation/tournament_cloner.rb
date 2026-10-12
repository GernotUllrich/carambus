# frozen_string_literal: true

module TournamentPreparation
  # Klont EIN Vorsaison-Turnier in die Folgesaison — NUR in ClubCloud (nbv-CC-Write).
  #
  # Legt CC-seitig eine Meldeliste (createMeldelisteCheck → createMeldelisteSave) an, mit
  # dem Datum um +1 Jahr auf den nächsten gleichen Wochentag verschoben, Meldeliste nur
  # strukturell (leer). Es wird NICHTS in die carambus-DB geschrieben; das Quell-Turnier
  # wird nur gelesen. Die neuen Turniere kommen per regulärem Authority-Scrape zurück in
  # die DB. Verifikation per Rück-Lesen in CC.
  #
  # HAR-VERANKERT (2026-07-10, tmp/meldeliste_anlegem.har): Die bestehende Infra
  # (RegionCc::MeldelisteCreator, TournamentCc.create_from_ba) ist gegenüber der aktuellen
  # CC-V2-UI VERALTET — falsche Feldnamen (meldeschluss/stichtag statt mschluss/stag),
  # falsches Datumsformat (DD.MM.YYYY statt YYYY-MM-DD), fehlender createMeldelisteCheck-
  # Prep-Schritt. Dieser Service bildet den ECHTEN Request-Flow aus dem HAR nach.
  #
  # ⚠️ ACHTUNG, armed:true MUTIERT DIE CLUBCLOUD: createMeisterschaftSave wird abgesetzt
  #    (der frühere Hinweis "POST zurückgehalten" war überholt). Duplikat-Schutz ist ein
  #    Titel-Match in der Ziel-Saison (read_meisterschaft_ref) — er greift NICHT, wenn
  #    das bereits angelegte Turnier inzwischen umbenannt wurde. Ein Re-Run gegen eine
  #    Saison, deren Turniere schon veröffentlicht sind, ist daher nur mit vorherigem
  #    dry_run-Abgleich vertretbar.
  #
  # v1.3 Phase 50-01 (Proof/Weg 3).
  class TournamentCloner
    # Verschiebt ein Datum um +1 Jahr auf den NÄCHSTLIEGENDEN gleichen Wochentag
    # (Abweichung −3..+3 Tage um den Kalender-Jahrestag). Arbeitet auf Date (Time/
    # TimeWithZone kennt kein #>>), gibt ein Date zurück.
    def self.shift_to_next_season_same_weekday(date)
      return nil if date.nil?
      d = date.to_date
      anchor = d >> 12                       # gleiches Kalenderdatum nächstes Jahr
      delta = (d.wday - anchor.wday) % 7      # 0..6
      delta -= 7 if delta > 3                 # auf den nächstliegenden gleichen Wochentag
      anchor + delta
    end

    def self.call(source_tournament:, armed: false, release: false, target_season: nil, selected_cat_id: nil, deadline: nil, opts: {})
      new(source_tournament: source_tournament, armed: armed, release: release, target_season: target_season,
        selected_cat_id: selected_cat_id, deadline: deadline, opts: opts).call
    end

    def initialize(source_tournament:, armed: false, release: false, target_season: nil, selected_cat_id: nil, deadline: nil, opts: {})
      @src = source_tournament
      @armed = armed
      @release = release
      @target_season = target_season
      @selected_cat_id = selected_cat_id
      @deadline = deadline
      @opts = opts
    end

    def call
      region = @src.organizer
      region_cc = region&.region_cc
      tournament_cc = @src.tournament_cc
      target_season = @target_season || @src.season&.next_season

      raise "Quell-Turnier hat kein region_cc (organizer=#{region.inspect})" unless region_cc
      raise "Quell-Turnier hat kein tournament_cc (nötig für Typ)" unless tournament_cc
      raise "Keine Ziel-Saison ermittelbar (season.next_season)" unless target_season

      branch_cc = @src.discipline.root.branch_cc
      new_start = self.class.shift_to_next_season_same_weekday(@src.date)
      duration = @src.end_date ? (@src.end_date.to_date - @src.date.to_date).to_i : 0
      new_end = @src.end_date ? new_start + duration : nil
      deadline_date = @deadline&.to_date || (new_start - 14)
      cat = selected_cat_id(branch_cc)

      cc_opts = @opts.merge(armed: @armed)

      # Sollwert der Rückleseprüfung: der Plan des Quell-Turniers. Bei bewusstem tpid-Override
      # gibt es keinen Sollwert — dann wird gelesen und berichtet, aber nicht bewertet.
      expected_plan_name = @opts[:tpid].present? ? nil : tournament_cc.tournament_plan_cc&.name

      meldeliste_args = build_meldeliste_args(region, branch_cc, target_season, new_start, deadline_date, cat)
      meisterschaft_args = build_meisterschaft_args(region, branch_cc, target_season, new_start, new_end, melde_list_id: nil)

      unless @armed
        return {
          dry_run: true, target_season: target_season.name, new_start: new_start, new_end: new_end,
          selected_cat_id: cat, meldeliste_args: meldeliste_args, meisterschaft_args: meisterschaft_args,
          meldeliste_cc_id: nil, meldeliste_created: nil, release_requested: @release,
          turnierplan_erwartet: expected_plan_name, meisterschaft_status: "DRY-RUN (keine CC-Mutation)"
        }
      end

      # ARMED — Meldeliste (HAR-verifiziert, idempotent) inkl. Release-Status.
      melde_row = find_meldeliste_row(region_cc, region, branch_cc, target_season)
      if melde_row
        created = false
      else
        region_cc.post_cc("createMeldelisteCheck", build_check_args(region, branch_cc, target_season), cc_opts)
        region_cc.post_cc("createMeldelisteSave", meldeliste_args, cc_opts)
        melde_row = find_meldeliste_row(region_cc, region, branch_cc, target_season)
        created = true
      end
      melde_list_id = melde_row&.dig(:cc_id)

      # Release-Automatisierung (50-03): NUR bei explizitem release:true (IRREVERSIBEL!) und
      # nur, wenn noch nicht freigegeben. releaseMeldeliste → Status neu lesen.
      if @release && melde_list_id && !melde_row[:status].to_s.match?(/Freigegeben/i)
        region_cc.post_cc("releaseMeldeliste",
          {branchId: branch_cc.cc_id, fedId: region.cc_id, season: target_season.name, meldelisteId: melde_list_id, release: ""}, cc_opts)
        melde_row = find_meldeliste_row(region_cc, region, branch_cc, target_season) || melde_row
      end

      meisterschaft_args[:meldeListId] = melde_list_id

      base = {
        dry_run: false, target_season: target_season.name, new_start: new_start, new_end: new_end,
        selected_cat_id: cat, meldeliste_args: meldeliste_args, meisterschaft_args: meisterschaft_args,
        meldeliste_cc_id: melde_list_id, meldeliste_created: created, release_requested: @release, meldeliste_status: melde_row&.dig(:status)
      }

      # Release-Guard: Meisterschaft nur an eine FREIGEGEBENE Meldeliste binden.
      # releaseMeldeliste wird NICHT automatisiert (irreversibel → 50-03).
      unless melde_row && melde_row[:status].to_s.match?(/Freigegeben/i)
        return base.merge(meisterschaft_status: "SKIPPED — Meldeliste nicht freigegeben (Status=#{melde_row&.dig(:status).inspect}); Release manuell/irreversibel → 50-03")
      end

      # Idempotenz (Bulk/Re-Run): existiert die Meisterschaft schon? Dann NICHT neu anlegen (kein Duplikat).
      existing_meister, existing_pparam = read_meisterschaft_ref(region_cc, region, branch_cc, target_season)
      if existing_meister
        plan_check = verify_tournament_plan(region_cc, existing_pparam, expected_plan_name)
        return base.merge(meisterschaft_cc_id: existing_meister, verbergen_abgesetzt: false,
          turnierplan_check: plan_check,
          meisterschaft_status: "SKIP — Meisterschaft existiert bereits (meisterschaftsId=#{existing_meister}), nicht neu angelegt" \
                                "#{plan_check[:ok] == false ? " — ⚠️ #{plan_check[:hinweis]}" : ""}")
      end

      # Meisterschaft: Check (Prep) → Save → Read meisterschaftsId → Auto-Verbergen (sofort öffentlich!).
      region_cc.post_cc("createMeisterschaftCheck", meisterschaft_opener_args(region, branch_cc, target_season), cc_opts)
      region_cc.post_cc("createMeisterschaftCheck", meisterschaft_args, cc_opts)
      region_cc.post_cc("createMeisterschaftSave", meisterschaft_args, cc_opts)
      meister_cc_id, pparam = read_meisterschaft_ref(region_cc, region, branch_cc, target_season)
      verbergen = false
      if meister_cc_id
        region_cc.post_cc("cc_turnier_status", cc_turnier_status_args(region, branch_cc, target_season, meister_cc_id, meisterschaft_args[:meisterTypeId]), cc_opts)
        verbergen = true
      end

      # Turnierplan zurücklesen, BEVOR "CREATED" gemeldet wird: eine unbekannte tpid speichert
      # die CC stillschweigend (10.07.2026: 36 Turniere ohne Plan). Erfolg heißt hier deshalb
      # "Plan steht", nicht "POST ist durch".
      plan_check = meister_cc_id ? verify_tournament_plan(region_cc, pparam, expected_plan_name) : nil

      status =
        if meister_cc_id.nil?
          "createMeisterschaftSave abgesetzt, meisterschaftsId nicht rücklesbar"
        elsif plan_check[:ok] == false
          "FEHLER — Meisterschaft #{meister_cc_id} angelegt, aber Turnierplan stimmt nicht: #{plan_check[:hinweis]} " \
          "(erwartet #{plan_check[:erwartet].inspect}, gelesen #{plan_check[:gelesen].inspect}, gesendete tpid=#{meisterschaft_args[:tpid]})"
        elsif plan_check[:ok].nil?
          "CREATED (meisterschaftsId=#{meister_cc_id}) + Verbergen abgesetzt — Turnierplan NICHT prüfbar (#{plan_check[:hinweis]})"
        else
          "CREATED (meisterschaftsId=#{meister_cc_id}) + Verbergen abgesetzt — Turnierplan #{plan_check[:gelesen].inspect} verifiziert"
        end

      base.merge(
        meisterschaft_cc_id: meister_cc_id,
        verbergen_abgesetzt: verbergen,
        turnierplan_check: plan_check,
        meisterschaft_status: status
      )
    end

    private

    # HAR-getreu: createMeldelisteSave (tmp/meldeliste_anlegem.har).
    def build_meldeliste_args(region, branch_cc, target_season, new_start, deadline_date, cat)
      {
        fedId: region.cc_id,
        branchId: branch_cc.cc_id,
        disciplinId: "*",
        season: target_season.name,
        catId: "*",
        selectedDisciplinId: @src.discipline.discipline_cc.cc_id,
        selectedCatId: cat,
        meldelistenName: @src.title,
        mschluss: deadline_date.strftime("%Y-%m-%d"),
        stag: "#{new_start.year}-01-01",
        save: ""
      }
    end

    # HAR-getreu: createMeldelisteCheck (nbut = "neu"-Button) — Prep-Schritt VOR dem Save.
    def build_check_args(region, branch_cc, target_season)
      {
        branchId: branch_cc.cc_id,
        fedId: region.cc_id,
        nbut: "",
        season: target_season.name,
        disciplinId: "*",
        catId: "*"
      }
    end

    # HAR-getreu: createMeisterschaftSave (tmp/meisterschaft_anlegem.har). create_from_ba war
    # stale (fehlten tpid/scth/bos/qg/urksig/auzi/besch; countryId="free" statt 9; groupId gab's
    # gar nicht; Spielort fehlte). Format-Felder aus dem Quell-tournament_cc kopiert.
    # tpid siehe #resolve_tpid — die lokale tournament_plan_cc_id ist NICHT die CC-ID.
    def build_meisterschaft_args(region, branch_cc, target_season, new_start, new_end, melde_list_id:)
      tc = @src.tournament_cc
      {
        fedId: region.cc_id,
        branchId: branch_cc.cc_id,
        disciplinId: "*",
        catId: "*",
        season: target_season.name,
        meisterName: @src.title,
        meisterShortName: (@src.shortname.presence || tc&.shortname.presence || "NDM"),
        qg: 0,
        urksig: "",
        meldeListId: melde_list_id,
        mr: 1,
        meisterTypeId: meister_type_id(branch_cc).to_s,
        tpid: resolve_tpid(tc),
        scth: (tc&.shot_clock_minutes || 60),
        bos: (tc&.best_of_sets || 1),
        auzi: "",
        playDate: new_start.strftime("%Y-%m-%d"),
        playDateTo: (new_end || new_start).strftime("%Y-%m-%d"),
        startTime: @src.date.strftime("%H:%M"),
        quote: "",
        sg: "",
        maxtn: "",
        countryId: 9,
        besch: "",
        save: ""
      }.merge(venue_fields(@src.location))
    end

    # Die CC-seitige ID des Turnierplans für createMeisterschaftSave.
    #
    # ⚠️ NICHT `tournament_plan_cc_id` senden: das ist der lokale Fremdschlüssel auf die
    # TournamentPlanCc-Zeile (bei NBV durchweg 1), nicht die ID, die die ClubCloud kennt.
    # Genau diese Verwechslung hat die Klon-Welle vom August 2026 erzeugt — die CC verwarf
    # die unbekannte tpid stillschweigend und legte 36 Turniere OHNE Turnierplan an, was in
    # der CC nachträglich nicht mehr korrigierbar ist (Turnier muss neu angelegt werden).
    #
    # `TournamentPlanCc.cc_id` ist derzeit nicht befüllt: der Detail-Scrape liest nur den
    # Plan-NAMEN (`<td>Turnierplan</td>…<b>NAME</b>`), die Seite enthält keine ID. Bis die
    # ID vorliegt, bricht der Klon hier ab, statt zu raten — lieber kein Turnier als eines,
    # das später nur durch Neuanlage zu reparieren ist. Bewusster Override: opts[:tpid].
    def resolve_tpid(tournament_cc)
      return @opts[:tpid] if @opts[:tpid].present?

      plan = tournament_cc&.tournament_plan_cc
      unless plan
        raise "Quell-Turnier hat keinen Turnierplan hinterlegt — Klon abgebrochen. " \
              "Erst in der ClubCloud einen Turnierplan setzen (sonst entsteht wieder ein " \
              "Turnier ohne Plan) oder tpid bewusst via opts[:tpid] übergeben."
      end
      if plan.cc_id.blank?
        raise "Turnierplan #{plan.name.inspect} (context #{plan.context.inspect}) hat keine " \
              "CC-ID (tournament_plan_ccs.cc_id ist leer) — Klon abgebrochen, damit nicht " \
              "erneut eine falsche tpid gesendet wird. CC-ID auf der Authority nachtragen " \
              "oder tpid bewusst via opts[:tpid] übergeben."
      end
      plan.cc_id
    end

    # Spielort EXAKT aus der lokalen Location (D-50-01-B: Klon kopiert Quelle exakt).
    # 50-02-Deviation: Adresse liegt lokal vor (Location#address/#name/#cc_id) → kein fragiler
    # CC-Template-Read nötig. Adressformat i. d. R. "Straße Nr\nPLZ Ort".
    def venue_fields(location)
      return {pubId: nil, pubName: "", pubStreet: "", pubZipcode: "", pubCity: "", pubPhone: ""} unless location
      lines = location.address.to_s.split("\n").map(&:strip).reject(&:empty?)
      street = lines[0].to_s
      zip = ""
      city = ""
      if lines[1] && (m = lines[1].match(/\A(\d{4,5})\s+(.+)\z/))
        zip = m[1]
        city = m[2]
      else
        city = lines[1].to_s
      end
      {pubId: location.cc_id, pubName: location.name.to_s, pubStreet: street, pubZipcode: zip, pubCity: city, pubPhone: ""}
    end

    # selectedCatId: In dieser CC ist die "Kategorie" faktisch der Championship-Typ
    # (HAR: NDM → catId 7). Ableitung aus dem Typ-Token im Titel; per Arg übersteuerbar.
    def selected_cat_id(branch_cc)
      return @selected_cat_id if @selected_cat_id
      names = (TournamentCc::TYPE_MAP[branch_cc.cc_id] || {}).values.flatten
      token = names.find { |n| /#{Regexp.escape(n)}/.match?(@src.title.to_s) }
      return nil unless token
      CategoryCc.where(branch_cc_id: branch_cc.id).where("name ilike ?", "%#{token}%").first&.cc_id
    end

    # DEV-50-01-A: bevorzugt der gescrapte Quell-Typ, Titel-Regex als Fallback.
    def meister_type_id(branch_cc)
      src_type = @src.tournament_cc&.championship_type_cc_id
      return src_type if src_type.present?
      map = TournamentCc::TYPE_MAP_REV[branch_cc.cc_id] || {}
      map.each { |name, id| return id if /#{name}/.match?(@src.title.to_s) }
      nil
    end

    # Liest die Meldeliste-Zeile per Wildcard-Listing (Datentabelle), Vorbild:
    # RegionCc::RegistrationSyncer#extract_meldeliste_rows. cc_id = letztes Pipe-Segment im
    # showMeldeliste.php-Link der Name-Zelle; Status = Zelle[6] ("Freigegeben" nach Release).
    def find_meldeliste_row(region_cc, region, branch_cc, target_season)
      args = {fedId: region.cc_id, branchId: branch_cc.cc_id, disciplinId: "*", catId: "*", season: target_season.name}
      _, doc = region_cc.post_cc("showMeldelistenList", args, @opts.merge(armed: @armed))
      return nil unless doc
      table = doc.css("table").select { |t| t.css("tr").length > 5 }.last
      return nil unless table
      table.css("tr").drop(1).each do |tr|
        cells = tr.css("td")
        next if cells.length < 8
        next unless cells[1].text.strip == @src.title.to_s
        link = cells[1].css('a[href*="showMeldeliste.php"]').first
        next unless link && (m = link["href"].to_s.match(/\|(\d+)(?:&|$)/))
        return {cc_id: m[1].to_i, status: cells[6].text.strip}
      end
      nil
    end

    # createMeisterschaftCheck-Opener (HAR: t=2, cbut leer) — initialisiert die Create-Form-Session.
    def meisterschaft_opener_args(region, branch_cc, target_season)
      {branchId: branch_cc.cc_id, t: 2, trid: "", fedId: region.cc_id, season: target_season.name,
       disciplinId: "*", catId: "*", meisterTypeId: "*", cbut: ""}
    end

    # Neue meisterschaftsId per Wildcard-Listing lesen: cc_id = Dash-Segment[6] im
    # showMeisterschaft.php-Link (Vorbild TournamentSyncer). Match per Name.
    # Liefert [cc_id, p-Parameter] — der p-Wert ist der Schlüssel zur Detailseite
    # (showMeisterschaft), die als einzige Quelle den gesetzten Turnierplan NENNT.
    def read_meisterschaft_ref(region_cc, region, branch_cc, target_season)
      args = {fedId: region.cc_id, branchId: branch_cc.cc_id, disciplinId: "*", catId: "*",
              meisterTypeId: "*", season: target_season.name, t: 1}
      _, doc = region_cc.post_cc("showMeisterschaftenList", args, @opts.merge(armed: @armed))
      return [nil, nil] unless doc
      link = doc.css("a").find { |a| a.text.to_s.strip == @src.title.to_s }
      return [nil, nil] unless link
      pparam = link["href"].to_s[/[?&]p=([^&]+)/, 1]
      return [nil, nil] unless pparam
      [pparam.split("-")[6]&.to_i&.nonzero?, pparam]
    end

    # Rückleseprüfung des Turnierplans (2026-09-16).
    #
    # Die ClubCloud SPEICHERT eine unbekannte tpid, statt sie abzulehnen — der Klon meldet also
    # auch dann Erfolg, wenn der Plan gar nicht gesetzt wurde. Genau so entstanden am 10.07.2026
    # 36 Turniere ohne Turnierplan, die CC-seitig nur durch Neuanlage zu reparieren sind.
    #
    # Die Detailseite führt keine ID, wohl aber den NAMEN (`<td>Turnierplan</td>…<b>NAME</b>`,
    # Parser-Vorbild: RegionCc::TournamentSyncer). Leeres Feld = tpid war in dieser CC ungültig.
    # Damit ist die Prüfung auch in einem fremden Verband aussagekräftig, dessen ID-Vergabe wir
    # nicht kennen: Statt den IDs zu vertrauen, lesen wir das Ergebnis zurück.
    #
    # Liefert {ok:, erwartet:, gelesen:, hinweis:}; ok=nil heißt „nicht prüfbar" (Seite nicht
    # lesbar) — das ist bewusst kein Fehler, aber auch keine Bestätigung.
    def verify_tournament_plan(region_cc, pparam, expected_plan_name)
      return {ok: nil, erwartet: expected_plan_name, gelesen: nil, hinweis: "kein p-Parameter — Detailseite nicht aufrufbar"} if pparam.blank?

      _, doc = region_cc.get_cc("showMeisterschaft", {p: pparam}, @opts.merge(armed: @armed))
      return {ok: nil, erwartet: expected_plan_name, gelesen: nil, hinweis: "Detailseite nicht lesbar"} unless doc

      row = doc.css("tr.tableContent > td > table > tr").find do |tr|
        tr.css("td")[0]&.text.to_s.strip == "Turnierplan"
      end
      gelesen = row&.css("td")&.[](2)&.css("b")&.text.to_s.strip

      if expected_plan_name.blank?
        {ok: nil, erwartet: nil, gelesen: gelesen.presence,
         hinweis: "tpid wurde per opts übergeben — kein Sollwert, nur gelesen"}
      elsif gelesen.blank?
        {ok: false, erwartet: expected_plan_name, gelesen: nil,
         hinweis: "Turnierplan-Feld LEER — die gesendete tpid ist in dieser ClubCloud unbekannt. " \
                  "Das Turnier ist CC-seitig nur durch Neuanlage zu reparieren."}
      elsif gelesen == expected_plan_name
        {ok: true, erwartet: expected_plan_name, gelesen: gelesen, hinweis: nil}
      else
        {ok: false, erwartet: expected_plan_name, gelesen: gelesen,
         hinweis: "Turnierplan weicht ab — die tpid zeigt in dieser ClubCloud auf einen anderen Plan."}
      end
    end

    # cc_turnier_status = "Verbergen" (HAR entry 56) — Meisterschaft ist nach save sofort öffentlich.
    def cc_turnier_status_args(region, branch_cc, target_season, meisterschafts_id, meister_type_id)
      {fedId: region.cc_id, branchId: branch_cc.cc_id, disciplinId: "", season: target_season.name,
       catId: "", meisterTypeId: meister_type_id, meisterschaftsId: meisterschafts_id}
    end
  end
end
