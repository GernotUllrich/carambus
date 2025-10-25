# frozen_string_literal: true

module Api
  # AI-powered search controller
  # Handles natural language search queries and converts them to filtered results
  class AiSearchController < ApplicationController
    before_action :authenticate_user!
    
    # POST /api/ai_search
    # Parameters:
    #   - query: Natural language search string
    #   - locale: 'de' or 'en' (optional, defaults to current I18n.locale)
    # 
    # Returns:
    #   {
    #     success: true/false,
    #     entity: "tournaments",
    #     filters: "Season:2024/2025 Region:HH",
    #     confidence: 95,
    #     explanation: "Suche nach Turnieren...",
    #     path: "/tournaments?sSearch=Season:2024/2025+Region:HH",
    #     error: "..." (nur bei Fehler)
    #   }
    def create
      query = params[:query]&.strip
      locale = params[:locale].presence || I18n.locale.to_s
      
      if query.blank?
        return render json: {
          success: false,
          error: locale == 'en' ? 'No search query provided' : 'Keine Suchanfrage angegeben'
        }, status: :unprocessable_entity
      end

      result = AiSearchService.call(query: query, user: current_user, locale: locale)
      
      if result[:success]
        render json: result, status: :ok
      else
        render json: result, status: :unprocessable_entity
      end
    rescue StandardError => e
      Rails.logger.error "AiSearchController error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      locale = params[:locale].presence || I18n.locale.to_s
      render json: {
        success: false,
        error: locale == 'en' ? 'An unexpected error occurred' : 'Ein unerwarteter Fehler ist aufgetreten'
      }, status: :internal_server_error
    end
  end
end

