module RegionsHelper
  # Deutschlandkarte (08-04/08-05). Region-basiert: 15 Landesverbands-Territorien als Polygone.
  # Geodaten gebuendelt (lib/data), einmalig als Konstante geladen (kein Request-/DB-Overhead).
  #
  # germany_regions.json: aus Bundeslaender- + Regierungsbezirk-GeoJSON (isellsoap/deutschlandGeoJSON,
  #   dl-de/by-2-0) gebildet (shapely-Union: NBV=SH+HH+HB+MV, BVW=Munster+Detmold+Arnsberg; BVNR=
  #   Duesseldorf, BLMR=Koeln; Rest 1:1), equirektangular projiziert (cos-Breitenkorrektur).
  #   Struktur: { "viewBox"=>[w,h], "proj"=>{lonmin,latmax,kx,scale,pad}, "regions"=>{ SHORT=>{path,centroid} } }
  # de_plz_coords.json: DE-PLZ -> [lat, lon] (Quelle: WZBSocialScienceCenter/plz_geocoord, OSM/Nominatim).
  GERMANY_MAP_DATA = JSON.parse(File.read(Rails.root.join("lib/data/germany_regions.json"))).freeze
  PLZ_COORDS = JSON.parse(File.read(Rails.root.join("lib/data/de_plz_coords.json"))).freeze

  # Per-Region Logo-Anpassungen (nur Versatz, gleiche Groesse). Berlin (BVB) liegt als Enklave in
  # Brandenburg (BBBV): BVB nach rechts-oben herausversetzt (via Reihenfolge zuletzt = vorne),
  # BBBV nach unten-links -> beide sichtbar, getrennt.
  MAP_LOGO_OVERRIDES = {
    "BVB" => { "dx" => 24, "dy" => -22 },
    "BBBV" => { "dx" => -10, "dy" => 8 }
  }.freeze

  # viewBox der Karte (aus der Projektion).
  def germany_map_viewbox
    w, h = GERMANY_MAP_DATA["viewBox"]
    "0 0 #{w} #{h}"
  end

  # Projiziert beliebige lat/lon in den Karten-viewBox — DIESELBE Projektion wie die Region-Polygone,
  # damit Dichte-Punkte deckungsgleich in den Regionen liegen.
  def project_lonlat(lon, lat)
    p = GERMANY_MAP_DATA["proj"]
    [(p["pad"] + (lon - p["lonmin"]) * p["kx"] * p["scale"]).round(1),
     (p["pad"] + (p["latmax"] - lat) * p["scale"]).round(1)]
  end

  # Kuratierte lokale Verbands-Logos (app/assets/images/logos/<Kuerzel>.png), memoisiert.
  # Lokal > Remote: schneller, zuverlaessig, kein externer Request, hoehere Qualitaet.
  def local_logo_shortnames
    @local_logo_shortnames ||=
      Dir[Rails.root.join("app/assets/images/logos/*.png")].map { |f| File.basename(f, ".png") }.to_set
  end

  # Logo-Quelle einer Region: lokales Asset (falls vorhanden) sonst die Remote-URL (region.logo).
  def region_logo_src(region)
    if local_logo_shortnames.include?(region.shortname)
      image_path("logos/#{region.shortname}.png")
    else
      region.logo.presence
    end
  end

  # Die 15 Karten-Regionen (Reihenfolge aus den Geodaten), je mit Polygon-Pfad, Zentroid,
  # Region-Record (Batch-Lookup, kein N+1), Logo-Quelle und Link/A11y. Regionen ohne DB-Record
  # werden ausgelassen.
  def germany_regions
    @germany_regions ||= begin
      recs = Region.where(shortname: GERMANY_MAP_DATA["regions"].keys).index_by(&:shortname)
      GERMANY_MAP_DATA["regions"].filter_map do |shortname, data|
        region = recs[shortname]
        next unless region

        {
          shortname: shortname,
          path: data["path"],
          centroid: data["centroid"],
          href: region_path(region),
          aria_label: region.name,
          title: "#{shortname} — #{region.name}",
          logo: region_logo_src(region)
        }
      end
    end
  end

  # Vereinsdichte (Stufe 1): Venue-Standorte aus Location-Adressen (5-stellige PLZ), ueber die
  # gebuendelte PLZ-Tabelle zu Koordinaten und mit project_lonlat in den viewBox projiziert,
  # gruppiert nach Punkt (count = Anzahl Venues). Read-only, memoisiert. -> [{x, y, count}]
  def club_density_points
    @club_density_points ||= begin
      buckets = Hash.new(0)
      Location.where.not(address: [nil, ""]).find_each do |loc|
        plz = loc.address.to_s[/\b(\d{5})\b/, 1]
        next unless plz
        coord = PLZ_COORDS[plz]
        next unless coord

        x, y = project_lonlat(coord[1], coord[0]) # coord = [lat, lon]
        buckets[[x, y]] += 1
      end
      buckets.map { |(x, y), count| { x: x, y: y, count: count } }
    end
  end

  # 08-06: Regionale Club-Karte. Clubs EINER Region an ihren Standorten (Location-PLZ projiziert,
  # gleiche 08-05-Projektion), read-only, je Region memoisiert. Ableitungen (Spieler/Sparten) als
  # Sammel-Queries ueber die Club-Ids gebatcht (KEIN N+1). -> [{x, y, shortname, href, logo,
  # players, branches}]; Clubs ohne aufloesbare PLZ werden ausgelassen (Datenluecke, kein Fehler).
  def region_club_points(region)
    (@region_club_points ||= {})[region.id] ||= begin
      clubs = Club.where(region_id: region.id).to_a
      club_ids = clubs.map(&:id)

      # Batch: Spieler je Club = season_participations der aktuellen Saison (ein Aggregat-Query).
      season = Season.current_season
      players_by_club =
        if season && club_ids.any?
          SeasonParticipation.where(club_id: club_ids, season_id: season.id).group(:club_id).count
        else
          {}
        end

      # Batch: aktive Sparten je Club = distinct Branch (Discipline) ueber league_teams -> leagues.branch_id.
      branch_pairs =
        if club_ids.any?
          LeagueTeam.where(club_id: club_ids).joins(:league)
                    .where.not(leagues: { branch_id: nil })
                    .distinct.pluck(:club_id, "leagues.branch_id")
        else
          []
        end
      branch_names = Discipline.where(id: branch_pairs.map(&:last).uniq).pluck(:id, :name).to_h
      branches_by_club = Hash.new { |h, k| h[k] = [] }
      branch_pairs.each { |cid, bid| branches_by_club[cid] << branch_names[bid] }

      # Batch: Adressen je Club (club_locations-Join, ein Query) — erste mit aufloesbarer PLZ gewinnt.
      addrs_by_club = Hash.new { |h, k| h[k] = [] }
      if club_ids.any?
        Location.joins(:club_locations)
                .where(club_locations: { club_id: club_ids })
                .where.not(address: [nil, ""])
                .pluck("club_locations.club_id", :address)
                .each { |cid, addr| addrs_by_club[cid] << addr }
      end

      clubs.filter_map do |club|
        coord = nil
        addrs_by_club[club.id].each do |addr|
          plz = addr.to_s[/\b(\d{5})\b/, 1]
          coord = plz && PLZ_COORDS[plz]
          break if coord
        end
        next unless coord

        x, y = project_lonlat(coord[1], coord[0]) # coord = [lat, lon]
        {
          x: x, y: y,
          shortname: club.shortname.presence || club.name,
          href: club_path(club),
          logo: club.logo.presence,
          players: players_by_club[club.id].to_i,
          branches: branches_by_club[club.id].compact.uniq.sort
        }
      end
    end
  end

  # SVG-Polygon-Pfad EINER Region (aus den 08-05-Geodaten). nil, wenn keine Kartengeometrie vorliegt.
  def region_map_path(shortname)
    GERMANY_MAP_DATA["regions"].dig(shortname, "path")
  end

  # Bounding-Box der Region als viewBox-Tupel [x, y, w, h] (+ Padding), aus den Pfad-Koordinaten
  # berechnet. nil ohne Geometrie. Dient als Karten-Ausschnitt fuer die Club-Karte.
  def region_map_bbox(shortname, pad: 8)
    path = region_map_path(shortname)
    return nil unless path

    nums = path.scan(/-?\d+(?:\.\d+)?/).map(&:to_f)
    return nil if nums.size < 4

    xs = nums.each_slice(2).map(&:first)
    ys = nums.each_slice(2).map(&:last)
    minx, maxx = xs.minmax
    miny, maxy = ys.minmax
    [(minx - pad).round(1), (miny - pad).round(1),
     (maxx - minx + 2 * pad).round(1), (maxy - miny + 2 * pad).round(1)]
  end
end
