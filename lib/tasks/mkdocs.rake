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
    puts "Available at: /docs/"
  end

  desc "Validate MkDocs documentation — strict mode, exits non-zero on any warning (CI-ready)"
  task check: :environment do
    unless system("which mkdocs > /dev/null 2>&1")
      puts "Error: mkdocs is not installed. Please install it first:"
      puts "  pip install mkdocs-material mkdocs-static-i18n pymdown-extensions"
      exit 1
    end

    # Build to temp dir to avoid polluting project with site/ artifacts
    tmp_dir = "/tmp/mkdocs-check-#{Process.pid}"
    puts "Running mkdocs build --strict (output to #{tmp_dir})..."
    success = system("mkdocs build --strict --site-dir #{tmp_dir} 2>&1")

    # Cleanup temp build artifacts
    FileUtils.rm_rf(tmp_dir) if Dir.exist?(tmp_dir)

    unless success
      puts "\nError: mkdocs build failed with warnings or errors."
      puts "Fix all warnings before proceeding."
      exit 1
    end

    puts "\nDocumentation validation passed — zero warnings."
  end
end