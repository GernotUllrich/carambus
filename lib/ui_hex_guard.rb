# frozen_string_literal: true

require "yaml"

# ─────────────────────────────────────────────────────────────────────────────
# UI-Guardrail — mechanische Wache gegen hartkodierte Farben in UI-Code.
#
# Kontext: Phase 7 „Hex-Migration" (UX-Redesign) ersetzt hartkodierte Farb-Hex
# durch Tailwind-Token-Utilities + Dark-Mode. Diese Wache stellt sicher, dass
# KEIN neuer hartkodierter Hex (#rgb/#rrggbb), kein <style>-Block und kein
# inline `style="…color…"` in den In-Scope-Dateien dazukommt.
#
# Ratchet-Prinzip (Baseline): config/ui_hex_baseline.yml „grandfathered" die
# Anzahl bekannter Verstoß-Zeilen je NOCH-NICHT-migrierter Datei. Die Wache
# schlägt fehl, sobald
#   (a) eine In-Scope-Datei MEHR Verstöße hat als ihre Baseline-Zahl (neuer Hex),
#   (b) eine nicht-baselinete, nicht-allowlistete Datei ÜBERHAUPT Verstöße hat.
# Wird eine Datei migriert, ihren Baseline-Eintrag entfernen → sie muss dann
# dauerhaft sauber bleiben. So ratscht die Schuld nur nach unten, nie nach oben.
#
# Bewusst KEINE Rails-Abhängigkeit: läuft schnell in overcommit (pre-commit)
# und CI ohne Rails-Boot. Siehe docs/ui-conventions.md für die Konventionen.
# ─────────────────────────────────────────────────────────────────────────────
module UiHexGuard
  ROOT = File.expand_path("..", __dir__) # lib/ → Projektwurzel

  ALLOWLIST_FILE = File.join(ROOT, "config", "ui_hex_allowlist.txt")
  BASELINE_FILE = File.join(ROOT, "config", "ui_hex_baseline.yml")

  # In-Scope: Admin-Views (primäres Migrationsziel der Phase 7) + die bereits
  # migrierten Core-CSS-Dateien (07-01), die hex-frei bleiben müssen. Bewusst
  # NICHT die ~370 out-of-scope-Hex-Vorkommen der übrigen Views/CSS — die
  # deckt die Allowlist bzw. der begrenzte Scope ab.
  SCAN_GLOBS = [
    "app/views/admin/**/*.erb",
    "app/assets/stylesheets/application.tailwind.css",
    "app/assets/stylesheets/components/carambus.css",
    "app/assets/stylesheets/components/buttons.css",
    "app/assets/stylesheets/components/forms.css",
    "app/assets/stylesheets/components/avatars.css",
    "app/assets/stylesheets/components/tabs.css"
  ].freeze

  # Farb-Hex #rgb oder #rrggbb. Lookbehind schließt HTML-Entities (&#8230;) und
  # Wort-Zeichen davor aus; `#{` (Ruby-Interpolation) matcht ohnehin nicht, weil
  # danach kein Hex-Zeichen folgt. Heuristik: reine Hex-Anker (href="#abc") sind
  # selten in Admin-Views und werden ggf. von der Baseline absorbiert.
  HEX_RE = /(?<![&\w])#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b/

  # <style>-Block (nur relevant in ERB-Views).
  STYLE_BLOCK_RE = /<style[\s>]/i

  # Inline `style="…"` das eine Farbe setzt: enthält Hex ODER color/background.
  # Reine Layout-Styles (style="margin-top:10px") werden bewusst NICHT geflaggt.
  INLINE_STYLE_RE = /style\s*=\s*(["'])(?:(?!\1).)*?(?:#\h{3,6}|\bcolor\b|\bbackground)/i

  Violation = Struct.new(:line_no, :type, :text, keyword_init: true)

  module_function

  # Öffentliche Einstiegspunkte ────────────────────────────────────────────────

  # Führt die Prüfung aus, gibt einen Report auf STDOUT/STDERR aus und liefert
  # true (sauber) / false (neue Verstöße). Wird von bin/ui-hex-guard + rake genutzt.
  def check
    counts = scan_counts
    baseline = load_baseline
    allowlist = load_allowlist

    new_violations = {} # path => [Violation, ...]  (nur die Dateien, die failen)
    ratchet_down = [] # Dateien, deren Count UNTER der Baseline liegt
    stale_baseline = [] # Baseline-Einträge ohne aktuelle Verstöße

    counts.each do |path, viols|
      next if allowlisted?(path, allowlist)

      current = viols.size
      accepted = baseline[path] || 0

      if current > accepted
        new_violations[path] = viols
      elsif current < accepted
        ratchet_down << [path, accepted, current]
      end
    end

    baseline.each_key do |path|
      next if allowlisted?(path, allowlist)
      stale_baseline << path if (counts[path]&.size || 0).zero?
    end

    report(new_violations, ratchet_down, stale_baseline, baseline)
    new_violations.empty?
  end

  # Erzeugt/aktualisiert config/ui_hex_baseline.yml aus dem Ist-Zustand.
  def generate_baseline!
    counts = scan_counts
    allowlist = load_allowlist

    data = {}
    counts.sort.each do |path, viols|
      next if allowlisted?(path, allowlist)
      data[path] = viols.size if viols.any?
    end

    File.write(BASELINE_FILE, baseline_yaml(data))
    puts "Baseline geschrieben: #{rel(BASELINE_FILE)} (#{data.size} Dateien, " \
         "#{data.values.sum} Verstoß-Zeilen)."
    data
  end

  # Interna ────────────────────────────────────────────────────────────────────

  # => { relative_path => [Violation, ...] } (nur Dateien mit ≥1 Verstoß)
  def scan_counts
    result = {}
    scan_files.each do |abs|
      rel_path = rel(abs)
      viols = scan_file(abs)
      result[rel_path] = viols if viols.any?
    end
    result
  end

  def scan_files
    SCAN_GLOBS.flat_map { |g| Dir.glob(File.join(ROOT, g)) }.uniq.sort
  end

  def scan_file(abs)
    erb = abs.end_with?(".erb")
    violations = []
    File.foreach(abs, encoding: "UTF-8").with_index(1) do |line, no|
      type = line_violation_type(line, erb)
      next unless type
      violations << Violation.new(line_no: no, type: type, text: line.strip)
    end
    violations
  rescue ArgumentError
    # z.B. ungültige Byte-Sequenz — Datei überspringen statt crashen.
    []
  end

  # Liefert das erste zutreffende Verstoß-Symbol für eine Zeile oder nil.
  def line_violation_type(line, erb)
    return :hex if line.match?(HEX_RE)
    if erb
      return :style_block if line.match?(STYLE_BLOCK_RE)
      return :inline_style if line.match?(INLINE_STYLE_RE)
    end
    nil
  end

  def load_baseline
    return {} unless File.exist?(BASELINE_FILE)
    (YAML.safe_load(File.read(BASELINE_FILE, encoding: "UTF-8")) || {}).select { |_k, v| v.is_a?(Integer) }
  end

  # Allowlist-Datei: eine Pattern/Zeile, `#`-Kommentare und Leerzeilen ignoriert.
  # Ein Pattern matcht, wenn es als Substring im relativen Pfad vorkommt.
  def load_allowlist
    return [] unless File.exist?(ALLOWLIST_FILE)
    File.readlines(ALLOWLIST_FILE, encoding: "UTF-8")
      .map { |l| l.sub(/#.*/, "").strip }
      .reject(&:empty?)
  end

  def allowlisted?(path, patterns)
    patterns.any? { |p| path.include?(p) }
  end

  def rel(abs)
    abs.sub("#{ROOT}/", "")
  end

  def baseline_yaml(data)
    header = <<~YAML
      # ─────────────────────────────────────────────────────────────────────────
      # UI-Hex-Ratchet-Baseline — auto-generiert von `rake ui:no_hardcoded_hex:baseline`.
      #
      # Jeder Eintrag = Anzahl „grandfahterter" Verstoß-Zeilen (Hex / <style> /
      # inline color-style) in einer NOCH-NICHT-migrierten In-Scope-Datei.
      # Die Wache (`rake ui:no_hardcoded_hex`) failt, wenn eine Datei MEHR
      # Verstöße bekommt als hier steht, oder eine hier fehlende Datei welche hat.
      #
      # Beim Migrieren einer Datei (Hex→Token, siehe docs/ui-conventions.md):
      #   → ihren Eintrag ENTFERNEN. Sie muss danach dauerhaft sauber (0) bleiben.
      # Nach absichtlichen Änderungen neu erzeugen: bin/rails ui:no_hardcoded_hex:baseline
      #
      # NICHT von Hand die Zahlen hochsetzen, um die Wache stumm zu schalten.
      # ─────────────────────────────────────────────────────────────────────────
    YAML
    return "#{header}--- {}\n" if data.empty?
    header + data.map { |k, v| "#{k.inspect}: #{v}\n" }.join
  end

  def report(new_violations, ratchet_down, stale_baseline, _baseline)
    if new_violations.any?
      warn "\n\e[31m✗ UI-Guardrail: neue hartkodierte Farben/Styles gefunden.\e[0m"
      warn "  Regeln & Migrationsweg: docs/ui-conventions.md\n"
      new_violations.each do |path, viols|
        warn "  #{path}"
        viols.first(20).each do |v|
          warn "    #{path}:#{v.line_no}  [#{label(v.type)}]  #{truncate(v.text)}"
        end
        warn "    … und #{viols.size - 20} weitere" if viols.size > 20
      end
      warn <<~HINT

        Behebung: betroffene Elemente auf Token-Utilities + dark:-Varianten ziehen
        (Mapping-Tabelle in docs/ui-conventions.md). NICHT die Baseline hochsetzen.
        Legitimer Ausnahmefall (Kiosk/Print/Vendor)? → config/ui_hex_allowlist.txt.
      HINT
    else
      puts "\e[32m✓ UI-Guardrail: keine neuen hartkodierten Farben/Styles.\e[0m"
    end

    if ratchet_down.any?
      puts "\n\e[33mℹ Ratchet: diese Dateien haben WENIGER Verstöße als die Baseline —\e[0m"
      puts "  bitte Baseline nachziehen (bin/rails ui:no_hardcoded_hex:baseline):"
      ratchet_down.each { |path, was, now| puts "    #{path}: #{was} → #{now}" }
    end

    if stale_baseline.any?
      puts "\n\e[33mℹ Baseline-Einträge ohne aktuelle Verstöße (können raus):\e[0m"
      stale_baseline.each { |path| puts "    #{path}" }
    end
  end

  def label(type)
    {hex: "hex", style_block: "<style>", inline_style: "inline-color"}[type] || type.to_s
  end

  def truncate(text, max = 90)
    (text.length > max) ? "#{text[0, max]}…" : text
  end
end
