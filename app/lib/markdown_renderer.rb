# frozen_string_literal: true

# Custom Markdown renderer that uses Rouge for syntax highlighting
# rubocop:disable Lint/MissingSuper

class MarkdownRenderer < Redcarpet::Render::HTML
  # Remove the Rouge::Plugins::Redcarpet include since it's causing issues
  # include Rouge::Plugins::Redcarpet

  def initialize(options = {})
    super options.merge(
      hard_wrap: true,
      link_attributes: { target: '_blank', rel: 'noopener' }
    )
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
