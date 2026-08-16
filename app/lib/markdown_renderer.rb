# frozen_string_literal: true

require 'pathname'

# Custom Markdown renderer that uses Rouge for syntax highlighting
# rubocop:disable Lint/MissingSuper

class MarkdownRenderer < Redcarpet::Render::HTML
  # Remove the Rouge::Plugins::Redcarpet include since it's causing issues
  # include Rouge::Plugins::Redcarpet

  def initialize(options = {})
    @locale = options[:locale] || I18n.locale.to_s
    @current_path = options[:current_path] || ''
    super options.merge(
      hard_wrap: true,
      link_attributes: { target: '_blank', rel: 'noopener' }
    )
  end

  # Override link rendering to transform internal .md links to Rails routes
  def link(link, title, content)
    # Check if this is an internal .md link (with or without anchor)
    if link.match?(/\.md(#|$)/) && !link.start_with?('http://', 'https://', '//')
      # Split anchor from path
      path, anchor = link.split('#', 2)
      
      # Remove .md extension
      path = path.sub(/\.md$/, '')
      
      # Remove language suffixes (.de, .en) if present
      # This handles both old-style links and ensures compatibility
      path = path.sub(/\.(de|en)$/, '')
      
      # Relative Pfade gegen das Verzeichnis des aktuellen Dokuments aufloesen.
      #
      # Vorher wurde '../' schlicht abgeschnitten, statt eine Ebene hoeher zu
      # gehen: in docs/developers/services/party-monitor.de.md zeigte
      # '../developer-guide.de.md' auf /docs_page/de/developer-guide statt auf
      # .../de/developers/developer-guide — 29 Links im publizierten Teil der
      # Doku liefen so ins Leere.
      #
      # Pathname#cleanpath rechnet '..' korrekt gegen @current_path. Fuehrt ein
      # Link aus dem docs-Baum heraus (z.B. '../../CHANGELOG.md'), bleibt ein
      # '..' im Ergebnis stehen; der Directory-Traversal-Guard in
      # StaticController#docs_page faengt das als 404 ab.
      unless path.start_with?('/')
        base = @current_path.to_s.empty? ? Pathname.new('.') : Pathname.new(@current_path)
        path = (base + path).cleanpath.to_s
      end
      
      # Convert to Rails docs_page route with locale
      rails_path = "/docs_page/#{@locale}/#{path}"
      
      # Re-add anchor if present
      rails_path += "##{anchor}" if anchor
      
      # Build the link tag (internal links stay in same window)
      title_attr = title ? " title=\"#{title}\"" : ""
      "<a href=\"#{rails_path}\"#{title_attr}>#{content}</a>"
    else
      # External links or non-.md links: use default behavior with target="_blank"
      target = link.start_with?('http://', 'https://', '//') ? ' target="_blank" rel="noopener"' : ''
      title_attr = title ? " title=\"#{title}\"" : ""
      "<a href=\"#{link}\"#{title_attr}#{target}>#{content}</a>"
    end
  end

  # Implement a simpler version of the code block highlighting
  def block_code(code, language)
    language ||= 'text'
    
    begin
      # Only use Rouge if the language is specified
      if language && language != 'text'
        lexer = Rouge::Lexer.find_fancy(language) || Rouge::Lexers::PlainText.new
        formatter = Rouge::Formatters::HTML.new
        "<div class=\"highlight\"><pre class=\"highlight #{language}\"><code>#{formatter.format(lexer.lex(code))}</code></pre></div>"
      else
        # For plain text, just wrap in a pre tag
        "<pre><code>#{code}</code></pre>"
      end
    rescue => e
      # If Rouge fails, fall back to plain text
      "<pre><code>#{code}</code></pre>"
    end
  end
  # rubocop:enable Lint/MissingSuper

end
