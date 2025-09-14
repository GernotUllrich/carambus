# frozen_string_literal: true

namespace :deploy do
  desc "Deploy NGINX configuration"
  task :nginx_config do
    on roles(:app) do
      # Check if nginx.conf already exists in shared directory (from scenario preparation)
      nginx_conf_shared = "#{shared_path}/config/nginx.conf"
      if test("[ -f #{nginx_conf_shared} ]")
        puts "✅ nginx.conf already exists in shared directory (from scenario preparation)"
      else
        # Upload local nginx.conf to server (fallback for manual deployments)
        upload! "config/nginx.conf", nginx_conf_shared
      end
      
      nginx_config_file = "#{shared_path}/config/nginx.conf"
      nginx_target = "/etc/nginx/sites-available/#{fetch(:basename)}"
      
      # Copy NGINX config to sites-available
      execute :sudo, :cp, nginx_config_file, nginx_target
      
      # Create symlink to sites-enabled if it doesn't exist
      execute :sudo, :ln, "-sf", nginx_target, "/etc/nginx/sites-enabled/#{fetch(:basename)}"
      
      # Test NGINX configuration
      execute :sudo, :nginx, "-t"
      
      # Reload NGINX
      execute :sudo, :systemctl, :reload, :nginx
      
      puts "✅ NGINX configuration deployed and activated"
    end
  end

  desc "Deploy Puma service configuration"
  task :puma_service_config do
    on roles(:app) do
      # Check if puma.service already exists in shared directory (from scenario preparation)
      puma_service_shared = "#{shared_path}/config/puma.service"
      if test("[ -f #{puma_service_shared} ]")
        puts "✅ puma.service already exists in shared directory (from scenario preparation)"
      else
        # Upload local puma.service to server (fallback for manual deployments)
        upload! "config/puma.service", puma_service_shared
      end
      
      puma_service_file = "#{shared_path}/config/puma.service"
      puma_target = "/etc/systemd/system/puma-#{fetch(:basename)}.service"
      
      # Copy Puma service config
      execute :sudo, :cp, puma_service_file, puma_target
      
      # Reload systemd daemon
      execute :sudo, :systemctl, "daemon-reload"
      
      # Enable the service
      execute :sudo, :systemctl, :enable, "puma-#{fetch(:basename)}.service"
      
      puts "✅ Puma service configuration deployed and enabled"
    end
  end

  desc "Deploy Puma.rb configuration"
  task :puma_rb_config do
    on roles(:app) do
      # Check if puma.rb already exists in shared directory (from scenario preparation)
      puma_rb_shared = "#{shared_path}/config/puma.rb"
      if test("[ -f #{puma_rb_shared} ]")
        puts "✅ puma.rb already exists in shared directory (from scenario preparation)"
      else
        # Upload local puma.rb to server (fallback for manual deployments)
        upload! "config/puma.rb", puma_rb_shared
      end
      
      puma_rb_file = "#{shared_path}/config/puma.rb"
      puma_rb_target = "#{shared_path}/puma.rb"
      
      # Copy Puma.rb config
      execute :cp, puma_rb_file, puma_rb_target
      
      # Ensure socket directory exists
      execute :mkdir, "-p", "#{shared_path}/sockets"
      execute :mkdir, "-p", "#{shared_path}/pids"
      execute :mkdir, "-p", "#{shared_path}/log"
      
      # Set proper permissions
      execute :chown, "-R", "www-data:www-data", "#{shared_path}/sockets"
      execute :chown, "-R", "www-data:www-data", "#{shared_path}/pids"
      execute :chown, "-R", "www-data:www-data", "#{shared_path}/log"
      
      puts "✅ Puma.rb configuration deployed"
    end
  end

  desc "Setup SSL certificate with Let's Encrypt"
  task :ssl_setup do
    on roles(:app) do
      domain = fetch(:domain)
      
      # Check if certificate already exists
      if test("sudo certbot certificates | grep -q '#{domain}'")
        puts "✅ SSL certificate already exists for #{domain}"
      else
        puts "🔒 Setting up SSL certificate for #{domain}..."
        
        # Create SSL certificate
        execute :sudo, :certbot, "--nginx", "-d", domain, "--non-interactive", "--agree-tos", "--email", "gernot.ullrich@gmx.de"
        
        puts "✅ SSL certificate created successfully"
      end
    end
  end

  desc "Deploy all templates and configurations"
  task :deploy_templates do
    invoke "deploy:nginx_config"
    invoke "deploy:puma_service_config"
    invoke "deploy:puma_rb_config"
    
    # Setup SSL if enabled
    if fetch(:ssl_enabled)
      invoke "deploy:ssl_setup"
    end
  end
end

# Hook into deployment process
after "deploy:published", "deploy:deploy_templates"
