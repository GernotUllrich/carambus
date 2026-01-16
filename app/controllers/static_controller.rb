class StaticController < ApplicationController
  before_action :authenticate_user!, only: [:start]
  before_action only: %i[index start intro] do
    #@navbar = @footer = !(current_user.present? && current_user == User.scoreboard) TODO JS current_user
    @navbar = @footer = true
  end

  def index; end

  def about
    # Redirect to docs_page for about documentation
    redirect_to docs_page_path(path: 'about', locale: I18n.locale.to_s)
  end

  def start
    redirect_to root_path
  end

  def search
    # Redirect to search documentation
    redirect_to docs_page_path(path: 'search', locale: I18n.locale.to_s)
  end

  def intro
    # Redirect to main documentation index
    redirect_to docs_page_path(path: 'index', locale: I18n.locale.to_s)
  end

  def index_t; end

  def training
    params
  end

  def update_version
    unless local_server?
      redirect_to repo_version_path, alert: "Update is only available on local servers"
      return
    end

    # Run the deployment in a background process
    deploy_script = "#{Rails.root}/bin/deploy.sh"
    
    unless File.exist?(deploy_script)
      redirect_to repo_version_path, alert: "Deploy script not found at #{deploy_script}"
      return
    end

    # Start deployment in background
    pid = Process.spawn(
      { 'RAILS_ENV' => Rails.env.to_s },
      deploy_script,
      out: Rails.root.join('log', 'deploy.log').to_s,
      err: [:child, :out]
    )
    Process.detach(pid)

    redirect_to repo_version_path, 
                notice: "Deployment started in background. The application will restart automatically. Please refresh this page in 1-2 minutes."
  end

  def pricing
    plans = Plan.visible.sorted
    unless plans.any?
      redirect_to root_path,
                  alert: t(".no_plans_html",
                           link: helpers.link_to_if(current_user&.admin?, "Add a visible plan in the admin",
                                                    admin_plans_path))
    end
    @monthly_plans, @yearly_plans = plans.partition(&:monthly?)
  end

  def terms
    # Redirect to docs_page for terms documentation
    redirect_to docs_page_path(path: 'terms', locale: I18n.locale.to_s)
  end

  def privacy
    # Redirect to docs_page for privacy documentation
    redirect_to docs_page_path(path: 'privacy', locale: I18n.locale.to_s)
  end

  def database_syncing
    # Redirect to docs_page for database syncing documentation
    redirect_to docs_page_path(path: 'database_syncing', locale: I18n.locale.to_s)
  end

  # Neue Methode: Einzelne MkDocs-Dokumente in das Carambus-Layout integrieren
  def docs_page
    # Pfad aus der URL extrahieren (z.B. "tournament" oder "about" oder "managers/tournament-management")
    path = params[:path]
    locale = params[:locale] || I18n.locale.to_s
    
    # Sicherheitscheck: Verhindere Directory Traversal
    if path.include?('..') || path.start_with?('/')
      render_404
      return
    end
    
    # Versuche verschiedene Pfadstrukturen
    possible_paths = [
      Rails.root.join('docs', "#{path}.#{locale}.md"),              # Neue Struktur: about.de.md
      Rails.root.join('docs', locale, "#{path}.md"),                # Alte Struktur: de/about.md
      Rails.root.join('docs', path, "#{locale}.md"),                # Sehr alte Struktur: about/de.md
    ]
    
    # Auch mit anderem Locale versuchen falls nicht gefunden
    other_locale = locale == 'de' ? 'en' : 'de'
    possible_paths += [
      Rails.root.join('docs', "#{path}.#{other_locale}.md"),
      Rails.root.join('docs', other_locale, "#{path}.md"),
      Rails.root.join('docs', path, "#{other_locale}.md"),
    ]
    
    # Erste existierende Datei verwenden
    docs_path = possible_paths.find { |p| File.exist?(p) }
    
    # Wenn keine Datei gefunden, 404
    unless docs_path
      render_404
      return
    end
    
    # Sprache aus gefundenem Pfad extrahieren
    if docs_path.to_s.include?(".#{other_locale}.md")
      locale = other_locale
    end
    
    # Markdown-Inhalt laden
    markdown_content = File.read(docs_path)
    
    # Front Matter extrahieren (falls vorhanden)
    front_matter, content = extract_front_matter(markdown_content)
    
    # Titel aus Front Matter oder Pfad extrahieren
    @page_title = front_matter['title'] || path.split('/').last.humanize
    
    # Markdown mit Redcarpet zu HTML rendern
    @rendered_content = render_markdown(content)
    
    # Layout rendern
    render 'docs_page', layout: 'application'
  end

  private

  # Front Matter aus Markdown extrahieren
  def extract_front_matter(content)
    if content.start_with?('---')
      parts = content.split('---', 3)
      if parts.length >= 3
        front_matter = YAML.safe_load(parts[1]) || {}
        content = parts[2].strip
        [front_matter, content]
      else
        [{}, content]
      end
    else
      [{}, content]
    end
  rescue YAML::SyntaxError
    [{}, content]
  end

  # Markdown mit Redcarpet zu HTML rendern
  def render_markdown(content)
    return '' if content.blank?

    renderer = MarkdownRenderer.new
    markdown = Redcarpet::Markdown.new(renderer, {
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      superscript: true,
      underline: true,
      highlight: true,
      quote: true,
      footnotes: true
    })

    markdown.render(content)
  end

  def render_404
    render file: Rails.root.join('public', '404.html'), status: :not_found, layout: false
  end
end
