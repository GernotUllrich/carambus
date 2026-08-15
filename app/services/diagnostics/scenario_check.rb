# frozen_string_literal: true

require "yaml"

module Diagnostics
  # Prueft STATISCH, ob die Szenario-Konfigurationen zusammen eine funktionierende Kette ergeben —
  # aus dem Entwickler-Checkout, ohne dass eine Instanz laufen muss.
  #
  # Der Mehrwert gegenueber `bin/deploy-scenario.sh` Step 1.5: der pruegt EIN Szenario gegen sich
  # selbst. Die teuren Fehler dieser Kette sind aber BEZIEHUNGSFEHLER zwischen Szenarien:
  #
  #   - Ein Location Server in einer CC-losen Region, dessen Region Server gar kein Szenario hat.
  #   - Ein Region Server, den die Authority nicht in `region_server_contexts` fuehrt: seine
  #     Meldelisten werden schlicht nie geholt — ohne Fehlermeldung, ohne leere Liste, ohne alles.
  #
  # STRIKT READ-ONLY, kein Netzwerk. Gibt niemals Passwoerter aus, nur ob sie da sind.
  class ScenarioCheck
    def initialize(data_path: nil)
      @data_path = data_path || default_data_path
      @checks = []
    end

    def call
      @checks = []
      if scenarios.empty?
        return [Check.new(name: "carambus_data", status: :fail,
          detail: "#{@data_path} nicht gefunden",
          hint: "CARAMBUS_DATA_PATH setzen oder aus dem Entwickler-Checkout starten")]
      end

      scenarios.each { |s| check_scenario(s) }
      check_chain
      @checks
    end

    # Alle Szenarien als Hash-Struktur (auch fuer die Rake-Ausgabe nuetzlich).
    def scenarios
      @scenarios ||= Dir.glob(File.join(@data_path, "scenarios", "*", "config.yml")).sort.filter_map do |file|
        yaml = YAML.load_file(file)
        sc = yaml["scenario"] || {}
        prod = (yaml["environments"] || {})["production"] || {}
        creds = sc["credentials"] || {}
        {
          name: File.basename(File.dirname(file)),
          file: file,
          declared_name: sc["name"],
          basename: sc["basename"],
          context: sc["context"].to_s,
          location_id: sc["location_id"],
          region_id: sc["region_id"],
          database_name: prod["database_name"].to_s,
          cap_role: prod["cap_role"].to_s,
          features: Array(creds["features"]).map(&:to_s),
          region_server_contexts: Array(creds["region_server_contexts"]).map(&:to_s)
        }
      rescue => e
        @checks << Check.new(name: File.basename(File.dirname(file)), status: :fail,
          detail: "config.yml nicht lesbar: #{e.message}")
        nil
      end
    end

    # :authority | :region_server | :location_server
    def role_of(s)
      return :authority if s[:cap_role] == "api"

      s[:location_id].present? ? :location_server : :region_server
    end

    # Eine Region gilt als CC-los, wenn das Szenario das `clubcloud`-Feature NICHT fuehrt.
    # Dieses Feature ist der einzige Ort, an dem "faehrt den Turnier-Lebenszyklus ueber die CC"
    # ueberhaupt deklariert ist.
    def cc_less?(s) = !s[:features].include?("clubcloud")

    private

    def add(name, status, detail, hint = nil)
      @checks << Check.new(name: name, status: status, detail: detail, hint: hint)
    end

    def default_data_path
      ENV["CARAMBUS_DATA_PATH"].presence ||
        (defined?(CarambusEnv) ? CarambusEnv.data_path : File.expand_path("~/DEV/carambus/carambus_data"))
    end

    def secrets
      @secrets ||= begin
        file = File.join(@data_path, "secrets.yml")
        File.exist?(file) ? (YAML.load_file(file) || {}) : {}
      end
    end

    def region_server_secrets
      @region_server_secrets ||= ((secrets["shared"] || {})["region_server"] || {})
        .reject { |k, _| k.to_s == "private_key" }
    end

    # ------------------------------------------------------------ je Szenario

    def check_scenario(s)
      label = s[:name]
      problems = []

      # Klon-Fallstrick: reset_server_db dropt database_name und loescht /var/www/<basename>.
      problems << "name=#{s[:declared_name]}" if s[:declared_name].present? && s[:declared_name] != s[:name]
      problems << "basename=#{s[:basename]}" if s[:basename].present? && s[:basename] != s[:name]
      problems << "database_name=#{s[:database_name]}" if s[:database_name].present? && s[:database_name] != "#{s[:name]}_production"

      if problems.any?
        add(label, :fail, "Namen passen nicht zum Szenario: #{problems.join("  ")}",
          "Sieht nach einer nicht angepassten Kopie aus — reset_server_db traefe eine fremde Instanz.")
      else
        add(label, :ok, "#{role_of(s)}#{", CC-los" if cc_less?(s)}#{", context=#{s[:context]}" if s[:context].present?}")
      end

      check_context_resolvable(s)
      check_region_server_contexts(s)
    end

    def check_context_resolvable(s)
      return if s[:context].blank?
      # Die Authority ist regionsuebergreifend; ihr `context: API` ist Absicht und meint keine Region.
      return if role_of(s) == :authority
      return unless defined?(Region) && Region.respond_to?(:find_by)

      region = Region.find_by("UPPER(shortname) = ?", s[:context].upcase)
      return if region

      add("#{s[:name]} · context", :warn, "#{s[:context].inspect} passt zu keiner Region",
        "Scope-Band und Formular-Vorbelegungen fallen dann still auf den Default zurueck.")
    end

    def check_region_server_contexts(s)
      # Die Authority wird hier NICHT pauschal geprueft: welche Kontexte sie braucht, ergibt sich
      # erst aus den vorhandenen CC-losen Region Servern — das entscheidet `check_chain` und meldet
      # dann konkret, welcher Kontext fehlt, statt nur "fehlt".
      if s[:region_server_contexts].empty?
        # Fehlt die Deklaration, ist das nur fuer einen CC-losen Location Server ein Blocker:
        # er hat sonst keinen Weg, seine Ergebnisse zu melden.
        return unless role_of(s) == :location_server && cc_less?(s)

        return add("#{s[:name]} · region_server_contexts", :fail,
          "fehlt (erwartet: [#{s[:context].upcase}])",
          "Ohne Deklaration werden die Zugangsdaten nicht generiert — der Aufruf scheitert erst im Betrieb.")
      end

      # Ist deklariert: dann muss es dafuer auch Zugangsdaten geben — unabhaengig von der Rolle.
      if role_of(s) == :location_server && !cc_less?(s)
        add("#{s[:name]} · region_server_contexts", :info,
          "deklariert (#{s[:region_server_contexts].join(", ")}), aber nicht noetig",
          "Region hat eine ClubCloud — der Rueckweg laeuft ueber sie.")
      end

      gaps = s[:region_server_contexts].reject do |ctx|
        region_server_secrets.key?(ctx.to_s) || region_server_secrets.key?(ctx.to_s.downcase)
      end

      if gaps.any?
        add("#{s[:name]} · region_server_contexts", :fail,
          "kein Eintrag in secrets.yml fuer: #{gaps.join(", ")}",
          "shared.region_server.<kontext>.{username,password} ergaenzen — sonst laesst der Generator " \
          "die Gruppe STILL weg.")
      else
        add("#{s[:name]} · region_server_contexts", :ok, s[:region_server_contexts].join(", "))
      end
    end

    # ------------------------------------------------------------ Beziehungen zwischen Szenarien

    def check_chain
      authority = scenarios.find { |s| role_of(s) == :authority }
      region_servers = scenarios.select { |s| role_of(s) == :region_server }
      cc_less_locations = scenarios.select { |s| role_of(s) == :location_server && cc_less?(s) }

      if authority.nil?
        return add("Kette", :warn, "kein Szenario mit cap_role: api gefunden")
      end

      known = authority[:region_server_contexts].map(&:upcase)

      # Jeder CC-lose Location Server braucht (a) einen Region Server und (b) dessen Kontext bei der
      # Authority — sonst holt sie seine Meldelisten nie, ohne dass irgendwo etwas auffaellt.
      cc_less_locations.each do |loc|
        ctx = loc[:context].to_s.upcase
        peer = region_servers.find { |rs| rs[:context].to_s.upcase == ctx }

        if peer.nil?
          add("Kette · #{loc[:name]}", :fail, "kein Region-Server-Szenario fuer context=#{ctx}",
            "Der Location Server haette niemanden, dem er Ergebnisse meldet.")
        elsif !known.include?(ctx)
          add("Kette · #{loc[:name]}", :fail,
            "#{peer[:name]} existiert, aber die Authority fuehrt #{ctx} nicht in region_server_contexts",
            "Die Meldelisten von #{ctx} werden NIE geholt — ohne Fehlermeldung. " \
            "In #{authority[:name]}/config.yml ergaenzen, dann generate/push_credentials.")
        else
          add("Kette · #{loc[:name]}", :ok, "#{loc[:name]} → #{peer[:name]} → #{authority[:name]} (#{ctx})")
        end
      end

      # CC-lose Region Server ohne Location Server: die Luecke faellt oben nicht auf, ist aber
      # dieselbe — die Authority holt ihre Meldelisten nie.
      region_servers.select { |rs| cc_less?(rs) }.each do |rs|
        ctx = rs[:context].to_s.upcase
        next if ctx.blank? || known.include?(ctx)
        next if cc_less_locations.any? { |loc| loc[:context].to_s.upcase == ctx } # oben schon gemeldet

        add("Kette · #{rs[:name]}", :fail,
          "CC-loser Region Server, aber die Authority fuehrt #{ctx} nicht in region_server_contexts",
          "Seine Meldelisten werden NIE geholt — ohne Fehlermeldung. " \
          "In #{authority[:name]}/config.yml ergaenzen, dann generate/push_credentials.")
      end

      # Region Server, die die Authority kennt, fuer die es aber kein Szenario gibt.
      orphans = known - region_servers.map { |rs| rs[:context].to_s.upcase }
      if orphans.any?
        add("Kette · Authority", :warn,
          "kennt Kontexte ohne Region-Server-Szenario: #{orphans.join(", ")}",
          "Kein Fehler (die Instanz kann ausserhalb dieses Checkouts gepflegt sein), aber pruefenswert.")
      end
    end
  end
end
