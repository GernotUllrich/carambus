  # frozen_string_literal: true

# Controller für MkDocs-Dokumentation
class DocsController < ApplicationController
  def show
    # Pfad aus der URL extrahieren (glob route gibt Array zurück)
    path = Array(params[:path]).join('/')

    # Sicherheitscheck: Verhindere Directory Traversal
    if path.include?('..') || path.start_with?('/')
      render_404
      return
    end

    # Datei aus public/docs laden
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

    # Prüfe Dateiendung und serviere entsprechend
    case File.extname(docs_path)
    when '.css'
      send_file docs_path, type: 'text/css', disposition: 'inline'
    when '.js'
      send_file docs_path, type: 'application/javascript', disposition: 'inline'
    when '.png', '.jpg', '.jpeg', '.gif', '.svg', '.ico', '.webp'
      send_file docs_path, type: "image/#{File.extname(docs_path)[1..-1]}", disposition: 'inline'
    when '.woff', '.woff2', '.ttf', '.eot'
      send_file docs_path, type: 'font/woff', disposition: 'inline'
    when '.json'
      send_file docs_path, type: 'application/json', disposition: 'inline'
    else
      # HTML-Datei laden und rendern
      content = File.read(docs_path)
      response.headers['Content-Type'] = 'text/html; charset=utf-8'
      render html: content.html_safe, layout: false
    end
  end

  # Neue Methode für Assets (CSS, JS, Bilder)
  def assets
    # Pfad aus der URL extrahieren (glob route gibt Array zurück)
    path = Array(params[:path]).join('/')

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
