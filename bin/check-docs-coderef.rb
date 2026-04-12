#!/usr/bin/env ruby
# frozen_string_literal: true

# Documentation Code Reference Checker
# Detects stale class/module references in docs that no longer exist in app/ or lib/
#
# Strategy:
#   1. Build stale identifier set from git diff (deleted/renamed files v1.0..v5.0)
#   2. Build live identifier set from current app/ and lib/ files
#   3. Scan docs full-text for any stale identifier occurrences
#
# Why full-text scanning (not code-fence-only):
#   The stale identifier set is tiny and project-specific (e.g. UmbScraperV2,
#   TournamentMonitorSupport). These exact strings cannot appear by coincidence in
#   normal prose — they are unique project class names derived from git history.
#   Full-text scanning ensures we catch references in headings and prose, not only
#   in code fences.

require "pathname"
require "set"
require "json"

class DocsCoderefChecker
  DOCS_ROOT = Pathname.new(__dir__).join("..", "docs").expand_path
  APP_ROOT = Pathname.new(__dir__).join("..").expand_path

  # Colors for output
  RED = "\e[31m"
  GREEN = "\e[32m"
  YELLOW = "\e[33m"
  BLUE = "\e[34m"
  RESET = "\e[0m"

  ARCHIVE_DIRS = %w[/archive/ /obsolete/ /internal/].freeze

  def initialize(exclude_archives: false, json_output: false)
    @exclude_archives = exclude_archives
    @json_output = json_output
    @findings = []
  end

  def run
    unless @json_output
      puts "=" * 80
      puts "Documentation Code Reference Checker"
      puts "=" * 80
      puts "App root: #{APP_ROOT}"
      puts "Docs root: #{DOCS_ROOT}"
      puts ""
    end

    stale = build_stale_identifiers
    live = build_live_identifiers
    stale_only = stale - live

    unless @json_output
      puts "Stale identifiers (deleted/renamed in v1.0..v5.0, not in live codebase):"
      stale_only.sort.each { |id| puts "  #{YELLOW}#{id}#{RESET}" }
      puts ""
    end

    scan_docs(stale_only)

    if @json_output
      puts JSON.generate(@findings)
    else
      print_findings
      print_summary(stale_only.size)
    end
  end

  private

  def build_stale_identifiers
    identifiers = Set.new

    # Deleted files between v1.0 and v5.0
    deleted_output = `git diff --diff-filter=D --name-only v1.0 v5.0 -- app/ lib/ 2>/dev/null`
    deleted_output.each_line do |line|
      path = line.strip
      next if path.empty?

      basename = File.basename(path, ".rb")
      identifiers.add(basename)                      # snake_case form
      identifiers.add(to_camel_case(basename))       # CamelCase form
    end

    # Renamed files between v1.0 and v5.0
    renamed_output = `git diff --diff-filter=R --name-status v1.0 v5.0 -- app/ lib/ 2>/dev/null`
    renamed_output.each_line do |line|
      parts = line.strip.split(/\s+/)
      next if parts.size < 3

      # parts[0] is "R100" etc, parts[1] is old path, parts[2] is new path
      old_path = parts[1]
      basename = File.basename(old_path, ".rb")
      identifiers.add(basename)
      identifiers.add(to_camel_case(basename))
    end

    identifiers
  end

  def to_camel_case(snake_str)
    # Split on underscore, capitalize each segment
    # Handle trailing digits: "v2" -> "V2", "umb_scraper_v2" -> "UmbScraperV2"
    snake_str.split("_").map { |segment| segment.capitalize }.join
  end

  def build_live_identifiers
    identifiers = Set.new

    Dir.glob(APP_ROOT.join("{app,lib}/**/*.rb").to_s).each do |path|
      basename = File.basename(path, ".rb")
      identifiers.add(basename)
      identifiers.add(to_camel_case(basename))
    end

    identifiers
  end

  def scan_docs(stale_identifiers)
    return if stale_identifiers.empty?

    doc_files = Dir.glob(DOCS_ROOT.join("**", "*.md").to_s)

    if @exclude_archives
      doc_files = doc_files.reject { |f| archive_path?(f) }
    end

    pattern = Regexp.union(stale_identifiers.to_a)

    doc_files.sort.each do |file|
      relative = Pathname.new(file).relative_path_from(APP_ROOT).to_s
      content = File.read(file, encoding: "utf-8")

      content.each_line.with_index(1) do |line, line_num|
        matches = line.scan(pattern)
        matches.uniq.each do |identifier|
          @findings << {
            file: relative,
            line: line_num,
            identifier: identifier,
            context: line.strip
          }
        end
      end
    end
  end

  def archive_path?(path)
    ARCHIVE_DIRS.any? { |dir| path.include?(dir) }
  end

  def print_findings
    @findings.each do |finding|
      puts "#{RED}STALE_REF: #{finding[:file]}:#{finding[:line]} — #{finding[:identifier]}#{RESET}"
      puts "  #{YELLOW}#{finding[:context]}#{RESET}"
    end
  end

  def print_summary(stale_count)
    doc_files = Dir.glob(DOCS_ROOT.join("**", "*.md").to_s)
    if @exclude_archives
      doc_files = doc_files.reject { |f| archive_path?(f) }
    end

    puts ""
    puts "=" * 80
    puts "Summary"
    puts "=" * 80
    puts "Files scanned:              #{doc_files.size}"
    puts "Stale identifiers checked:  #{stale_count}"
    puts "Findings:                   #{@findings.size}"
    puts ""

    if @findings.empty?
      puts "#{GREEN}No stale code references found.#{RESET}"
    else
      puts "#{RED}Found #{@findings.size} stale reference(s) in documentation.#{RESET}"
    end

    exit(@findings.empty? ? 0 : 1)
  end
end

# Parse command line arguments
if ARGV.include?("--help") || ARGV.include?("-h")
  puts <<~HELP
    Documentation Code Reference Checker

    Usage:
      ruby bin/check-docs-coderef.rb [OPTIONS]

    Options:
      --exclude-archives   Exclude archive/, obsolete/, internal/ paths from scan
      --json               Output findings as JSON array instead of text
      --help, -h           Show this help message

    Output (text mode):
      STALE_REF: docs/path/file.md:42 — UmbScraperV2

    Exit codes:
      0 — No stale references found
      1 — One or more stale references found

    How it works:
      1. Runs git diff --diff-filter=D/R to find files deleted or renamed between v1.0 and v5.0
      2. Builds a set of stale class identifiers (both CamelCase and snake_case)
      3. Scans all docs full-text for any of those identifiers
      4. Reports each match with file, line number, and context

    Examples:
      ruby bin/check-docs-coderef.rb
        Check all docs against stale identifiers

      ruby bin/check-docs-coderef.rb --exclude-archives
        Check active docs only

      ruby bin/check-docs-coderef.rb --json
        Output findings as machine-readable JSON
  HELP
  exit 0
end

exclude_archives = ARGV.include?("--exclude-archives")
json_output = ARGV.include?("--json")

DocsCoderefChecker.new(exclude_archives: exclude_archives, json_output: json_output).run
