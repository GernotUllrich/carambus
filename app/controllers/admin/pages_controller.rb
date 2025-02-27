module Admin
  class PagesController < Admin::ApplicationController
    # Add any custom behavior here
    
    # Override this method to customize how the preview is rendered
    def show
      super
      @page = requested_resource
      @rendered_content = @page.rendered_content if @page.content_type == 'markdown'
    end
    
    # Add a preview action
    def preview
      if request.post?
        # Für POST-Anfragen (aus dem Editor)
        content = params[:page][:content]
        content_type = params[:page][:content_type] || 'markdown'
        
        html = render_content(content, content_type)
        
        render json: { html: html, success: true }
      else
        # Für GET-Anfragen (aus der Show-Ansicht)
        page = Page.find(params[:id])
        
        # Rendere den Inhalt mit einem minimalen Layout
        render layout: false, inline: <<~HTML
          <!DOCTYPE html>
          <html>
          <head>
            <title>#{page.title}</title>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
              body { 
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                line-height: 1.6;
                color: #333;
                max-width: 800px;
                margin: 0 auto;
                padding: 20px;
              }
              pre { background: #f5f5f5; padding: 10px; border-radius: 4px; overflow-x: auto; }
              code { background: #f5f5f5; padding: 2px 4px; border-radius: 3px; }
              img { max-width: 100%; height: auto; }
              table { border-collapse: collapse; width: 100%; }
              table, th, td { border: 1px solid #ddd; }
              th, td { padding: 8px; text-align: left; }
              th { background-color: #f2f2f2; }
            </style>
          </head>
          <body>
            #{page.rendered_content}
          </body>
          </html>
        HTML
      end
    end
    
    # Override this method to handle publishing/archiving
    def update
      if params[:publish] && requested_resource.draft?
        requested_resource.publish
        redirect_to admin_page_path(requested_resource), notice: "Page was successfully published."
      elsif params[:archive] && requested_resource.published?
        requested_resource.archive
        redirect_to admin_page_path(requested_resource), notice: "Page was successfully archived."
      else
        super
      end
    end
    
    private
    
    def page_params
      params.require(:page).permit(:title, :content, :summary, :super_page_id, 
                                  :position, :content_type, :status, :tags, 
                                  :crud_minimum_roles)
    end
    
    def render_content(content, content_type)
      return '' if content.blank?
      
      if content_type == 'markdown'
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
      else
        content
      end
    end
  end
end 