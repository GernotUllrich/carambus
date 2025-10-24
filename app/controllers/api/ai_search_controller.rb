# frozen_string_literal: true

module Api
  # AI-powered search controller
  # Handles natural language search queries and converts them to filtered results
  class AiSearchController < ApplicationController
    before_action :authenticate_user!
    
    # POST /api/ai_search
    # Parameters:
    #   - query: Natural language search string (German)
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
      
      if query.blank?
        return render json: {
          success: false,
          error: 'Keine Suchanfrage angegeben'
        }, status: :unprocessable_entity
      end

      result = AiSearchService.call(query: query, user: current_user)
      
      if result[:success]
        render json: result, status: :ok
      else
        render json: result, status: :unprocessable_entity
      end
    rescue StandardError => e
      Rails.logger.error "AiSearchController error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      render json: {
        success: false,
        error: 'Ein unerwarteter Fehler ist aufgetreten'
      }, status: :internal_server_error
    end
  end
end

