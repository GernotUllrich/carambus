# frozen_string_literal: true

# AI-powered documentation search service
# Searches through MkDocs documentation using ripgrep and provides AI-generated answers
#
# Usage:
#   result = AiDocsService.call(query: "Wie erstelle ich ein Turnier?", user: current_user)
#
class AiDocsService < ApplicationService
  MAX_CONTEXT_LENGTH = 8000 # characters to send to GPT
  MAX_DOCS = 5 # Maximum number of doc files to include
  
  def initialize(options = {})
    super()
    @query = options[:query]&.strip
    @user = options[:user]
    @locale = options[:locale] || 'de'
    @client = OpenAI::Client.new
  end

  def call
    return error_response('Keine Frage angegeben') if @query.blank?
    return error_response('OpenAI nicht konfiguriert') unless openai_configured?

    begin
      # 1. Search docs with ripgrep
      relevant_docs = search_documentation
      
      if relevant_docs.empty?
        return {
          success: true,
          answer: "Leider habe ich in der Dokumentation nichts zu Ihrer Frage gefunden. Versuchen Sie es mit anderen Begriffen oder schauen Sie im Hauptmenü unter 'Docs'.",
          docs_links: [],
          snippets: [],
          confidence: 30
        }
      end
      
      # 2. Ask GPT with documentation context
      ai_response = ask_gpt_with_context(relevant_docs)
      
      # 3. Format response
      {
        success: true,
        answer: ai_response[:answer],
        docs_links: relevant_docs.map { |d| doc_link(d) },
        snippets: relevant_docs.flat_map { |d| d[:snippets] }.first(3),
        confidence: ai_response[:confidence] || 80
      }
    rescue StandardError => e
      Rails.logger.error "AiDocsService error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      error_response("Fehler bei der Dokumentations-Suche: #{e.message}")
    end
  end

  private

  def search_documentation
    docs_path = Rails.root.join('docs')
    
    # Escape query for shell
    safe_query = @query.gsub(/[`$"\\]/, '\\\\\\&')
    
    # Use grep to search through markdown files
    # -i: case insensitive
    # -r: recursive
    # -n: line numbers
    # -A 3: 3 lines after match
    # -B 1: 1 line before match
    # --include: only .md files
    cmd = "grep -rin -A 3 -B 1 --include='*.md' '#{safe_query}' #{docs_path} 2>/dev/null"
    
    output = `#{cmd}`
    
    return [] if output.blank?
    
    # Parse grep output
    # Format: filepath:line:content
    matches_by_file = {}
    current_file = nil
    
    output.each_line do |line|
      # Match format: /path/to/file.md:123:content
      # or /path/to/file.md-123-content (for context lines)
      if line =~ /^([^:]+):(\d+):(.+)$/
        file = $1
        content = $3.strip
        
        next if content.blank? || content.start_with?('#') # Skip headings as matches
        
        matches_by_file[file] ||= {
          file: file,
          title: extract_title_from_file(file),
          snippets: []
        }
        
        # Add snippet (avoid duplicates)
        unless matches_by_file[file][:snippets].include?(content) || content.length < 20
          matches_by_file[file][:snippets] << content
        end
      end
    end
    
    # Return top docs sorted by number of matches
    matches_by_file.values
      .sort_by { |d| -d[:snippets].count }
      .first(MAX_DOCS)
  end

  def extract_title_from_file(filepath)
    # Extract title from file path or first line
    basename = File.basename(filepath, '.md')
    
    # Try to get title from first # heading
    begin
      first_lines = File.read(filepath).lines.first(10)
      heading = first_lines.find { |l| l.start_with?('#') }
      if heading
        return heading.gsub(/^#+\s*/, '').strip
      end
    rescue
      # Fall back to filename
    end
    
    # Convert filename to title
    basename.split(/[_-]/).map(&:capitalize).join(' ')
  end

  def ask_gpt_with_context(docs)
    # Build context from doc snippets
    context = docs.map { |doc|
      "=== #{doc[:title]} ===\n#{doc[:snippets].first(5).join("\n")}"
    }.join("\n\n")
    
    # Truncate if too long
    context = context[0...MAX_CONTEXT_LENGTH] if context.length > MAX_CONTEXT_LENGTH
    
    response = @client.chat(
      parameters: {
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: system_prompt(context) },
          { role: 'user', content: @query }
        ],
        temperature: 0.3,
        max_tokens: 500
      }
    )

    answer = response.dig('choices', 0, 'message', 'content')
    
    {
      answer: answer || 'Keine Antwort generiert',
      confidence: calculate_confidence(docs, answer)
    }
  end

  def system_prompt(context)
    <<~PROMPT
      Du bist der Carambus Hilfe-Assistent für eine deutsche Billard-Verwaltungs-App.
      
      Beantworte Fragen basierend auf der folgenden Dokumentation.
      
      DOKUMENTATION:
      #{context}
      
      ANTWORT-REGELN:
      - Kurz und prägnant (2-5 Sätze)
      - Schritt-für-Schritt Anleitungen wenn möglich
      - Auf Deutsch
      - Freundlicher, hilfreicher Ton
      - Nutze Bulletpoints für Listen
      - Wenn Information nicht in Docs: Ehrlich sagen
      - Verweise auf UI-Elemente: "Gehe zu...", "Klicke auf..."
      
      WICHTIG:
      - Nur Informationen aus der Dokumentation verwenden
      - Keine Erfindungen oder Annahmen
      - Bei Unsicherheit: Alternative Suchbegriffe vorschlagen
    PROMPT
  end

  def calculate_confidence(docs, answer)
    # Simple heuristic for confidence
    return 40 if docs.empty?
    return 60 if docs.count == 1
    return 80 if docs.count >= 2 && answer.present?
    90
  end

  def doc_link(doc)
    # Extract relative path from docs/ directory
    relative_path = doc[:file].to_s.sub(%r{.*/docs/}, '').sub(/\.md$/, '')
    
    {
      title: doc[:title],
      url: Rails.application.routes.url_helpers.docs_page_path(path: relative_path, locale: @locale),
      file: doc[:file]
    }
  end

  def error_response(message)
    {
      success: false,
      error: message,
      answer: '',
      docs_links: [],
      snippets: [],
      confidence: 0
    }
  end

  def openai_configured?
    Rails.application.credentials.dig(:openai, :api_key).present?
  end
end

