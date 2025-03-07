class TranslationService
  def self.translate(text, source_language, target_language)
    api_key = ENV['ANTHROPIC_API_KEY'].presence || Rails.application.credentials.fetch(:anthropic_key)
    Rails.logger.debug("Using API key: #{api_key.present? ? "Present (not shown)" : "Missing"}")

    # First, let's parse the markdown to identify structure elements
    markdown_elements = extract_markdown_elements(text)
    
    uri = URI.parse("https://api.anthropic.com/v1/messages")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["x-api-key"] = api_key
    request["anthropic-version"] = "2023-06-01"

    # Create a system prompt that instructs the model to preserve markdown
    system_instruction = "You are a specialized markdown translator. Your task is to translate text while perfectly preserving all markdown formatting, including headers, lists, code blocks, tables, links, and other markdown elements."

    # Create a more structured user prompt
    user_prompt = <<~PROMPT
      # Translation Task
      
      Translate the following markdown text from #{source_language} to #{target_language}.
      
      ## Important Instructions:
      1. Preserve ALL markdown syntax exactly as it appears
      2. Translate ONLY the text content, not the markdown syntax
      3. Keep all links, code blocks, and formatting intact
      4. Do not add any explanations or comments
      5. Return ONLY the translated markdown
      
      ## Text to Translate:
      
      #{text}
    PROMPT
    
    Rails.logger.debug("Translation prompt prepared with system instructions")

    # Correct format for Claude API - system is a top-level parameter
    request_body = {
      model: "claude-3-5-sonnet-20240620",
      max_tokens: 4000,
      system: system_instruction,
      messages: [
        { role: "user", content: user_prompt }
      ],
      temperature: 0.1 # Lower temperature for more consistent output
    }

    request.body = request_body.to_json

    Rails.logger.debug("Sending request to Claude API with model: #{request_body[:model]}")
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    Rails.logger.debug("Response status: #{response.code}")
    
    result = JSON.parse(response.body)

    if result["error"]
      Rails.logger.error("API Error: #{result["error"]["message"]}")
      return nil
    end

    translated_text = if result.dig("content", 0, "text")
      result.dig("content", 0, "text")
    elsif result.dig("content", 0, "type") == "text"
      result.dig("content", 0, "text")
    else
      Rails.logger.error("Unexpected response format: #{result}")
      nil
    end

    # Clean up the response
    if translated_text
      # Remove any markdown code block markers that Claude might have added
      translated_text = translated_text.gsub(/^```markdown\s*/, '')
      translated_text = translated_text.gsub(/^```\s*$/, '')
      
      # Remove any "Translation Task" or instruction text that might have been echoed back
      translated_text = translated_text.gsub(/^# Translation Task.*?## Text to Translate:\s*/m, '')
      
      # Remove any other common prefixes Claude might add
      translated_text = translated_text.gsub(/^Here's the translation:?\s*/i, '')
      translated_text = translated_text.gsub(/^Translated text:?\s*/i, '')
      translated_text = translated_text.gsub(/^Translation:?\s*/i, '')
      
      translated_text = translated_text.strip
      
      # Verify markdown elements are preserved
      if !verify_markdown_elements(translated_text, markdown_elements)
        Rails.logger.warn("Some markdown elements may not have been preserved in translation")
      end
    end

    Rails.logger.debug("Translation completed with markdown format preserved: #{translated_text ? 'success' : 'nil'}")

    translated_text
  rescue => e
    Rails.logger.error("Translation error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    nil
  end
  
  # Extract key markdown elements to verify they're preserved
  def self.extract_markdown_elements(text)
    elements = {
      headers: text.scan(/^#+\s+.+$/),
      code_blocks: text.scan(/```[\s\S]*?```/),
      inline_code: text.scan(/`[^`]+`/),
      links: text.scan(/\[.+?\]\(.+?\)/),
      images: text.scan(/!\[.+?\]\(.+?\)/),
      lists: text.scan(/^[\s]*[-*+]\s+.+$/),
      tables: text.scan(/\|.+\|[\s\S]*?\|.+\|/)
    }
    
    # Count the elements
    elements.transform_values(&:count)
  end
  
  # Verify that key markdown elements are preserved
  def self.verify_markdown_elements(translated_text, original_elements)
    translated_elements = extract_markdown_elements(translated_text)
    
    # Check if counts match for each element type
    original_elements.all? do |element_type, count|
      translated_count = translated_elements[element_type] || 0
      if translated_count < count
        Rails.logger.warn("Missing #{element_type}: expected #{count}, got #{translated_count}")
        false
      else
        true
      end
    end
  end

  def self.test_with_models
    models = [
      "claude-3-5-sonnet-20240620",
      "claude-3-opus-20240229",
      "claude-3-haiku-20240307",
      "claude-3-sonnet-20240229",
      "claude-2.1",
      "claude-2.0",
      "claude-instant-1.2"
    ]

    puts "Testing translation with different Claude models:"

    models.each do |model|
      puts "\nTrying model: #{model}"
      result = translate_with_model("Hallo, wie geht es dir?", "Deutsch", "Englisch", model)
      puts "Result: #{result || 'Failed'}"
    end
  end

  def self.translate_with_model(text, source_language, target_language, model)
    api_key = ENV['ANTHROPIC_API_KEY'].presence || Rails.application.credentials.fetch(:anthropic_key)

    uri = URI.parse("https://api.anthropic.com/v1/messages")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["x-api-key"] = api_key
    request["anthropic-version"] = "2023-06-01"

    prompt = "Übersetze den folgenden Text von #{source_language} nach #{target_language}:\n\n#{text}"

    request_body = {
      model: model,
      max_tokens: 1000,
      messages: [
        { role: "user", content: prompt }
      ]
    }

    request.body = request_body.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    puts "Response status: #{response.code}"
    puts "Response body: #{response.body[0..200]}..." if response.body.length > 200

    result = JSON.parse(response.body)

    if result["error"]
      puts "Error: #{result["error"]["message"]}"
      return nil
    end

    if result.dig("content", 0, "text")
      result.dig("content", 0, "text")
    elsif result.dig("content", 0, "type") == "text"
      result.dig("content", 0, "text")
    else
      nil
    end
  rescue => e
    puts "Error: #{e.message}"
    nil
  end

  def self.test_translation
    result = translate("Hallo, wie geht es dir?", "Deutsch", "Englisch")
    puts "Test translation result: #{result || 'nil'}"
    result
  end
end
