#!/usr/bin/env ruby
# frozen_string_literal: true

# Documentation Translation Coverage Checker
# Reports missing .en.md and .de.md counterparts across the docs folder

require "pathname"
require "set"
require "yaml"

class DocsTranslationChecker
  DOCS_ROOT = Pathname.new(__dir__).join("..", "docs").expand_path
  MKDOCS_YML = Pathname.new(__dir__).join("..", "mkdocs.yml").expand_path

  # Colors for output
  RED = "\e[31m"
  GREEN = "\e[32m"
  YELLOW = "\e[33m"
  BLUE = "\e[34m"
  RESET = "\e[0m"

  ARCHIVE_DIRS = %w[/archive/ /obsolete/ /internal/ /studies/ /changelog/].freeze

  def initialize(nav_only: false, exclude_archives: false)
    @nav_only = nav_only
    @exclude_archives = exclude_archives
    @missing_en = []
    @missing_de = []
  end

  def run
    puts "=" * 80
    puts "Documentation Translation Coverage Checker"
    puts "=" * 80
    puts "Docs root: #{DOCS_ROOT}"
    puts "Mode: #{mode_description}"
    puts ""

    de_bases, en_bases = collect_base_sets

    if @nav_only
      nav_bases = collect_nav_bases
      check_nav_pairs(nav_bases)
      print_findings
      print_summary(nav_bases.size, nav_bases.size)
    else
      @missing_en = (de_bases - en_bases).sort
      @missing_de = (en_bases - de_bases).sort
      print_findings
      print_summary(de_bases.size, en_bases.size)
    end
  end

  private

  def mode_description
    parts = []
    parts << "nav-only" if @nav_only
    parts << "excluding archives" if @exclude_archives
    parts.empty? ? "full scan" : parts.join(", ")
  end

  def collect_base_sets
    de_files = Dir.glob(DOCS_ROOT.join("**", "*.de.md").to_s)
    en_files = Dir.glob(DOCS_ROOT.join("**", "*.en.md").to_s)

    if @exclude_archives
      de_files = de_files.reject { |f| archive_path?(f) }
      en_files = en_files.reject { |f| archive_path?(f) }
    end

    de_bases = Set.new(de_files.map { |f| strip_locale_extension(f) })
    en_bases = Set.new(en_files.map { |f| strip_locale_extension(f) })

    [de_bases, en_bases]
  end

  def strip_locale_extension(path)
    # Strip .md then .de or .en to get base path
    # e.g., /docs/about.de.md -> /docs/about
    Pathname.new(path).sub_ext("").sub_ext("").to_s
  end

  def archive_path?(path)
    ARCHIVE_DIRS.any? { |dir| path.include?(dir) }
  end

  def collect_nav_bases
    config = YAML.load_file(MKDOCS_YML.to_s)
    nav = config["nav"] || []
    extract_nav_paths(nav)
  end

  def extract_nav_paths(nav_node)
    bases = Set.new

    case nav_node
    when Array
      nav_node.each { |item| bases.merge(extract_nav_paths(item)) }
    when Hash
      nav_node.each_value { |v| bases.merge(extract_nav_paths(v)) }
    when String
      # nav_node is a relative path like "about.md" or "developers/index.md"
      # Strip .md extension to get base
      base = DOCS_ROOT.join(nav_node.sub(/\.md$/, "")).to_s
      bases.add(base)
    end

    bases
  end

  def check_nav_pairs(nav_bases)
    nav_bases.each do |base|
      en_path = base + ".en.md"
      de_path = base + ".de.md"

      if @exclude_archives
        next if archive_path?(base)
      end

      @missing_en << base unless File.exist?(en_path)
      @missing_de << base unless File.exist?(de_path)
    end

    @missing_en.sort!
    @missing_de.sort!
  end

  def print_findings
    @missing_en.each do |base|
      relative = Pathname.new(base + ".en.md").relative_path_from(DOCS_ROOT.join("..")).to_s
      puts "#{RED}MISSING_EN: #{relative}#{RESET}"
    end

    @missing_de.each do |base|
      relative = Pathname.new(base + ".de.md").relative_path_from(DOCS_ROOT.join("..")).to_s
      puts "#{YELLOW}MISSING_DE: #{relative}#{RESET}"
    end
  end

  def print_summary(de_count, en_count)
    puts ""
    puts "=" * 80
    puts "Summary"
    puts "=" * 80
    puts "Total .de.md files:  #{de_count}"
    puts "Total .en.md files:  #{en_count}"
    puts "Missing .en.md:      #{@missing_en.size}"
    puts "Missing .de.md:      #{@missing_de.size}"
    puts ""

    total_gaps = @missing_en.size + @missing_de.size
    if total_gaps.zero?
      puts "#{GREEN}All translation pairs are complete.#{RESET}"
    else
      puts "#{RED}Found #{total_gaps} translation gap(s).#{RESET}"
    end

    exit(total_gaps.zero? ? 0 : 1)
  end
end

# Parse command line arguments
if ARGV.include?("--help") || ARGV.include?("-h")
  puts <<~HELP
    Documentation Translation Coverage Checker

    Usage:
      ruby bin/check-docs-translations.rb [OPTIONS]

    Options:
      --nav-only           Only check files referenced in mkdocs.yml nav section
      --exclude-archives   Exclude archive/, obsolete/, internal/, studies/, changelog/ paths
      --help, -h           Show this help message

    Output:
      MISSING_EN: docs/path/to/file.en.md   — .de.md exists but .en.md is missing
      MISSING_DE: docs/path/to/file.de.md   — .en.md exists but .de.md is missing

    Exit codes:
      0 — No translation gaps found
      1 — One or more translation gaps found

    Examples:
      ruby bin/check-docs-translations.rb
        Check all docs for translation pairs

      ruby bin/check-docs-translations.rb --nav-only
        Check only nav-referenced files

      ruby bin/check-docs-translations.rb --exclude-archives
        Check active docs only (skip archive/obsolete/internal)
  HELP
  exit 0
end

nav_only = ARGV.include?("--nav-only")
exclude_archives = ARGV.include?("--exclude-archives")

DocsTranslationChecker.new(nav_only: nav_only, exclude_archives: exclude_archives).run
