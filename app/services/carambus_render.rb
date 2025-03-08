class CarambusRender < Redcarpet::Render::HTML

  def block_html(raw_html)
    %(<div class="container mx-auto mt-8">#{raw_html}</div>)
  end

  def header(text, header_level)
    "<h#{header_level} class='font-bold mt-4'>#{text}</h#{header_level}>\n"
  end

  def paragraph(text)
    if text.match(/<%.*%>/)
      text
    else
      p_css = @p_css.presence ||  "text-base text-gray-700 #{@p_css_add} dark:text-gray-200 leading-relaxed my-4"
      "<p class='#{p_css}'>\n#{text}</p>\n"
    end
  end

  def block_code(text, language)
    text
  end

  def codespan(code)
    "#{code}\n"
  end

  def doc_header
    css = @wrapper_css.presence || "py-10 max-w-2xl m-auto #{@wrapper_css_add} flex flex-col"
    "<div class=\"#{css}\">" + "\n"
  end

  def doc_footer
   "</div>\n"
  end

  def preprocess(full_document)
    @p_css_add = full_document.match(/p_css_add:\s*(.*) %>/).andand[1]
    @wrapper_css = full_document.match(/wrapper_css:\s*(.*) %>/).andand[1]
    @wrapper_css_add = full_document.match(/wrapper_css_add:\s*(.*) %>/).andand[1]
    @p_css = full_document.match(/p_css:\s*(.*) %>/).andand[1]
    full_document
  end
end
