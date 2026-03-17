#!/usr/bin/env ruby
# frozen_string_literal: true

# Documentation Link Fixer
# Automatically fixes common broken link patterns

require 'pathname'
require 'fileutils'

class DocsLinkFixer
  DOCS_ROOT = Pathname.new(__dir__).join('..', 'docs').expand_path
  
  # Colors
  GREEN = "\e[32m"
  YELLOW = "\e[33m"
  BLUE = "\e[34m"
  RESET = "\e[0m"
  
  # Common fix patterns
  FIX_PATTERNS = [
    # Remove language suffixes (.de.md, .en.md) - mkdocs-static-i18n handles this automatically
    {
      pattern: /\]\(([^\)]+)\.(de|en)\.md\)/,
      replacement: '](\\1.md)',
      description: 'Remove language suffix (i18n auto-resolves)'
    },
    # Remove 'docs/' prefix from paths
    {
      pattern: /\]\(docs\/(.*?)\)/,
      replacement: '](../\1)',
      description: 'Remove docs/ prefix'
    },
    # Fix table-reservation links (was renamed)
    {
      pattern: /\]\(\.\.\/managers\/table-reservation\.de\.md\)/,
      replacement: '](../managers/table-reservation.de.md)',
      description: 'Fix table-reservation path'
    },
    # Fix old INSTALLATION paths
    {
      pattern: /\]\(\.\.\/INSTALLATION\/QUICKSTART\.md\)/,
      replacement: '](../administrators/raspberry-pi-quickstart.de.md)',
      description: 'Fix INSTALLATION/QUICKSTART path'
    },
    # Fix test/ references to point to developers/testing
    {
      pattern: /\]\(test\/README\.md\)/,
      replacement: '](../developers/testing/testing-quickstart.md)',
      description: 'Fix test/README path'
    },
    {
      pattern: /\]\(docs\/developers\/testing-strategy\.de\.md\)/,
      replacement: '](../developers/testing-strategy.de.md)',
      description: 'Fix testing-strategy path'
    },
    # Fix TESTING.md references
    {
      pattern: /\]\(TESTING\.md\)/,
      replacement: '](../developers/testing/testing-quickstart.md)',
      description: 'Fix TESTING.md path'
    },
    # Fix doc/doc/Runbook (likely should be removed or fixed)
    {
      pattern: /\]\(doc\/doc\/Runbook\)/,
      replacement: '](../developers/developer-guide.de.md#operations)',
      description: 'Fix Runbook reference'
    },
    # Fix obsolete references
    {
      pattern: /\]\(obsolete\/(.*?)\)/,
      replacement: '](../developers/\1)',
      description: 'Move obsolete references to developers'
    }
  ]
  
  def initialize(dry_run: true)
    @dry_run = dry_run
    @fixes_applied = 0
    @files_modified = 0
  end
  
  def run
    puts "=" * 80
    puts "Documentation Link Fixer"
    puts "=" * 80
    puts "Mode: #{@dry_run ? 'DRY RUN (no changes)' : 'LIVE (will modify files)'}"
    puts ""
    
    markdown_files = find_markdown_files
    
    markdown_files.each do |file|
      fix_file(file)
    end
    
    print_summary
  end
  
  private
  
  def find_markdown_files
    # Exclude certain directories
    exclude_patterns = [
      '**/obsolete/**',
      '**/archive/**',
      '**/internal/**'
    ]
    
    all_files = Dir.glob(DOCS_ROOT.join('**', '*.md'))
    
    # Filter out excluded patterns
    all_files.reject do |file|
      exclude_patterns.any? { |pattern| File.fnmatch?(File.join(DOCS_ROOT, pattern), file) }
    end.map { |f| Pathname.new(f) }.sort
  end
  
  def fix_file(file)
    content = File.read(file)
    original_content = content.dup
    modified = false
    
    FIX_PATTERNS.each do |fix|
      if content.match?(fix[:pattern])
        content.gsub!(fix[:pattern], fix[:replacement])
        modified = true
        @fixes_applied += 1
        
        relative_path = file.relative_path_from(DOCS_ROOT)
        puts "#{YELLOW}#{fix[:description]}#{RESET} in #{BLUE}#{relative_path}#{RESET}"
      end
    end
    
    if modified
      @files_modified += 1
      
      unless @dry_run
        File.write(file, content)
        puts "  #{GREEN}✓ File updated#{RESET}"
      else
        puts "  #{YELLOW}→ Would update file (dry run)#{RESET}"
      end
    end
  end
  
  def print_summary
    puts ""
    puts "=" * 80
    puts "Summary"
    puts "=" * 80
    puts "Fixes applied: #{@fixes_applied}"
    puts "Files modified: #{@files_modified}"
    puts ""
    
    if @dry_run
      puts "#{YELLOW}This was a DRY RUN - no files were changed#{RESET}"
      puts "Run with --live to apply changes:"
      puts "  ruby bin/fix-docs-links.rb --live"
    else
      puts "#{GREEN}✓ All fixes have been applied!#{RESET}"
      puts ""
      puts "Next steps:"
      puts "1. Review changes: git diff docs/"
      puts "2. Run link checker: ruby bin/check-docs-links.rb"
      puts "3. Rebuild docs: bundle exec rake mkdocs:deploy"
    end
  end
end

# Parse command line arguments
dry_run = !ARGV.include?('--live')

DocsLinkFixer.new(dry_run: dry_run).run
