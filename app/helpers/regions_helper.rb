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
end
