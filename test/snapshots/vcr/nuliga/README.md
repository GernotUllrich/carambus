# NuLiga (BBV) — Recon-Fixtures (Phase 13, 2026-07-15)

Roh-HTML-Belege je NuLiga-Seitentyp von `bbv-billard.liga.nu`, ISO-8859-1 → UTF-8 konvertiert (`iconv`).
Read-only geholt (öffentliche Seiten), Saison **Pool 25/26**, group **1001** als durchgängiges Beispiel.
Dienen der Analyse (Phase 13) und als spätere Parser-Vorlage (Phase 14 → echte VCR-Cassettes).

| Datei | Seitentyp (wa/-Aktion) | Beispiel-URL-Params |
|-------|------------------------|---------------------|
| 01_leaguePage_pool_2025-26.html | `leaguePage` | `championship=BBV Pool 25/26` |
| 02_groupPage_pool_group1001.html | `groupPage` (Liga: Tabelle + Teams + Meetings) | `championship=…&group=1001` |
| 03_groupMeetingReport_7112978.html | `groupMeetingReport` (Spielbericht/Einzelspiele) | `meeting=7112978&…&group=1001` |
| 04_teamPortrait_1809539.html | `teamPortrait` (Team-Detail) | `teamtable=1809539&…` |
| 05_clubInfoDisplay_383.html | `clubInfoDisplay` (Verein) | `club=383` |
| 06_groupPlayerRankingLists.html | `groupPlayerRankingLists` (Spieler-Rangliste) | `type=rankingPoints&…&group=1001` |
| 07_groupPage_meetings.html | `groupPage` (Spielplan-Ansicht) | `displayDetail=meetings&…&group=1001` |
| 08_playerInfo_person1625.html | `playerPortrait` (Spieler) | `season=Pool 2025/26&person=1625` |

Basis-URL: `https://bbv-billard.liga.nu/cgi-bin/WebObjects/nuLigaBILLARDDE.woa/wa/`
