module RegionsHelper
  # Deutschlandkarte (08-04): Zuordnung Karten-Flaeche -> Landesverband (Region.shortname).
  # 16 Bundeslaender auf 15 LVs (validiert 2026-07-05, DB + User):
  #   - NBV sammelt den Norden: Hamburg, Bremen, Schleswig-Holstein, Mecklenburg-Vorpommern.
  #   - Niedersachsen ist separat (BLVN).
  #   - NRW ist in DREI klickbare Teilflaechen zerlegt (dort liegen die Daten): BLMR/BVNR/BVW.
  #     Der NRW-Dachverband BVNRW (fast leer) bekommt KEINE Flaeche.
  # Reihenfolge ~ Nord->Sued fuer stabile, lesbare Ausgabe. Werte = Region.shortname.
  REGION_MAP_AREAS = {
    "sh" => "NBV",     # Schleswig-Holstein
    "hh" => "NBV",     # Hamburg
    "hb" => "NBV",     # Bremen
    "mv" => "NBV",     # Mecklenburg-Vorpommern
    "ni" => "BLVN",    # Niedersachsen
    "be" => "BVB",     # Berlin
    "bb" => "BBBV",    # Brandenburg
    "st" => "BLVSA",   # Sachsen-Anhalt
    "nw_bvnr" => "BVNR", # NRW / Niederrhein
    "nw_bvw" => "BVW",   # NRW / Westfalen
    "nw_blmr" => "BLMR", # NRW / Mittleres Rheinland
    "he" => "HBU",     # Hessen
    "th" => "TBV",     # Thueringen
    "sn" => "SBV",     # Sachsen
    "rp" => "BVRP",    # Rheinland-Pfalz
    "sl" => "BVS",     # Saarland
    "bw" => "BVBW",    # Baden-Wuerttemberg
    "by" => "BBV"      # Bayern
  }.freeze

  # Karten-Layout (08-04): [cx, cy] = Kachel-Zentren im viewBox GERMANY_MAP_VIEWBOX. Aus realen
  # LV-Schwerpunkten (lat/lon) mit DERSELBEN Projektion wie die Aussengrenze erzeugt (equirektangular
  # + cos-Breitenkorrektur) -> Kacheln sitzen geografisch korrekt in der Kontur. Enklaven/kleine
  # Staaten pixel-nachjustiert. NRW = 3 Kacheln (BVNR/BVW/BLMR); NBV sammelt SH/HH/HB/MV.
  GERMANY_MAP_LAYOUT = {
    "sh" => [114, 42], "mv" => [196, 73], "hh" => [123, 75],
    "hb" => [85, 92], "ni" => [108, 114], "bb" => [203, 128],
    "be" => [220, 115], "st" => [169, 145], "sn" => [214, 184],
    "th" => [150, 190], "nw_bvnr" => [26, 164], "nw_bvw" => [68, 153],
    "nw_blmr" => [43, 197], "he" => [95, 204], "rp" => [57, 230],
    "sl" => [37, 257], "bw" => [95, 290], "by" => [166, 278]
  }.freeze

  # viewBox der Karte (aus der Projektion).
  GERMANY_MAP_VIEWBOX = "0 0 270 359".freeze

  # Reale, vereinfachte Deutschland-Aussengrenze als SVG-Pfad (Quelle: isellsoap/deutschlandGeoJSON,
  # dl-de/by-2-0; low-res, equirektangular projiziert mit cos-Breitenkorrektur -> deckungsgleich mit
  # GERMANY_MAP_LAYOUT). Inline (CSP-konform, kein externer Request).
  GERMANY_OUTLINE_PATH = "M79.2,10.0 L80.2,11.2 L77.8,13.3 L78.1,16.2 L79.8,17.2 L90.3,15.5 L101.5,18.2 L103.1,20.5 L106.6,18.8 L107.3,21.1 L112.2,17.3 L111.9,19.2 L118.4,22.5 L121.5,21.5 L123.7,26.2 L122.2,24.9 L121.7,26.1 L123.6,26.3 L123.5,31.5 L118.3,35.1 L128.1,35.6 L126.3,41.9 L128.9,37.4 L131.4,36.5 L141.9,42.2 L148.1,38.8 L153.5,38.4 L151.6,40.0 L152.6,46.8 L143.3,53.1 L147.0,57.4 L154.9,54.8 L157.1,56.1 L157.1,58.3 L159.2,57.3 L162.4,59.8 L163.2,56.8 L160.3,55.6 L163.5,54.4 L163.4,56.8 L167.1,51.5 L164.4,52.3 L168.6,48.8 L179.7,47.5 L180.7,48.9 L179.9,47.6 L186.6,42.5 L191.5,34.4 L203.6,36.4 L196.0,37.8 L196.8,37.8 L195.8,39.3 L198.8,38.2 L199.4,40.4 L205.2,36.3 L207.2,39.5 L207.5,43.2 L212.4,45.2 L214.1,47.6 L213.3,48.5 L216.0,47.8 L215.1,49.2 L217.1,51.5 L223.6,48.0 L226.6,51.0 L224.9,54.2 L229.6,58.8 L227.1,61.3 L230.2,59.4 L229.3,55.9 L231.0,55.9 L230.8,58.3 L233.1,58.0 L233.2,55.6 L232.0,53.8 L238.0,58.5 L237.0,59.1 L237.9,61.3 L226.6,61.6 L233.0,66.1 L239.6,66.8 L237.8,68.4 L239.4,68.5 L240.8,72.0 L240.2,75.4 L244.2,87.6 L242.3,90.1 L241.4,96.7 L235.8,100.7 L235.2,105.9 L249.4,117.3 L248.3,119.3 L249.2,120.8 L246.4,125.3 L247.5,129.9 L251.0,132.0 L250.2,137.2 L252.2,139.3 L251.2,145.0 L247.9,150.2 L252.1,157.0 L251.0,161.7 L257.4,165.0 L258.3,170.6 L260.0,172.6 L257.3,186.4 L253.9,193.5 L251.3,193.6 L248.6,192.4 L249.7,189.0 L247.2,189.4 L248.2,186.5 L245.6,183.8 L242.8,185.7 L239.9,183.7 L238.7,187.2 L242.9,188.6 L242.1,190.9 L230.7,194.6 L227.8,198.3 L219.6,198.5 L217.3,203.6 L214.9,201.6 L213.5,204.2 L211.4,203.8 L210.0,207.8 L205.5,207.4 L204.0,211.5 L199.9,209.6 L196.6,212.3 L191.4,212.2 L187.3,217.5 L186.3,221.8 L185.0,221.6 L182.6,215.5 L179.7,218.5 L182.7,221.1 L182.7,224.7 L184.3,226.9 L192.3,232.7 L190.2,238.7 L188.3,240.2 L191.7,243.2 L193.4,249.4 L194.9,250.0 L195.4,254.3 L198.7,257.8 L205.5,259.7 L209.5,266.8 L215.6,270.9 L215.6,273.8 L221.9,275.3 L227.4,282.9 L226.1,285.2 L226.7,290.9 L224.3,294.1 L218.4,290.7 L216.5,292.1 L215.8,300.2 L212.4,303.4 L201.0,307.8 L197.9,311.5 L204.6,323.1 L202.2,328.3 L205.8,328.8 L207.5,332.3 L205.0,339.9 L199.2,335.7 L199.9,333.3 L198.7,330.8 L193.8,330.6 L191.1,332.8 L189.2,329.7 L184.4,330.7 L184.3,328.0 L182.1,329.8 L183.0,334.0 L167.4,334.1 L165.9,337.9 L162.0,337.8 L160.6,339.6 L161.6,340.8 L159.3,340.5 L157.5,343.2 L156.1,343.1 L156.7,341.2 L149.4,342.9 L148.0,339.4 L146.3,339.4 L147.8,337.7 L146.8,336.7 L143.8,337.7 L139.1,335.2 L138.0,336.8 L134.5,334.7 L135.6,341.3 L134.5,343.7 L127.4,348.4 L128.9,343.1 L125.3,344.7 L125.2,340.3 L122.6,339.0 L121.9,336.2 L119.3,337.1 L116.5,334.2 L114.2,336.5 L96.6,324.3 L101.4,331.1 L99.9,331.7 L95.2,327.6 L93.8,328.3 L95.6,329.9 L92.4,331.7 L90.2,327.9 L89.2,328.8 L89.9,330.6 L88.0,329.8 L88.0,326.8 L83.6,324.7 L79.1,330.6 L81.0,332.2 L84.7,330.7 L84.1,334.0 L82.3,332.4 L80.6,333.8 L81.4,334.9 L78.5,335.4 L73.6,332.9 L70.5,335.7 L66.6,336.2 L63.2,334.3 L59.1,336.8 L58.1,335.7 L59.1,334.3 L57.4,334.9 L54.8,329.9 L57.8,317.8 L56.3,315.1 L56.6,311.4 L61.1,302.3 L60.8,299.3 L63.6,289.1 L70.5,281.7 L74.3,274.4 L66.4,270.7 L58.1,270.8 L53.0,265.1 L48.8,268.1 L43.5,266.4 L42.4,268.2 L41.7,264.9 L38.7,263.4 L36.4,263.8 L36.3,266.5 L33.6,265.9 L28.1,254.2 L23.2,252.9 L23.4,248.1 L27.6,241.6 L27.9,237.9 L22.0,236.7 L16.2,227.0 L18.7,221.3 L18.1,219.3 L24.6,215.1 L22.8,213.0 L23.7,210.2 L22.5,208.1 L18.2,205.6 L21.1,202.7 L18.2,202.5 L16.7,198.7 L12.5,195.0 L15.5,192.7 L15.8,189.4 L13.9,189.0 L14.3,186.8 L10.9,187.0 L10.0,184.2 L12.7,184.5 L18.2,179.4 L17.4,178.5 L18.8,177.7 L16.0,178.4 L15.6,175.4 L19.8,170.1 L19.5,163.9 L16.0,159.7 L16.7,157.3 L12.5,153.8 L13.6,152.6 L12.5,150.2 L18.1,149.3 L16.4,147.3 L17.8,146.6 L24.9,150.1 L24.5,148.0 L33.8,146.9 L36.3,142.7 L32.6,140.8 L32.6,139.3 L42.7,132.1 L41.6,129.7 L43.0,125.9 L41.0,122.1 L39.4,123.5 L34.4,122.3 L32.2,118.3 L34.5,117.9 L33.3,116.8 L33.8,114.3 L42.2,114.8 L43.4,105.7 L47.9,99.1 L47.0,93.6 L48.6,90.3 L46.4,88.6 L47.6,84.6 L40.8,83.3 L41.7,75.8 L44.4,75.8 L43.3,73.9 L45.1,71.6 L49.5,69.2 L68.5,68.0 L72.8,74.8 L72.3,76.6 L69.9,77.0 L70.1,78.7 L75.0,81.6 L76.7,78.7 L76.7,76.3 L74.4,76.3 L75.5,72.4 L82.2,74.8 L83.3,76.1 L82.3,77.2 L83.7,76.4 L81.3,68.8 L84.7,60.7 L92.2,62.9 L98.1,61.4 L94.4,60.0 L90.5,54.5 L94.9,53.4 L93.4,49.7 L91.6,50.1 L90.1,47.9 L90.9,44.5 L94.1,41.8 L91.2,44.0 L83.9,42.2 L84.6,39.9 L86.8,39.9 L84.7,38.6 L92.5,37.5 L96.0,34.9 L95.1,32.8 L92.8,35.4 L90.1,35.0 L92.4,29.6 L90.3,29.4 L90.6,27.3 L86.9,23.7 L84.2,16.9 L79.5,18.6 L76.6,17.4 L75.7,22.7 L76.2,15.9 L79.2,10.0 Z".freeze

  # Kacheln, die als Enklave/kleiner Stadtstaat kleiner gerendert werden (Ueberlappung vermeiden).
  GERMANY_MAP_SMALL_TILES = %w[be hb sl].freeze

  # Region-Records fuer alle Karten-Kuerzel in EINEM Query (kein N+1), memoisiert pro Request.
  def region_map_regions
    @region_map_regions ||=
      Region.where(shortname: REGION_MAP_AREAS.values.uniq).index_by(&:shortname)
  end

  # Region-Record fuer eine Karten-Flaeche (nil, wenn die Region nicht existiert -> Flaeche
  # wird ausgegraut/ohne Link gerendert).
  def region_for_area(area_key)
    region_map_regions[REGION_MAP_AREAS[area_key.to_s]]
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

  # Link-/A11y-Attribute fuer eine Karten-Flaeche; nil, wenn keine Region vorhanden.
  def region_area_link_attrs(area_key)
    region = region_for_area(area_key)
    return nil unless region

    {
      href: region_path(region),
      aria_label: region.name,
      title: "#{region.shortname} — #{region.name}",
      shortname: region.shortname,
      logo: region_logo_src(region)
    }
  end
end
