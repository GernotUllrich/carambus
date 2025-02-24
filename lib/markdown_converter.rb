require 'redcarpet'
require 'nokogiri'

class MarkdownConverter
  def initialize
    @markdown = Redcarpet::Markdown.new(
      Redcarpet::Render::HTML.new(
        with_toc_data: true,
        hard_wrap: true,
        link_attributes: { target: '_blank' }
      ),
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      superscript: true,
      footnotes: true
    )
  end

  def convert(markdown_text)
    # Convert markdown to HTML
    html = @markdown.render(markdown_text)
    
    # Parse HTML with Nokogiri for additional processing
    doc = Nokogiri::HTML(html)

    # Add CSS classes to tables
    doc.css('table').each do |table|
      table['class'] = 'table table-striped table-bordered'
    end

    # Add CSS classes to code blocks
    doc.css('pre code').each do |code|
      code['class'] = 'language-ruby' unless code['class']
    end

    # Wrap images with figure tags and add captions
    doc.css('img').each do |img|
      # Get the alt text which contains our caption
      caption = img['alt']
      
      # Create a new figure element
      figure = Nokogiri::XML::Node.new('figure', doc)
      figure['class'] = 'figure'
      
      # Move the image inside the figure
      img.parent.add_child(figure)
      figure.add_child(img)
      
      # Add caption if present
      if caption && !caption.empty?
        figcaption = Nokogiri::XML::Node.new('figcaption', doc)
        figcaption['class'] = 'figure-caption'
        figcaption.content = caption
        figure.add_child(figcaption)
      end
    end

    # Return the processed HTML
    doc.to_html
  end

  def convert_file(input_path, output_path)
    # Read markdown file
    markdown_text = File.read(input_path)
    
    # Convert to HTML
    html = convert(markdown_text)
    
    # Wrap with HTML template
    full_html = <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>#{File.basename(input_path, '.*').capitalize}</title>
        <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
        <link href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.24.1/themes/prism.min.css" rel="stylesheet">
        <style>
          body { 
            padding: 2rem;
            max-width: 900px;
            margin: 0 auto;
          }
          img {
            max-width: 100%;
            height: auto;
          }
          .figure {
            margin: 1.5rem 0;
          }
          .figure-caption {
            text-align: center;
            font-style: italic;
            margin-top: 0.5rem;
          }
        </style>
      </head>
      <body>
        <div class="container">
          #{html}
        </div>
        <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.24.1/prism.min.js"></script>
      </body>
      </html>
    HTML
    
    # Write to output file
    File.write(output_path, full_html)
  end
end

# Usage example:
if __FILE__ == $0
  if ARGV.length != 2
    puts "Usage: ruby markdown_converter.rb input.md output.html"
    exit 1
  end

  input_file = ARGV[0]
  output_file = ARGV[1]

  unless File.exist?(input_file)
    puts "Error: Input file '#{input_file}' not found"
    exit 1
  end

  begin
    converter = MarkdownConverter.new
    converter.convert_file(input_file, output_file)
    puts "Successfully converted #{input_file} to #{output_file}"
  rescue => e
    puts "Error converting file: #{e.message}"
    exit 1
  end
end 