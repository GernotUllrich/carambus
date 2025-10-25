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
    
    # Extract keywords from query (remove question words)
    keywords = extract_keywords(@query)
    return [] if keywords.blank?
    
    # Search for each keyword and combine results
    all_matches = {}
    
    keywords.each do |keyword|
      # Escape for shell
      safe_keyword = keyword.gsub(/['\\]/, '\\\\\&')
      
      # Try ripgrep first, fall back to grep if not available
      if ripgrep_available?
        search_with_ripgrep(safe_keyword, docs_path, all_matches)
      else
        search_with_grep(safe_keyword, docs_path, all_matches)
      end
    end
    
    # Return top docs sorted by relevance
    # Prioritize files with keywords in filename
    all_matches.values
      .sort_by { |d| 
        filename_score = keywords.count { |kw| d[:file].downcase.include?(kw.downcase) } * 100
        snippet_score = d[:snippets].count
        -(filename_score + snippet_score)
      }
      .first(MAX_DOCS)
  end
  
  def ripgrep_available?
    # Check if ripgrep is installed (cache result)
    return @ripgrep_available unless @ripgrep_available.nil?
    
    @ripgrep_available = system('which rg > /dev/null 2>&1')
    
    if @ripgrep_available
      Rails.logger.info "✓ Using ripgrep for docs search"
    else
      Rails.logger.info "⚠ Ripgrep not found, falling back to grep"
    end
    
    @ripgrep_available
  end
  
  def search_with_ripgrep(keyword, docs_path, matches_by_file)
    # Use ripgrep with JSON output for better parsing
    cmd = "rg -i '#{keyword}' #{docs_path} -A 3 -B 1 --json --type md 2>/dev/null"
    output = `#{cmd}`
    return if output.blank?
    
    parse_ripgrep_output(output, matches_by_file)
  end
  
  def search_with_grep(keyword, docs_path, matches_by_file)
    # Fallback to grep (available everywhere)
    cmd = "grep -rin -A 3 -B 1 --include='*.md' '#{keyword}' #{docs_path} 2>/dev/null"
    output = `#{cmd}`
    return if output.blank?
    
    parse_grep_output(output, matches_by_file)
  end
  
  def extract_keywords(query)
    # Remove common German question words and prepositions
    stopwords = %w[wie was wo wann warum welche welcher welches wieso weshalb
                   der die das den dem des ein eine einen einem einer
                   ich du er sie es wir ihr sie mich dich sich uns euch
                   ist sind hat haben kann können muss müssen soll sollen
                   gibt gibt's hat's kann's
                   für von mit bei nach über unter zwischen durch ohne
                   zu auf aus in an als ob wenn dann aber oder und
                   dass weil denn also doch noch nur auch schon mal
                   diese dieser dieses diesem diesen]
    
    # Remove punctuation and split into words
    cleaned = query.gsub(/[?!.,;:]/, '').downcase
    words = cleaned.split(/\s+/)
    keywords = words.reject { |w| stopwords.include?(w) || w.length < 3 }
    
    # Keep at least one meaningful keyword
    if keywords.empty?
      # Fall back to all non-stopwords
      keywords = words.reject { |w| stopwords.include?(w) }
    end
    
    # If still empty, use last word
    keywords = [words.last] if keywords.empty?
    
    keywords
  end
  
  def parse_ripgrep_output(output, matches_by_file = {})
    output.each_line do |line|
      begin
        data = JSON.parse(line)
        
        # Only process match lines (not context or other types)
        next unless data['type'] == 'match'
        
        file = data.dig('data', 'path', 'text')
        line_text = data.dig('data', 'lines', 'text')
        
        next if file.blank? || line_text.blank?
        
        content = line_text.strip
        
        # Skip empty lines and very short snippets
        next if content.blank? || content.length < 10
        
        # Skip markdown headings (they'll be used for titles)
        next if content.match?(/^#+\s/)
        
        matches_by_file[file] ||= {
          file: file,
          title: extract_title_from_file(file),
          snippets: []
        }
        
        # Add snippet (avoid duplicates)
        unless matches_by_file[file][:snippets].include?(content)
          matches_by_file[file][:snippets] << content
        end
      rescue JSON::ParserError
        # Skip non-JSON lines (summary, etc.)
        next
      end
    end
    
    matches_by_file
  end
  
  def parse_grep_output(output, matches_by_file = {})
    # Parse standard grep output
    # Format: /path/to/file.md:123:content or /path/to/file.md-123-content
    output.each_line do |line|
      # Match both actual matches (:) and context lines (-)
      if line =~ /^([^:]+)[:-](\d+)[:-](.+)$/
        file = $1
        content = $3.strip
        
        # Skip separators, empty lines, short snippets
        next if content.blank? || content == '--' || content.length < 10
        
        # Skip markdown headings
        next if content.match?(/^#+\s/)
        
        matches_by_file[file] ||= {
          file: file,
          title: extract_title_from_file(file),
          snippets: []
        }
        
        # Add snippet (avoid duplicates)
        unless matches_by_file[file][:snippets].include?(content)
          matches_by_file[file][:snippets] << content
        end
      end
    end
    
    matches_by_file
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

