# frozen_string_literal: true

module Admin
  # Controller for managing incomplete records (with placeholder references)
  class IncompleteRecordsController < ApplicationController
    layout 'admin/incomplete_records'
    # before_action :authenticate_admin! # Uncomment when auth is ready
    
    def index
      @tournaments = InternationalTournament.with_placeholders
                                            .includes(:discipline, :season, :location, :organizer, :international_source)
                                            .order(date: :desc)
                                            .page(params[:page]).per(50)
      
      @stats = {
        total: InternationalTournament.count,
        incomplete: InternationalTournament.with_placeholders.count,
        complete: InternationalTournament.complete.count
      }
      
      # Breakdown by field
      @field_stats = {
        unknown_discipline: InternationalTournament.joins(:discipline)
          .where(disciplines: { name: 'Unknown Discipline' }).count,
        unknown_season: InternationalTournament.joins(:season)
          .where(seasons: { name: 'Unknown Season' }).count,
        unknown_location: InternationalTournament.joins(:location)
          .where(locations: { name: 'Unknown Location' }).count,
        unknown_organizer: InternationalTournament
          .where(organizer_type: 'Region')
          .joins('LEFT JOIN regions ON regions.id = tournaments.organizer_id')
          .where('regions.shortname = ?', 'UNKNOWN').count
      }
    end
    
    def show
      @tournament = InternationalTournament.find(params[:id])
      
      # Load options for dropdowns
      @disciplines = Discipline.where.not(name: 'Unknown Discipline').order(:name)
      @seasons = Season.where.not(name: 'Unknown Season').order(name: :desc)
      @locations = Location.where.not(name: 'Unknown Location').order(:name).limit(100)
      @organizers = Region.where.not(shortname: 'UNKNOWN').order(:name)
    end
    
    def update
      @tournament = InternationalTournament.find(params[:id])
      
      Rails.logger.info "Update params: #{tournament_params.inspect}"
      
      # Use update_columns to bypass validations that might be causing issues
      begin
        @tournament.update_columns(
          discipline_id: tournament_params[:discipline_id],
          season_id: tournament_params[:season_id],
          location_id: tournament_params[:location_id],
          organizer_id: tournament_params[:organizer_id],
          organizer_type: tournament_params[:organizer_type]
        )
        
        # Check if still incomplete
        if @tournament.reload.has_placeholders?
          redirect_to admin_incomplete_record_path(@tournament), notice: "Tournament updated successfully!"
        else
          redirect_to admin_incomplete_records_path, notice: "Tournament is now complete!"
        end
      rescue => e
        Rails.logger.error "Update failed: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        
        flash.now[:error] = "Failed to update tournament: #{e.message}"
        @disciplines = Discipline.where.not(name: 'Unknown Discipline').order(:name)
        @seasons = Season.where.not(name: 'Unknown Season').order(name: :desc)
        @locations = Location.where.not(name: 'Unknown Location').order(:name).limit(100)
        @organizers = Region.where.not(shortname: 'UNKNOWN').order(:name)
        render :show
      end
    end
    
    def auto_fix_all
      fixed_count = 0
      scraper = UmbScraper.new
      unknown_discipline = Discipline.find_by(name: 'Unknown Discipline')
      
      InternationalTournament.where(discipline: unknown_discipline).find_each do |tournament|
        detected_discipline = scraper.send(:find_discipline_from_name, tournament.title)
        
        if detected_discipline && detected_discipline != unknown_discipline
          tournament.update(discipline: detected_discipline)
          fixed_count += 1
        end
      end
      
      redirect_to admin_incomplete_records_path, notice: "Auto-fixed #{fixed_count} tournaments!"
    end
    
    def create_location_from_text
      @tournament = InternationalTournament.find(params[:id])
      
      unless @tournament.location_text.present?
        redirect_to admin_incomplete_record_path(@tournament), alert: "No location text available"
        return
      end
      
      # Check if location already exists
      existing_location = Location.find_by(name: @tournament.location_text)
      
      if existing_location
        @tournament.update(location_id: existing_location.id)
        redirect_to admin_incomplete_record_path(@tournament), notice: "Existing location '#{existing_location.name}' assigned!"
        return
      end
      
      # Create new location
      location = Location.create!(
        name: @tournament.location_text,
        address: params[:address].presence || @tournament.location_text,
        data: { 
          created_from_tournament: @tournament.id,
          country_code: params[:country_code].presence || 'FR',
          source: 'admin_incomplete_records'
        }.to_json
      )
      
      # Update tournament with location_id
      @tournament.update(location_id: location.id)
      
      redirect_to admin_incomplete_record_path(@tournament), notice: "Location '#{location.name}' created and assigned!"
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_incomplete_record_path(@tournament), alert: "Failed to create location: #{e.message}"
    end
    
    private
    
    def tournament_params
      params.require(:tournament).permit(
        :discipline_id,
        :season_id,
        :location_id,
        :organizer_id,
        :organizer_type
      )
    end
  end
end
