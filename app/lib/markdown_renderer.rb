# frozen_string_literal: true

# Custom Markdown renderer that uses Rouge for syntax highlighting
# rubocop:disable Lint/MissingSuper

class MarkdownRenderer < Redcarpet::Render::HTML
  # Remove the Rouge::Plugins::Redcarpet include since it's causing issues
  # include Rouge::Plugins::Redcarpet

  def initialize(options = {})
    @locale = options[:locale] || I18n.locale.to_s
    super options.merge(
      hard_wrap: true,
      link_attributes: { target: '_blank', rel: 'noopener' }
    )
  end

  # Override link rendering to transform internal .md links to Rails routes
  def link(link, title, content)
    # Check if this is an internal .md link
    if link.end_with?('.md') && !link.start_with?('http://', 'https://', '//')
      # Remove .md extension
      path = link.sub(/\.md$/, '')
      
      # Remove any leading '../' or './' - we'll use absolute paths from docs root
      # This matches how MkDocs resolves links
      path = path.gsub(/^\.\.\//, '').gsub(/^\.\//, '')
      
      # Convert to Rails docs_page route with locale
      rails_path = "/docs_page/#{@locale}/#{path}"
      
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
