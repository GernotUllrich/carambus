# frozen_string_literal: true

namespace :deploy do
  desc "Deploy NGINX configuration"
  task :nginx_config do
    on roles(:app) do
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
      puma_service_file = "#{shared_path}/config/puma.service"
      puma_target = "/etc/systemd/system/puma-#{fetch(:basename)}.service"
      
      # Copy Puma service config
      execute :sudo, :cp, puma_service_file, puma_target
      
      # Reload systemd daemon
      execute :sudo, :systemctl, :daemon-reload
      
      # Enable the service
      execute :sudo, :systemctl, :enable, "puma-#{fetch(:basename)}.service"
      
      puts "✅ Puma service configuration deployed and enabled"
    end
  end

  desc "Deploy all templates and configurations"
  task :deploy_templates do
    invoke "deploy:nginx_config"
    invoke "deploy:puma_service_config"
  end
end

# Hook into deployment process
after "deploy:published", "deploy:deploy_templates"
