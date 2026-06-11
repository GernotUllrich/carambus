# frozen_string_literal: true

require "net/http/post/multipart"

# Standalone HTTP-Transport-Client fuer das ClubCloud-API.
# Kapselt alle Netzwerkoperationen (GET, POST, multipart POST) gegen das
# PHP-basierte ClubCloud-Admin-Interface.
#
# Kein ORM-Coupling: Die Klasse kennt keine Models, keine DB-Aufrufe.
# Session-Verwaltung: opts[:session_id] wird als PHPSESSID-Cookie gesendet.
# Dry-run-Logik: opts[:armed].blank? == true bedeutet Dry-run; nicht-lesende
# Aktionen werden dann uebersprungen.
#
# Verwendung:
#   client = RegionCc::ClubCloudClient.new(base_url:, username:, userpw:)
#   res, doc = client.get("showLeagueList", {fedId: 20}, {session_id: "abc"})
class RegionCc::ClubCloudClient
  # Abbildung von Action-Namen auf [URL-Pfad, read_only_boolean].
  # Vollstaendig aus app/models/region_cc.rb uebernommen (Zeilen 45-447).
  PATH_MAP = { # maps to path and read_only {true|false}|}
    "home" => ["", true],
    # "showClubList" => "/admin/approvement/player/showClubList.php",
    "createLeagueSave" => ["/admin/league/createLeagueSave.php", false],
    # fedId: 20
    # branchId: 10
    # subBranchId: 2
    # seasonId: 11
    # seasonId: 11
    # leagueName: Oberliga Dreiband
    # leagueShortName: OD
    # reportId: 20
    # prefix: 0
    # staffelName:
    # sportdistrictId: 0
    # sbut:
    "showLeagueList" => ["/admin/report/showLeagueList.php", true],
    "showLeague" => ["/admin/league/showLeague.php", true],

    "admin_report_showLeague" => ["/admin/report/showLeague.php", true],
    # branchId: 6
    # fedId: 20
    # subBranchId: 1
    # seasonId: 8
    # leagueId: 34
    "admin_report_showLeague_create_team" => ["/admin/report/showLeague_create_team.php", false],
    # teamCounter: 2
    # fedId: 20
    # leagueId: 32
    # branchId: 6
    # subBranchId: 1
    # seasonId: 8
    "spielbericht_anzeigen" => ["/admin/reportbuilder2/spielbericht_anzeigen.php", true],
    # p=#{fedId}-#{branchId}-#{cc_id}-&    cc_id vom GamePlanCc
    "showTeam" => ["/admin/announcement/team/showTeam.php", true],
    # fedId: 20,
    # branchId: 6,
    # subBranchId: 1,
    # sportDistrictId: *,
    # clubId: 1004,
    # originalBranchId: 6,
    # seasonId: 1,
    # teamId: 98
    "editTeam" => ["admin/announcement/team/editTeamCheck.php", false],
    "showClubList" => ["/admin/announcement/team/showClubList.php", true],
    # fedId: 20
    # branchId: 6
    # subBranchId: 11
    # sportDistrictId: *
    # statusId: 1   (1 = active)
    "showLeague_show_teamplayer" => ["/admin/report/showLeague_show_teamplayer.php", true],
    # GET
    # p: 187
    "showLeague_add_teamplayer" => ["/admin/report/showLeague_add_teamplayer.php", false],
    # fedId: 20,
    # leagueId: 34,
    # staffelId: 0,
    # branchId: 6,
    # subBranchId: 1,
    # seasonId: 8,
    # p: 187,
    # passnr: 221109,
    "showAnnounceList" => ["/admin/announcement/team/showAnnounceList.php", true],
    # fedId: 20
    # branchId: 10
    # subBranchId: 2
    # sportDistrictId: *
    # clubId: 1011
    # originalBranchId: 10
    # seasonId: 45
    "spielbericht" => ["/admin/bm_mw/spielbericht.php", true],
    # errMsgNew:
    # matchId: 572
    # teamId: 189
    # woher: 1
    # firstEntry: 1
    #  ODER ?!
    # sortKey: NAME
    # branchid: 6
    # woher: 1
    # wettbewerb: 1
    # sportkreis: *
    # saison: 2010/2011
    # partienr: 4003
    # seekBut:
    "showLeague_create_team_save" => ["/admin/report/showLeague_create_team_save.php", false],
    # fedId: 20
    # leagueId: 61
    # branchId: 10
    # subBranchId: 2
    # seasonId: 11
    # ncid: 1573   TODO was ist ncid
    # sbut:
    "spielberichte" => ["/admin/reportbuilder2/spielberichte.php", true],
    # GET Request
    # p: "#{fedId}-#{branchId}"
    "spielberichtCheck" => ["/admin/bm_mw/spielberichtCheck.php", true],
    "spielberichtSave" => ["/admin/bm_mw/spielberichtSave.php", false],
    # "errMsgNew:
    #  fedId: 20
    #  branchId: 6
    #  subBranchId: 1
    #  wettbewerb: 1
    #  leagueId: 34
    #  seasonId: 8
    #  teamId: 185
    #  matchId: 571
    #  saison: 2010/2011
    #  partienr: 4003
    #  woher: 1
    #  woher2: 1
    #  editBut: "
    #  TODO ODER MIT GET-REQUEST??
    #
    # a: 703     party_cc.match_id
    # b: 2        ???
    # c: 193>    team cc_id

    # memo: Die Partien von Florian Knipfer wurden aus der Wertung gestrichen, wegen Einsatz als Ersatz-Spieler in der Bundesliga !!
    # protest:
    # zuNullTeamId: 0
    # wettbewerb: 1
    # partienr: 4004
    # saison:
    # 572-1-1-1-pid1: 10130
    # 572-1-1-1-pid2: 10353
    # 572-1-1-sc1: 125
    # 572-1-1-sc2: 70
    # 572-1-1-in1: 46
    # 572-1-1-in2: 45
    # 572-1-1-br1: 13
    # 572-1-1-br2: 10
    # 572-1-1-vo1:
    # 572-1-1-vo2:
    # 572-2-1-1-pid1: 10243
    # 572-2-1-1-pid2: 0
    # 572-2-1-sc1: 0
    # 572-2-1-sc2: 0
    # 572-2-1-in1:
    # 572-2-1-in2:
    # 572-2-1-br1:
    # 572-2-1-br2:
    # 572-2-1-vo1:
    # 572-2-1-vo2:
    # 572-3-1-1-pid1: 0
    # 572-3-1-1-pid2: 10121
    # 572-3-1-sc1: 9
    # 572-3-1-sc2: 4
    # 572-3-1-in1:
    # 572-3-1-in2:
    # 572-3-1-br1:
    # 572-3-1-br2:
    # 572-3-1-vo1:
    # 572-3-1-vo2:
    # 572-4-1-1-pid1: 0
    # 572-4-1-1-pid2: 10108
    # 572-4-1-sc1: 2
    # 572-4-1-sc2: 8
    # 572-4-1-in1:
    # 572-4-1-in2:
    # 572-4-1-br1:
    # 572-4-1-br2:
    # 572-4-1-vo1:
    # 572-4-1-vo2:
    # 572-6-1-1-pid1: 0
    # 572-6-1-1-pid2: 0
    # 572-6-1-sc1: 8
    # 572-6-1-sc2: 4
    # 572-6-1-in1:
    # 572-6-1-in2:
    # 572-6-1-br1:
    # 572-6-1-br2:
    # 572-6-1-vo1:
    # 572-6-1-vo2:
    # 572-7-1-1-pid1: 0
    # 572-7-1-1-pid2: 10108
    # 572-7-1-sc1: 9
    # 572-7-1-sc2: 6
    # 572-7-1-in1:
    # 572-7-1-in2:
    # 572-7-1-br1:
    # 572-7-1-br2:
    # 572-7-1-vo1:
    # 572-7-1-vo2:
    # 572-8-1-1-pid1: 10130
    # 572-8-1-1-pid2: 10121
    # 572-8-1-sc1: 7
    # 572-8-1-sc2: 5
    # 572-8-1-in1:
    # 572-8-1-in2:
    # 572-8-1-br1:
    # 572-8-1-br2:
    # 572-8-1-vo1:
    # 572-8-1-vo2:
    # 572-9-1-1-pid1: 10243
    # 572-9-1-1-pid2: 0
    # 572-9-1-sc1:
    # 572-9-1-sc2:
    # 572-9-1-in1:
    # 572-9-1-in2:
    # 572-9-1-br1:
    # 572-9-1-br2:
    # 572-9-1-vo1:
    # 572-9-1-vo2:
    "massChangingCheck" => ["/admin/report/massChangingCheck.php", true],
    # fedId: 20,
    # leagueId: 34,
    # branchId: 6,
    # subBranchId: 1,
    # seasonId: 8,
    # staffelId:
    "massChangingCheckAuth" => ["/admin/report/massChangingCheckAuth.php", true],
    # https://e12112e2454d41f1824088919da39bc0.club-cloud.de/admin/report/massChangingCheckAuth.php?

    # teamCounter: 10
    # fedId: 20
    # leagueId: 36
    # branchId: 6
    # subBranchId: 1
    # seasonId: 8
    # editAll:
    # matchId: 715
    "showCategoryList" => ["/admin/einzel/category/showCategoryList.php", true],
    # fedId: 20
    # branchId: 10
    "showCategory" => ["/admin/einzel/category/showCategory.php", true],
    # fedId: 20
    # branchId: 6
    # catId: 14
    "editCategoryCheck" => ["/admin/einzel/category/editCategoryCheck.php", true],
    # fedId: 20
    # branchId: 6
    # catId: 14
    "showTypeList" => ["/admin/einzel/type/showTypeList.php", true],
    # fedId: 20
    # branchId: 10
    "showType" => ["/admin/einzel/type/showType.php", true],
    # fedId: 20
    # branchId: 10
    # season: 2011/2012
    "showSerienList" => ["/admin/einzel/serie/showSerienList.php", true],
    # fedId: 20
    # branchId: 10
    "showSerie" => ["/admin/einzel/serie/showSerie.php", true],
    # fedId: 20
    # branchId: 10
    # season: 2022/2023
    # serienId: 4
    "showGroupList" => ["/admin/einzel/gruppen/showGroupList.php", true],
    # branchId: 10
    "showGroup" => ["/admin/einzel/gruppen/showGroup.php", true],
    # branchId: 10
    "showMeldelistenList" => ["/admin/einzel/meldelisten/showMeldelistenList.php", true],
    # fedId: 20
    # branchId: 10
    # disciplinId: *
    # catId: *
    # season: 2010/2011
    "showMeldeliste" => ["/admin/einzel/meldelisten/showMeldeliste.php", true],
    # Turnier-spezifische Meldeliste (persistiert, stabil) — Plan 31-01 Bug-Fix.
    # p=<fedId>-<branchId>-*-<season>-*--<meisterschaftsId>-2
    "meisterschaft-showMeldeliste" => ["/admin/einzel/meisterschaft/showMeldeliste.php", true],
    # fedId: 20
    # branchId: 10
    # disciplinId: *
    # catId: *
    # season: 2010/2011
    # meldelisteId: 66
    #
    # --- Verbands-Sicht (admin/einzel/meldelisten) Edit-Workflow — Plan 06-03 cc_update_tournament_deadline ---
    # 2-Step-POST-Chain für Meldeschluss-Verschiebung (View-Source-Sniff 2026-05-11):
    #   1. editMeldelisteCheck (Server-Side-Prep, Edit-Form-Render mit prefilled HTML5-date inputs)
    #   2. editMeldelisteSave  (actual write — schreibt meldelistenName + mschluss + stag in CC-DB)
    # Beide Endpoints unter `/admin/einzel/meldelisten/`; nbut="1"/save="1" als PHP-Button-Sentinels.
    # NICHT zu verwechseln mit Phase-4 saveMeldeliste (`/admin/myclub/...` register-flow) — anderer Pfad, anderer Use-Case.
    "editMeldelisteCheck" => ["/admin/einzel/meldelisten/editMeldelisteCheck.php", false],
    "editMeldelisteSave" => ["/admin/einzel/meldelisten/editMeldelisteSave.php", false],
    #
    # --- Verbands-Sicht (admin/einzel/meisterschaft) Teilnehmerliste-Pflege — Plan 07-03 cc_assign_player_to_teilnehmerliste ---
    # Multi-Step-Chain für Akkreditierungs-Workflow (Spieler von Meldeliste → Teilnehmerliste übernehmen):
    #   1. editTeilnehmerlisteCheck (Pre-Read mit <select name="teilnehmerId"> + <select name="meldungId[]">)
    #   2. assignPlayer            (Multi-Add via meldungId[] Array — mehrere Spieler in EINEM Call)
    #   3. editTeilnehmerlisteSave (Commit mit save="1" Sentinel)
    #   4. removePlayer            (Single-Remove via teilnehmerId — Plan 07-04 Inline-Patch ODER Phase 8)
    #   5. showTeilnehmerliste     (Read-only View)
    # Alle Endpoints unter `/admin/einzel/meisterschaft/` (NICHT `meldelisten/` wie Phase 6 — andere Entity!).
    # Identifier ist `meisterschaftsId` (= tournament_cc_id), NICHT meldelisteId.
    # KEIN finalize-State (Kapitalbefund Plan 07-02 D-7-5): Add/Remove werden via Save direkt persistiert.
    "assignPlayer" => ["/admin/einzel/meisterschaft/assignPlayer.php", false],
    "removePlayer" => ["/admin/einzel/meisterschaft/removePlayer.php", false],
    # Plan 33-fix (2026-06-10, HAR-Goldvorlage): atomarer Akkreditierungs-Toggle pro Spieler.
    # POST mit pid=<player_cc_id> verschiebt einen Spieler Meldeliste→Teilnehmerliste (bzw. zurück).
    # Ersetzt den race-anfälligen assignPlayer/meldungId[]-Edit-Buffer-Workflow.
    "showMeldeliste_teilnahme" => ["/admin/einzel/meisterschaft/showMeldeliste_teilnahme.php", false],
    "editTeilnehmerlisteCheck" => ["/admin/einzel/meisterschaft/editTeilnehmerlisteCheck.php", false],
    "editTeilnehmerlisteSave" => ["/admin/einzel/meisterschaft/editTeilnehmerlisteSave.php", false],
    "showTeilnehmerliste" => ["/admin/einzel/meisterschaft/showTeilnehmerliste.php", true],
    # Plan 32-01 cc_fast_assign — Schnellanmeldung (DEFER-D2-2): Spieler direkt via foundpid in
    # Teilnehmerliste eintragen. Kein Pre-Read/Edit-Buffer nötig. Params: meisterschaftsId + foundpid
    # + akkpid (leer=add, befüllt=swap) + fedId + branchId. URL-Pfad basiert auf DEFER-D2-2-HAR-Befund;
    # Live-Smoke empfohlen falls URL-Drift festgestellt wird.
    "cc_fast_assign" => ["/admin/einzel/meisterschaft/cc_fast_assign.php", false],
    # Plan 33-01 (2026-06-11, HAR-Goldvorlage schnellanmeldung_entfernen): atomares Entfernen eines
    # Schnellanmeldungs-Spielers (ohne Meldeliste-Eintrag) GANZ aus der Teilnehmerliste. Spiegel zu
    # cc_fast_assign: dort foundpid=<add>, hier akkpid=<player_cc_id zum Entfernen>, foundpid leer.
    # Kein Edit-Buffer/Save. Für :accredited-Spieler (mit Meldeliste-Eintrag) stattdessen den
    # showMeldeliste_teilnahme-Toggle nutzen (der schiebt zurück in die Meldeliste).
    "cc_remove_tn" => ["/admin/einzel/meisterschaft/cc_remove_tn.php", false],
    #
    # --- Vereins-Sicht (myclub/meldewesen/single) — Plan 04-04 register-Tool ---
    # Diese 3 Endpoints liegen im VEREINS-Bereich (admin/myclub/meldewesen/single),
    # NICHT im Verbands-Bereich (admin/einzel/meldelisten) — gleiche Funktion,
    # anderer Pfad, anderer Action-Name. Ergebnis aus SNIFF v2 (View-Source-Methode).
    # PATH_MAP-Format hier: [path, read_only_bool]; Plan-04-04-Spec-Detail
    # `{method: :post, path: ...}` war schematisch — code-konform mit existing format.
    "addPlayerToMeldeliste" => ["/admin/myclub/meldewesen/single/cc_add.php", false],
    # POST application/x-www-form-urlencoded — fügt Player in Edit-Buffer
    # clubId, fedId, branchId, disciplinId=*, catId=*, season, meldelisteId,
    # firstEntry, rang, gd, selectedClubId, a=<player_cc_id>, d=
    "saveMeldeliste" => ["/admin/myclub/meldewesen/single/editMeldelisteSave.php", false],
    # POST application/x-www-form-urlencoded — committet Edit-Buffer in DB
    # Alle Felder wie addPlayerToMeldeliste + save= als Commit-Marker
    # Server ignoriert a= beim Commit; Player-cc_id IST der Liste-Identifier
    "showCommittedMeldeliste" => ["/admin/myclub/meldewesen/single/showMeldeliste.php", true],
    # Phase 8 Plan 08-02 — cc_unregister_for_tournament (Meldeliste-Pfad).
    # WICHTIG: `a=<Listen-Eintrags-ID || player_cc_id>` (SUBSTRATE-08.md Sektion 2).
    # Symmetrisch zu addPlayerToMeldeliste (Phase 4); 5-Step-Chain analog Phase-7-Lesson.
    "removePlayerFromMeldeliste" => ["/admin/myclub/meldewesen/single/cc_remove.php", false],
    # POST (read-only) — zeigt committed Meldeliste; für Erfolgs-Verifikation nach Save
    # Body enthält <td align="center">{player_cc_id}</td> falls erfolgreich
    # NICHT zu verwechseln mit "showMeldeliste" (Verbands-Pfad oben)
    #
    # --- Plan 14-G.12 — Sportwart-Sicht: Meldelisten-Discovery + Edit-Form ---
    # Komplettiert den myclub-Cluster (addPlayerToMeldeliste + saveMeldeliste +
    # showCommittedMeldeliste + removePlayerFromMeldeliste existierten bereits).
    # NICHT zu verwechseln mit der Verbands-Sicht (LSW)
    # /admin/einzel/meldelisten/showMeldelistenList.php (= Key "showMeldelistenList"
    # ohne Präfix, oben) — die ist für LSW-Verband-Übersicht; Sportwart-Pfad ist
    # club-scoped (clubId-Pflicht-Param).
    "sportwart-showMeldelistenList" => ["/admin/myclub/meldewesen/single/showMeldelistenList.php", true],
    # POST clubId+fedId+branchId+season+disciplinId=*+catId=*
    # Response: <select name="meldelisteId" size="15"> mit
    #   <option value="MID">Title [N Meldungen]</option>
    # Parser-Pattern: doc.css('select[name="meldelisteId"] option')
    "sportwart-editMeldelisteCheck" => ["/admin/myclub/meldewesen/single/editMeldelisteCheck.php", true],
    # POST clubId+fedId+branchId+...+meldelisteId+edit="" (Render der Anmelde-Maske)
    # Verwendung primär als Discovery-HEAD (Form-Render mit allen Hidden-Inputs);
    # für Submit nutzen Tools direkt addPlayerToMeldeliste (cc_add.php) und
    # removePlayerFromMeldeliste (cc_remove.php) — Plan 14-G.12 Substrate.
    "showMeisterschaftenList" => ["/admin/einzel/meisterschaft/showMeisterschaftenList.php", true],
    # fedId: 20
    # branchId: 10
    # disciplinId: *
    # catId: *
    # season: 2010/2011
    # meisterTypeId: *
    # t: 2
    "showMeisterschaft" => ["/admin/einzel/meisterschaft/showMeisterschaft.php", true],
    # fedId: 20
    # branchId: 10
    # disciplinId: *
    # catId: *
    # season: 2010/2011
    # meisterschaftId: 66
    "club-showMeldelistenList" => ["/admin/einzel/clubmeldung/showMeldelistenList.php", true],
    # fedId: 20
    # branchId: 10
    # disciplinId: *
    # catId: *
    # season: 2010/2011
    "club-showMeldeliste" => ["/admin/einzel/clubmeldung/showMeldeliste.php", true],
    # fedId: 20
    # branchId: 10
    # disciplinId: *
    # catId: *
    # season: 2010/2011
    # meldelisteId: 66
    "createMeldelisteSave" => ["/admin/einzel/meldelisten/createMeldelisteSave.php", false],
    # fedId: 20
    # branchId: 10
    # disciplinId: *
    # season: 2010/2011
    # catId: *
    # selectedDisciplinId: 13
    # selectedCatId: 17
    # meldelistenName: 5. Petit Prix Einband Vorrunde 1
    # meldeschluss: 29.01.2011
    # stichtag: 01.01.2011
    # save:
    "createMeldelisteCheck" => ["/admin/einzel/meldelisten/createMeldelisteCheck.php", false],
    # branchId: 6
    # fedId: 20
    # disciplinId: *
    # catId: *
    # season: 2022/2023
    # create:
    "releaseMeldeliste" => ["/admin/einzel/meldelisten/releaseMeldeliste.php", false],
    # branchId: 10,
    # fedId: cc_id,
    # season: season.name,
    # meldelisteId: cc_id_ml
    # release: ""
    "createMeisterschaftSave" => ["/admin/einzel/meisterschaft/createMeisterschaftSave.php", false],
    "editMeisterschaftCheck" => ["/admin/einzel/meisterschaft/editMeisterschaftCheck.php", false],
    "editMeisterschaftSave" => ["/admin/einzel/meisterschaft/editMeisterschaftSave.php", false],
    "deleteMeldeliste" => ["/admin/einzel/meldelisten/deleteMeldeliste.php", false],
    "deleteErgebnis" => ["/admin/einzel/meisterschaft/deleteErgebnis.php", false],
    "showErgebnisliste" => ["/admin/einzel/meisterschaft/showErgebnisliste.php", false],
    "importErgebnisseStep1" => ["/admin/einzel/meisterschaft/importErgebnisseStep1.php", false],
    # fedId: 20
    # branchId: 10
    # disciplinId: *
    # season: 2010/2011
    # catId: *
    # meisterTypeId: *
    # meisterschaftsId: 109
    # ibut
    "importErgebnisseStep2" => ["/admin/einzel/meisterschaft/importErgebnisseStep2.php", false],
    # fedId: 20
    # branchId: 10
    # disciplinId: *
    # season: 2010/2011
    # catId: *
    # meisterTypeId: *
    # meisterschaftsId: 109
    # importFile - filename="result3.csv"
    # saveBut
    "importErgebnisseStep3" => ["/admin/einzel/meisterschaft/importErgebnisseStep3.php", false],
    # fedId: 20
    # branchId: 10
    # disciplinId: *
    # season: 2010/2011
    # catId: *
    # meisterTypeId: *
    # meisterschaftsId: 109
    # saveBut
    "importRangliste1" => ["/admin/einzel/meisterschaft/importRangliste1.php", false],
    # fedId: 20
    # branchId: 10
    # disciplinId: 9
    # season: 2010/2011
    # catId: *
    # meisterTypeId: *
    # meisterschaftsId: 109
    # importBut
    "importRangliste2" => ["/admin/einzel/meisterschaft/importRangliste2.php", false],
    # fedId: 20
    # branchId: 10
    # disciplinId: 9
    # season: 2010/2011
    # catId: *
    # meisterTypeId: *
    # meisterschaftsId: 109
    # ranglistenimport - filename="rangliste3.csv"
    # importBut
    "showRangliste" => ["/admin/einzel/meisterschaft/showRangliste.php", false],
    # fedId: 20
    # branchId: 10
    # disciplinId: 9
    # season: 2010/2011
    # catId: *
    # meisterTypeId: *
    # meisterschaftsId: 109
    "releaseRangliste.php" => ["/admin/einzel/meisterschaft/releaseRangliste.php.php", false],
    #  fedId: 20
    #  branchId: 10
    #   disciplinId: 9
    #   season: 2010/2011
    #   catId: *
    #   meisterTypeId: *
    #   meisterschaftsId: 109
    #   releaseBut
    "suche" => ["suche.php", true]
    # c:
    # f:
    # 10
    # v:
    # Gerd
    # n:
    # Schmitz
    # pa:
    # lastPageNo:
    # nextPageNo:
    # 1
    # pno:
    # s:
  }.freeze

  attr_reader :base_url, :username, :userpw

  # Plan 14-G.13.1 Task 2: Net::HTTP Keep-Alive — TLS-Handshake nur beim ersten Call
  # pro (host, port)-Combo, danach Connection-Reuse innerhalb dieses Client-Lifecycles.
  HTTP_KEEPALIVE_TIMEOUT = 30 # Sekunden

  def initialize(base_url:, username:, userpw:)
    @base_url = base_url
    @username = username
    @userpw = userpw
    @http_pool = {}
  end

  # Plan 14-G.13.1 Task 2: Reusable Net::HTTP-Instance pro (host, port).
  # use_ssl wird einmalig gesetzt; keep_alive_timeout ermöglicht Connection-Reuse.
  def http_for(uri)
    key = [uri.host, uri.port]
    @http_pool[key] ||= begin
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.keep_alive_timeout = HTTP_KEEPALIVE_TIMEOUT
      http
    end
  end

  # Plan 14-G.13.1 Task 2: Defensive Retry bei Stale-Connection
  # (Server hat keep-alive Connection im Pool gedroppt). Pool-Entry verwerfen + 1× retry.
  def request_with_keepalive_retry(uri)
    http = http_for(uri)
    yield http
  rescue Errno::EPIPE, IOError => e
    Rails.logger.warn "[ClubCloudClient] Stale connection (#{e.class}) for #{uri.host}:#{uri.port}, retrying with fresh instance"
    @http_pool.delete([uri.host, uri.port])
    http = http_for(uri)
    yield http
  end

  # Fuehrt einen GET-Request durch, ermittelt URL aus PATH_MAP[action][0].
  # Wirft ArgumentError wenn action unbekannt.
  # Gibt [Net::HTTPResponse, Nokogiri::HTML::Document] zurueck.
  def get(action, get_options = {}, opts = {})
    raise ArgumentError, "Unknown Action", caller unless PATH_MAP[action].present?

    get_options[:referer] ||= ""
    url = base_url + PATH_MAP[action][0]
    get_with_url(action, url, get_options, opts)
  end

  # Fuehrt einen GET-Request mit expliziter URL durch (ohne PATH_MAP-Lookup).
  # Gibt [Net::HTTPResponse, Nokogiri::HTML::Document] zurueck.
  def get_with_url(action, url, get_options = {}, opts = {})
    referer = base_url + get_options.delete(:referer).to_s
    Rails.logger.debug "[get_cc] GET #{action} with payload #{get_options}"
    uri = URI(url)
    req = Net::HTTP::Get.new(uri.path)
    req.set_form_data(get_options)
    # Einen neuen Request mit Query-String bauen (set_form_data setzt body, nicht URI)
    req = Net::HTTP::Get.new(uri.path + ("?" unless /\?$/.match?(uri.path)).to_s + req.body)
    req["cookie"] = "PHPSESSID=#{opts[:session_id]}" if opts[:session_id].present?
    req["referer"] = referer if referer.present?
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    # Plan 14-G.13.1 Task 2: Net::HTTP Keep-Alive via http_for-Pool + EPIPE-Retry.
    res = request_with_keepalive_retry(uri) { |http| http.request(req) }
    elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round(1)
    Rails.logger.info "[CC-LATENCY] verb=GET action=#{action} host=#{uri.host} path=#{uri.path} elapsed_ms=#{elapsed_ms} status=#{res&.code} body_bytes=#{res&.body&.bytesize}"
    doc = if res.message == "OK"
      Nokogiri::HTML(res.body)
    else
      Nokogiri::HTML(res.message)
    end
    [res, doc]
  end

  # Fuehrt einen form-encoded POST-Request durch.
  # Dry-run: opts[:armed].blank? => true => nicht-lesende Aktionen werden uebersprungen.
  # Gibt [Net::HTTPResponse, Nokogiri::HTML::Document] oder [nil, nil] im Dry-run zurueck.
  def post(action, post_options = {}, opts = {})
    dry_run = opts[:armed].blank?
    referer = post_options.delete(:referer)
    referer = referer.present? ? base_url + referer : nil
    if PATH_MAP[action].present?
      url = base_url + PATH_MAP[action][0]
      read_only_action = PATH_MAP[action][1]
      if read_only_action
        Rails.logger.debug "[#{action}] POST #{PATH_MAP[action][0]} with payload #{post_options}"
      else
        Rails.logger.debug "[#{action}] #{"WILL " if dry_run}POST #{action} #{PATH_MAP[action][0]} with payload #{post_options}"
      end
      doc = nil
      res = nil
      if !dry_run || read_only_action
        uri = URI(url)
        req = Net::HTTP::Post.new(uri.request_uri)
        req["cookie"] = "PHPSESSID=#{opts[:session_id]}"
        req["Content-Type"] = "application/x-www-form-urlencoded"
        req["referer"] = referer if referer.present?
        req["cache-control"] = "max-age=0"
        req["upgrade-insecure-requests"] = "1"
        req["accept-language"] = "de-DE,de;q=0.9,en-US;q=0.8,en;q=0.7,fr;q=0.6"
        req["accept"] =
          "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9"
        # Plan 14-G.13 (2026-05-18): `opts[:keep_blanks]` (Array von Keys) erlaubt es,
        # leere Werte gezielt durchzulassen. Brower-Init-Calls senden `edit=` (key
        # vorhanden, value leer); semantisch unterscheidet PHP zwischen "isset+empty"
        # und "nicht-isset". Default-Filter wirft beides als blank raus.
        keep_blanks = Array(opts[:keep_blanks]).map(&:to_sym)
        filtered = post_options.reject { |k, v| v.blank? && !keep_blanks.include?(k.to_sym) }
        req.set_form_data(filtered)
        t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        # Plan 14-G.13.1 Task 2: Net::HTTP Keep-Alive via http_for-Pool + EPIPE-Retry.
        res = request_with_keepalive_retry(uri) { |http| http.request(req) }
        elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round(1)
        Rails.logger.info "[CC-LATENCY] verb=POST action=#{action} host=#{uri.host} path=#{uri.path} elapsed_ms=#{elapsed_ms} status=#{res&.code} body_bytes=#{res&.body&.bytesize} read_only=#{read_only_action ? 1 : 0}"
        doc = if res.message == "OK"
          Nokogiri::HTML(res.body)
        else
          Nokogiri::HTML(res.message)
        end
      end
    end
    [res, doc]
  end

  # Fuehrt einen multipart POST-Request durch (fuer Datei-Uploads).
  # Dry-run: opts[:armed].blank? => true => nicht-lesende Aktionen werden uebersprungen.
  # Gibt [Net::HTTPResponse, Nokogiri::HTML::Document] oder [nil, nil] im Dry-run zurueck.
  def post_with_formdata(action, post_options = {}, opts = {})
    dry_run = opts[:armed].blank?
    referer = post_options.delete(:referer)
    referer = referer.present? ? base_url + referer : nil
    if PATH_MAP[action].present?
      url = base_url + PATH_MAP[action][0]
      read_only_action = PATH_MAP[action][1]
      if read_only_action
        Rails.logger.debug "[#{action}] POST #{PATH_MAP[action][0]} with payload #{post_options}"
      else
        Rails.logger.debug "[#{action}] #{"WILL " if dry_run}POST #{action} #{PATH_MAP[action][0]} with payload #{post_options}"
      end
      doc = nil
      res = nil
      if !dry_run || read_only_action
        uri = URI(url)
        req = Net::HTTP::Post::Multipart.new(uri.request_uri, post_options)
        req["cookie"] = "PHPSESSID=#{opts[:session_id]}"
        req["referer"] = referer if referer.present?
        req["cache-control"] = "max-age=0"
        req["upgrade-insecure-requests"] = "1"
        req["accept-language"] = "de-DE,de;q=0.9,en-US;q=0.8,en;q=0.7,fr;q=0.6"
        req["accept"] =
          "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9"
        t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        # Plan 14-G.13.1 Task 2: Net::HTTP Keep-Alive via http_for-Pool + EPIPE-Retry.
        res = request_with_keepalive_retry(uri) { |http| http.request(req) }
        elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round(1)
        Rails.logger.info "[CC-LATENCY] verb=POST-MULTIPART action=#{action} host=#{uri.host} path=#{uri.path} elapsed_ms=#{elapsed_ms} status=#{res&.code} body_bytes=#{res&.body&.bytesize} read_only=#{read_only_action ? 1 : 0}"
        doc = if res.message == "OK"
          Nokogiri::HTML(res.body)
        else
          Nokogiri::HTML(res.message)
        end
      end
    end
    [res, doc]
  end
end
