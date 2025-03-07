class CarambusRender < Redcarpet::Render::HTML
  def block_html(raw_html)
    %(<div class="container mx-auto mt-8">#{raw_html}</div>)
  end

  def header(text, header_level)
    "<h#{header_level} class='font-bold text-xl mt-4'>#{text}</h#{header_level}>\n"
  end

  def paragraph(text)
    if text.match(/<%.*%>/)
      text
    else
      "<p class='text-base text-gray-700 dark:text-gray-200 leading-relaxed my-4'>\n#{text}</p>\n"
    end
  end

  def block_code(text, language)
    text
  end

  def codespan(code)
    "#{code}\n"
  end

  def doc_header
    '<div class="py-10 max-w-2xl m-auto text-center flex flex-col items-center justify-center">' + "\n"
  end

  def doc_footer
   "</div>\n"
  end
end
