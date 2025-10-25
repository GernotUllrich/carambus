# frozen_string_literal: true

module Api
  # AI-powered documentation search controller
  # Provides intelligent answers from Carambus documentation
  class AiDocsController < ApplicationController
    before_action :authenticate_user!
    
    # POST /api/ai_docs
    # Parameters:
    #   - query: Natural language question (German)
    #   - locale: 'de' or 'en' (optional, defaults to 'de')
    # 
    # Returns:
    #   {
    #     success: true/false,
    #     answer: "AI-generated answer",
    #     docs_links: [{ title: "...", url: "..." }],
    #     snippets: ["relevant text 1", "relevant text 2"],
    #     confidence: 80,
    #     error: "..." (nur bei Fehler)
    #   }
    def create
      query = params[:query]&.strip
      locale = params[:locale].presence || I18n.locale.to_s
      
      if query.blank?
        return render json: {
          success: false,
          error: 'Keine Frage angegeben'
        }, status: :unprocessable_entity
      end

      result = AiDocsService.call(
        query: query, 
        user: current_user,
        locale: locale
      )
      
      if result[:success]
        render json: result, status: :ok
      else
        render json: result, status: :unprocessable_entity
      end
    rescue StandardError => e
      Rails.logger.error "AiDocsController error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      render json: {
        success: false,
        error: 'Ein unerwarteter Fehler ist aufgetreten'
      }, status: :internal_server_error
    end
  end
end

