# frozen_string_literal: true

namespace :test do
  desc "Run tests with coverage report"
  task :coverage do
    ENV['COVERAGE'] = 'true'
    Rake::Task['test'].invoke
    puts "\n📊 Coverage report generated: coverage/index.html"
    puts "Open with: open coverage/index.html"
  end
  
  desc "Run only critical tests (concerns + scraping)"
  task :critical do
    puts "🔥 Running critical tests..."
    Rake::Task['test:concerns'].invoke
    Rake::Task['test:scraping'].invoke
  end
  
  desc "Run concern tests"
  task :concerns do
    puts "🔧 Running concern tests..."
    system("bin/rails test test/concerns/")
  end
  
  desc "Run scraping tests"
  task :scraping do
    puts "🕷️ Running scraping tests..."
    system("bin/rails test test/scraping/")
  end
  
  desc "Clean and re-record all VCR cassettes"
  task :rerecord_vcr do
    cassette_dir = Rails.root.join('test', 'snapshots', 'vcr')
    
    if File.directory?(cassette_dir)
      puts "🗑️  Deleting old VCR cassettes..."
      Dir.glob("#{cassette_dir}/*.yml").each do |file|
        File.delete(file)
        puts "   Deleted: #{File.basename(file)}"
      end
    end
    
    puts "\n▶️  Run tests to re-record cassettes:"
    puts "   bin/rails test test/scraping/"
  end
  
  desc "List all test files"
  task :list do
    puts "📝 Test files:\n\n"
    
    test_dirs = {
      'Concerns' => 'test/concerns',
      'Scraping' => 'test/scraping',
      'Models' => 'test/models',
      'Controllers' => 'test/controllers',
      'Integration' => 'test/integration',
      'System' => 'test/system'
    }
    
    test_dirs.each do |name, dir|
      path = Rails.root.join(dir)
      if File.directory?(path)
        files = Dir.glob("#{path}/**/*_test.rb")
        puts "#{name} (#{files.count}):"
        files.each do |file|
          puts "  - #{file.sub(Rails.root.to_s + '/', '')}"
        end
        puts
      end
    end
  end
  
  desc "Show test statistics"
  task :stats do
    puts "📊 Test Statistics\n\n"
    
    # Count test files
    test_files = Dir.glob(Rails.root.join('test', '**', '*_test.rb'))
    puts "Test Files: #{test_files.count}"
    
    # Count test methods
    test_count = 0
    test_files.each do |file|
      content = File.read(file)
      test_count += content.scan(/^\s*test\s+["']/).count
      test_count += content.scan(/^\s*def\s+test_/).count
    end
    puts "Test Methods: #{test_count}"
    
    # Count fixtures
    fixture_files = Dir.glob(Rails.root.join('test', 'fixtures', '**', '*.yml'))
    puts "Fixture Files: #{fixture_files.count}"
    
    # Count VCR cassettes
    cassette_files = Dir.glob(Rails.root.join('test', 'snapshots', 'vcr', '*.yml'))
    puts "VCR Cassettes: #{cassette_files.count}"
    
    # Count snapshots
    snapshot_files = Dir.glob(Rails.root.join('test', 'snapshots', 'data', '*.yml'))
    puts "Data Snapshots: #{snapshot_files.count}"
    
    puts "\n📁 Test Directory Breakdown:"
    test_dirs = ['concerns', 'scraping', 'models', 'controllers', 'integration', 'system']
    test_dirs.each do |dir|
      files = Dir.glob(Rails.root.join('test', dir, '**', '*_test.rb'))
      next if files.empty?
      
      test_methods = 0
      files.each do |file|
        content = File.read(file)
        test_methods += content.scan(/^\s*test\s+["']/).count
        test_methods += content.scan(/^\s*def\s+test_/).count
      end
      
      puts "  #{dir.ljust(15)} #{files.count.to_s.rjust(3)} files, #{test_methods.to_s.rjust(4)} tests"
    end
  end
  
  desc "Validate test setup"
  task :validate => :environment do
    puts "🔍 Validating test setup...\n\n"
    
    issues = []
    
    # Check test database
    begin
      ActiveRecord::Base.connection
      puts "✅ Test database connection OK"
    rescue => e
      issues << "❌ Test database connection failed: #{e.message}"
    end
    
    # Check fixtures
    fixture_dir = Rails.root.join('test', 'fixtures')
    if File.directory?(fixture_dir)
      puts "✅ Fixtures directory exists"
    else
      issues << "❌ Fixtures directory not found"
    end
    
    # Check test helpers
    support_dir = Rails.root.join('test', 'support')
    if File.directory?(support_dir)
      puts "✅ Test support directory exists"
      
      helpers = ['vcr_setup.rb', 'scraping_helpers.rb', 'snapshot_helpers.rb']
      helpers.each do |helper|
        if File.exist?(support_dir.join(helper))
          puts "  ✅ #{helper}"
        else
          issues << "❌ Missing helper: #{helper}"
        end
      end
    else
      issues << "❌ Test support directory not found"
    end
    
    # Check VCR setup
    vcr_dir = Rails.root.join('test', 'snapshots', 'vcr')
    if File.directory?(vcr_dir)
      puts "✅ VCR directory exists"
    else
      issues << "⚠️  VCR directory not found (will be created on first use)"
    end
    
    # Check gems
    begin
      require 'vcr'
      puts "✅ VCR gem loaded"
    rescue LoadError
      issues << "❌ VCR gem not installed (run: bundle install)"
    end
    
    begin
      require 'webmock'
      puts "✅ WebMock gem loaded"
    rescue LoadError
      issues << "❌ WebMock gem not installed"
    end
    
    if issues.empty?
      puts "\n✅ All checks passed! Test setup is ready."
    else
      puts "\n⚠️  Issues found:"
      issues.each { |issue| puts issue }
      exit 1
    end
  end
end
