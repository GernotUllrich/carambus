# frozen_string_literal: true

# Controller für MkDocs-Dokumentation
class DocsController < ApplicationController
  def show
    # Pfad aus der URL extrahieren
    path = params[:path]
    
    # Sicherheitscheck: Verhindere Directory Traversal
    if path.include?('..') || path.start_with?('/')
      render_404
      return
    end
    
    # HTML-Datei aus public/docs laden
    docs_path = Rails.root.join('public', 'docs', path)
    
    # Wenn es ein Verzeichnis ist, index.html verwenden
    if File.directory?(docs_path)
      docs_path = docs_path.join('index.html')
    end
    
    # Wenn die Datei nicht existiert, .html Extension hinzufügen
    unless File.exist?(docs_path)
      docs_path = Rails.root.join('public', 'docs', "#{path}.html")
    end
    
    # Wenn die Datei immer noch nicht existiert, 404
    unless File.exist?(docs_path)
      render_404
      return
    end
    
    # HTML-Datei laden und rendern
    content = File.read(docs_path)
    
    # Content-Type auf HTML setzen
    response.headers['Content-Type'] = 'text/html; charset=utf-8'
    
    # HTML-Inhalt rendern
    render html: content.html_safe, layout: false
  end
  
  # Neue Methode für Assets (CSS, JS, Bilder)
  def assets
    # Pfad aus der URL extrahieren
    path = params[:path]
    
    # Sicherheitscheck: Verhindere Directory Traversal
    if path.include?('..') || path.start_with?('/')
      render_404
      return
    end
    
    # Asset-Datei aus public/docs laden
    asset_path = Rails.root.join('public', 'docs', path)
    
    # Wenn die Datei nicht existiert, 404
    unless File.exist?(asset_path)
      render_404
      return
    end
    
    # Content-Type basierend auf Dateiendung setzen
    content_type = case File.extname(asset_path)
                   when '.css'
                     'text/css'
                   when '.js'
                     'application/javascript'
                   when '.png', '.jpg', '.jpeg', '.gif', '.svg', '.ico'
                     "image/#{File.extname(asset_path)[1..-1]}"
                   when '.woff', '.woff2', '.ttf', '.eot'
                     'font/woff'
                   else
                     'application/octet-stream'
                   end
    
    response.headers['Content-Type'] = content_type
    
    # Asset-Datei senden
    send_file asset_path, disposition: 'inline'
  end
  
  private
  
  def render_404
    render file: Rails.root.join('public', 'docs', '404.html'), 
           layout: false, 
           status: :not_found
  end
end 