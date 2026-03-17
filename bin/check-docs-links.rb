#!/usr/bin/env ruby
# frozen_string_literal: true

# Documentation Link Checker
# Checks all markdown links in the docs folder and reports broken ones

require 'pathname'
require 'set'

class DocsLinkChecker
  DOCS_ROOT = Pathname.new(__dir__).join('..', 'docs').expand_path

  # Colors for output
  RED = "\e[31m"
  GREEN = "\e[32m"
  YELLOW = "\e[33m"
  BLUE = "\e[34m"
  RESET = "\e[0m"

  def initialize(exclude_patterns: [])
    @broken_links = []
    @total_links = 0
    @total_files = 0
    @external_links = 0
    @exclude_patterns = exclude_patterns
  end

  def run
    puts "=" * 80
    puts "Documentation Link Checker"
    puts "=" * 80
    puts "Docs root: #{DOCS_ROOT}"
    puts ""

    markdown_files = find_markdown_files

    puts "Found #{markdown_files.size} markdown files"
    puts ""

    markdown_files.each do |file|
      check_file(file)
    end

    print_summary
  end

  private

  def find_markdown_files
    all_files = Dir.glob(DOCS_ROOT.join('**', '*.md'))

    # Convert patterns to simple directory prefixes
    # e.g., '**/archive/**' becomes 'archive/'
    exclude_dirs = @exclude_patterns.map do |pattern|
      # Extract directory name from pattern like '**/archive/**'
      pattern.gsub(/\*\*\/|\*\*/, '').sub(/\/$/, '') + '/'
    end

    # Filter out excluded directories
    filtered_files = all_files.reject do |file|
      # Get path relative to DOCS_ROOT
      relative_path = Pathname.new(file).relative_path_from(DOCS_ROOT).to_s

      # Check if path starts with any excluded directory
      exclude_dirs.any? { |dir| relative_path.start_with?(dir) }
    end

    filtered_files.map { |f| Pathname.new(f) }.sort
  end

  def check_file(file)
    @total_files += 1
    relative_path = file.relative_path_from(DOCS_ROOT)

    content = File.read(file)
    links = extract_links(content)

    return if links.empty?

    links.each_with_index do |(link_text, link_url, line_num), index|
      @total_links += 1

      # Skip external links
      if external_link?(link_url)
        @external_links += 1
        next
      end

      # Skip anchors only (same page)
      next if link_url.start_with?('#')

      # Check if link target exists
      target_path = resolve_link_path(file, link_url)

      unless target_path && target_path.exist?
        @broken_links << {
          source_file: relative_path,
          line: line_num,
          link_text: link_text,
          link_url: link_url,
          resolved_path: target_path,
          suggestions: find_suggestions(link_url)
        }
      end
    end
  end

  def extract_links(content)
    links = []
    line_num = 0

    content.each_line do |line|
      line_num += 1

      # Match markdown links: [text](url)
      line.scan(/\[([^\]]+)\]\(([^)]+)\)/) do |text, url|
        # Remove anchor from URL for file checking
        url_without_anchor = url.split('#').first
        next if url_without_anchor.nil? || url_without_anchor.empty?

        links << [text, url_without_anchor, line_num]
      end
    end

    links
  end

  def external_link?(url)
    url.start_with?('http://', 'https://', 'mailto:', '//')
  end

  def resolve_link_path(source_file, link_url)
    # Get directory of source file
    source_dir = source_file.dirname

    # Remove leading './' if present
    link_url = link_url.sub(/^\.\//, '')

    # Resolve relative path
    if link_url.start_with?('/')
      # Absolute path from docs root
      target = DOCS_ROOT.join(link_url.sub(/^\//, ''))
    else
      # Relative path from source file
      target = source_dir.join(link_url)
    end

    # Normalize the path
    target = target.expand_path

    # Try with and without .md extension
    return target if target.exist?

    target_with_md = Pathname.new(target.to_s + '.md')
    return target_with_md if target_with_md.exist?

    # Try with locale variants
    %w[de en].each do |locale|
      target_with_locale = Pathname.new(target.to_s.sub(/\.md$/, '') + ".#{locale}.md")
      return target_with_locale if target_with_locale.exist?
    end

    nil
  end

  def find_suggestions(link_url)
    suggestions = []

    # Extract filename from link
    filename = File.basename(link_url, '.*')

    # Search for files with similar names in new structure
    search_dirs = %w[
      players
      managers
      administrators
      developers
      decision-makers
      reference
      international
    ]

    search_dirs.each do |dir|
      dir_path = DOCS_ROOT.join(dir)
      next unless dir_path.exist?

      Dir.glob(dir_path.join('**', "*#{filename}*.md")).each do |found|
        found_path = Pathname.new(found)
        relative = found_path.relative_path_from(DOCS_ROOT)
        suggestions << relative.to_s
      end
    end

    suggestions.uniq
  end

  def print_summary
    puts ""
    puts "=" * 80
    puts "Summary"
    puts "=" * 80
    puts "Files checked: #{@total_files}"
    puts "Total links: #{@total_links}"
    puts "External links: #{@external_links}"
    puts "Broken links: #{@broken_links.size}"
    puts ""

    if @broken_links.empty?
      puts "#{GREEN}✓ All internal links are valid!#{RESET}"
    else
      puts "#{RED}✗ Found #{@broken_links.size} broken links:#{RESET}"
      puts ""

      # Group by source file
      @broken_links.group_by { |link| link[:source_file] }.each do |file, links|
        puts "#{BLUE}#{file}#{RESET}"
        links.each do |link|
          puts "  #{RED}Line #{link[:line]}:#{RESET} [#{link[:link_text]}](#{link[:link_url]})"
          if link[:resolved_path]
            puts "    → Tried: #{link[:resolved_path].relative_path_from(DOCS_ROOT)}"
          end

          if link[:suggestions].any?
            puts "    #{YELLOW}Suggestions:#{RESET}"
            link[:suggestions].first(3).each do |suggestion|
              puts "      • #{suggestion}"
            end
          end
          puts ""
        end
      end

      # Print statistics by category
      puts ""
      puts "Broken links by directory:"
      @broken_links.group_by { |link| link[:source_file].to_s.split('/').first }.each do |dir, links|
        puts "  #{dir}: #{links.size}"
      end
    end

    exit(@broken_links.empty? ? 0 : 1)
  end
end

# Parse command line arguments
if ARGV.include?('--help') || ARGV.include?('-h')
  puts <<~HELP
    Documentation Link Checker
    
    Usage:
      ruby bin/check-docs-links.rb [OPTIONS]
    
    Options:
      --exclude-archives    Exclude archive, internal, and obsolete documents
      --help, -h           Show this help message
    
    Examples:
      ruby bin/check-docs-links.rb
        Check all documentation (including archives)
      
      ruby bin/check-docs-links.rb --exclude-archives
        Check only active documentation
      
      ruby bin/check-docs-links.rb > report.txt 2>&1
        Save report to file
  HELP
  exit 0
end

exclude_archives = ARGV.include?('--exclude-archives')

# Define exclude patterns
exclude_patterns = if exclude_archives
  [
    '**/obsolete/**',
    '**/archive/**',
    '**/internal/**',
    '**/studies/**',
    '**/changelog/**'
  ]
else
  []
end

# Run the checker
if exclude_archives
  puts "Mode: Excluding archives, internal, and obsolete documents"
  puts ""
end

DocsLinkChecker.new(exclude_patterns: exclude_patterns).run
