# Neue Task für externe Daten-Verwaltung
namespace :data do
  desc "Set data directory for current environment"
  task :set_directory, [:environment] => :environment do |task, args|
    load File.expand_path('../carambus_env.rb', __dir__) unless defined?(CarambusEnv)
    env = args.environment || 'api_server'
    data_dir = "#{CarambusEnv.data_path}/#{env}"
    
    # Erstelle Directory-Struktur
    dirs = [
      "#{data_dir}/config",
      "#{data_dir}/credentials", 
      "#{data_dir}/environments",
      "#{data_dir}/database_dumps",
      "#{data_dir}/deploy"
    ]
    
    dirs.each do |dir|
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
    end
    
    # Setze Environment-Variable
    ENV['CARAMBUS_DATA_DIR'] = data_dir
    puts "✓ Data directory set to: #{data_dir}"
  end

  desc "Generate templates to external data directory"
  task :generate_templates => :environment do
    load File.expand_path('../carambus_env.rb', __dir__) unless defined?(CarambusEnv)
    data_dir = ENV['CARAMBUS_DATA_DIR'] || "#{CarambusEnv.data_path}/api_server"
    
    puts "🔧 Generating templates to external data directory..."
    puts "📁 Target: #{data_dir}"
    
    # Generiere Templates wie gewohnt
    Rake::Task['mode:generate_templates'].invoke
    
    # Kopiere generierte Dateien ins externe Directory
    config_files = [
      'config/database.yml',
      'config/carambus.yml', 
      'config/nginx.conf',
      'config/puma.service',
      'config/puma.rb',
      'config/scoreboard_url'
    ]
    
    config_files.each do |file|
      if File.exist?(file)
        target = "#{data_dir}/#{file}"
        FileUtils.mkdir_p(File.dirname(target))
        FileUtils.cp(file, target)
        puts "✓ Copied #{file} to #{target}"
      end
    end
    
    # Kopiere Credentials und Environments
    if File.exist?('config/credentials')
      FileUtils.cp_r('config/credentials', "#{data_dir}/")
      puts "✓ Copied credentials to #{data_dir}/credentials"
    end
    
    if File.exist?('config/environments')
      FileUtils.cp_r('config/environments', "#{data_dir}/")
      puts "✓ Copied environments to #{data_dir}/environments"
    end
    
    if File.exist?('config/deploy')
      FileUtils.cp_r('config/deploy', "#{data_dir}/")
      puts "✓ Copied deploy configs to #{data_dir}/deploy"
    end
    
    puts "✅ Templates generated and copied to external data directory"
  end

  desc "Deploy from external data directory"
  task :deploy => :environment do
    load File.expand_path('../carambus_env.rb', __dir__) unless defined?(CarambusEnv)
    data_dir = ENV['CARAMBUS_DATA_DIR'] || "#{CarambusEnv.data_path}/api_server"
    
    puts "📤 Deploying from external data directory..."
    puts "📁 Source: #{data_dir}"
    
    # Kopiere Dateien zurück ins Repository
    config_files = [
      'database.yml',
      'carambus.yml', 
      'nginx.conf',
      'puma.service',
      'puma.rb',
      'scoreboard_url'
    ]
    
    config_files.each do |file|
      source = "#{data_dir}/config/#{file}"
      target = "config/#{file}"
      
      if File.exist?(source)
        FileUtils.cp(source, target)
        puts "✓ Copied #{source} to #{target}"
      else
        puts "⚠️  #{source} not found"
      end
    end
    
    # Kopiere Credentials und Environments zurück
    if Dir.exist?("#{data_dir}/credentials")
      FileUtils.cp_r("#{data_dir}/credentials", "config/")
      puts "✓ Copied credentials back to config/"
    end
    
    if Dir.exist?("#{data_dir}/environments")
      FileUtils.cp_r("#{data_dir}/environments", "config/")
      puts "✓ Copied environments back to config/"
    end
    
    if Dir.exist?("#{data_dir}/deploy")
      FileUtils.cp_r("#{data_dir}/deploy", "config/")
      puts "✓ Copied deploy configs back to config/"
    end
    
    puts "✅ Files copied from external data directory"
  end
end
