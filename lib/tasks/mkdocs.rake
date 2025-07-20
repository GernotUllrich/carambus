# frozen_string_literal: true

namespace :mkdocs do
  desc "Build MkDocs documentation and copy to public directory"
  task build: :environment do
    puts "Building MkDocs documentation..."
    
    # Check if mkdocs is available
    unless system("which mkdocs > /dev/null 2>&1")
      puts "Error: mkdocs is not installed. Please install it first:"
      puts "  pip install mkdocs-material mkdocs-static-i18n pymdown-extensions"
      exit 1
    end
    
    # Build documentation
    unless system("mkdocs build")
      puts "Error: Failed to build MkDocs documentation"
      exit 1
    end
    
    # Create public/docs directory
    public_docs_dir = Rails.root.join("public", "docs")
    FileUtils.mkdir_p(public_docs_dir)
    
    # Copy built documentation to public/docs
    site_dir = Rails.root.join("site")
    if Dir.exist?(site_dir)
      puts "Copying documentation to public/docs..."
      FileUtils.cp_r(Dir.glob("#{site_dir}/*"), public_docs_dir)
      puts "Documentation copied successfully to public/docs/"
    else
      puts "Error: site directory not found. MkDocs build may have failed."
      exit 1
    end
    
    puts "MkDocs documentation is now available at /docs/"
  end
  
  desc "Clean MkDocs build artifacts"
  task clean: :environment do
    puts "Cleaning MkDocs build artifacts..."
    
    # Remove site directory
    site_dir = Rails.root.join("site")
    if Dir.exist?(site_dir)
      FileUtils.rm_rf(site_dir)
      puts "Removed site directory"
    end
    
    # Remove public/docs directory
    public_docs_dir = Rails.root.join("public", "docs")
    if Dir.exist?(public_docs_dir)
      FileUtils.rm_rf(public_docs_dir)
      puts "Removed public/docs directory"
    end
    
    puts "Cleanup completed"
  end
  
  desc "Serve MkDocs documentation locally for development"
  task serve: :environment do
    puts "Starting MkDocs development server..."
    puts "Documentation will be available at http://127.0.0.1:8000/carambus-docs/"
    puts "Press Ctrl+C to stop the server"
    
    system("mkdocs serve")
  end
  
  desc "Build and deploy MkDocs documentation"
  task deploy: [:clean, :build] do
    puts "MkDocs documentation deployed successfully!"
    puts "Available at: #{Rails.application.routes.url_helpers.root_url}docs/"
  end
end 