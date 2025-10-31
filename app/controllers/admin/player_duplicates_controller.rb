# frozen_string_literal: true

module Admin
  class PlayerDuplicatesController < ApplicationController
    before_action :authenticate_user!
    before_action :load_duplicates, only: [:index]
    before_action :load_duplicate_group, only: [:show]

    def index
      @total_count = @duplicate_groups.count
      @current_page = (params[:page] || 1).to_i
      @per_page = 1
      
      @duplicate_group = @duplicate_groups[@current_page - 1] if @duplicate_groups.any?
      @has_next = @current_page < @total_count
      @has_prev = @current_page > 1
    end

    def show
      # Already loaded by before_action
    end

    def merge
      master_id = params[:master_id].to_i
      other_ids = params[:other_ids].to_s.split(',').map(&:to_i)
      page = params[:page].to_i
      
      master = Player.find_by(id: master_id, type: nil)
      
      if master.nil?
        flash[:error] = "Master player not found (ID: #{master_id})"
        redirect_to admin_player_duplicates_path(page: page) and return
      end
      
      # Remove master_id from others list
      other_ids = other_ids - [master_id]
      others = Player.where(id: other_ids, type: nil).to_a
      
      if others.empty?
        flash[:error] = "No other players to merge (other_ids: #{params[:other_ids]})"
        redirect_to admin_player_duplicates_path(page: page) and return
      end
      
      begin
        Player.merge_players(master, others)
        flash[:success] = "Successfully merged #{others.count} player(s) (IDs: #{others.map(&:id).join(', ')}) into #{master.fullname} (ID: #{master.id})"
        Rails.logger.info "==== MANUAL MERGE ==== User #{current_user&.email} merged #{others.map(&:id).join(', ')} into #{master.id} (#{master.fullname})"
      rescue StandardError => e
        flash[:error] = "Error merging players: #{e.message}"
        Rails.logger.error "==== MANUAL MERGE ERROR ==== #{e.message}\n#{e.backtrace.join("\n")}"
      end
      
      # Go to next duplicate group
      redirect_to admin_player_duplicates_path(page: page)
    end

    def keep_separate
      fl_name = params[:fl_name]
      player_ids = params[:player_ids].split(',').map(&:to_i)
      
      Rails.logger.info "==== MANUAL REVIEW ==== User decided to keep separate: #{fl_name} (IDs: #{player_ids.join(', ')})"
      flash[:info] = "Marked '#{fl_name}' as separate players (IDs: #{player_ids.join(', ')})"
      
      # Go to next duplicate group
      next_page = params[:page].to_i
      redirect_to admin_player_duplicates_path(page: next_page)
    end

    def stats
      # Show overall statistics
      @duplicates = Player.where(type: nil)
                          .group(:fl_name)
                          .having('count(*) > 1')
                          .count
      
      @total_duplicate_fl_names = @duplicates.count
      @total_duplicate_records = @duplicates.values.sum
      @total_players = Player.where(type: nil).count
      
      # Pattern analysis
      @pattern_stats = analyze_patterns(@duplicates.keys.first(100))
    end

    private

    def load_duplicates
      # Get all duplicate fl_names
      duplicates_hash = Player.where(type: nil)
                              .group(:fl_name)
                              .having('count(*) > 1')
                              .count
      
      @duplicate_groups = duplicates_hash.keys.map do |fl_name|
        players = Player.where(type: nil, fl_name: fl_name).order(:id).to_a
        {
          fl_name: fl_name,
          players: players
        }
      end.sort_by { |g| g[:fl_name] }
    end

    def load_duplicate_group
      fl_name = params[:fl_name]
      @players = Player.where(type: nil, fl_name: fl_name).order(:id).to_a
      @fl_name = fl_name
      
      if @players.empty?
        flash[:error] = "No players found for '#{fl_name}'"
        redirect_to admin_player_duplicates_path
      end
    end

    def analyze_patterns(fl_names)
      patterns = {
        same_cc_id: 0,
        ba_id_equals_dbu_nr: 0,
        new_vs_old: 0,
        both_ba_id_only: 0,
        both_have_clubs: 0,
        complex: 0
      }
      
      fl_names.each do |fl_name|
        players = Player.where(type: nil, fl_name: fl_name).to_a
        
        if players.count != 2
          patterns[:complex] += 1
          next
        end
        
        p1, p2 = players
        
        # Categorize
        if p1.cc_id.present? && p2.cc_id.present? && p1.cc_id == p2.cc_id
          patterns[:same_cc_id] += 1
        elsif (p1.ba_id.present? && p2.dbu_nr.present? && p1.ba_id == p2.dbu_nr) ||
              (p2.ba_id.present? && p1.dbu_nr.present? && p2.ba_id == p1.dbu_nr)
          patterns[:ba_id_equals_dbu_nr] += 1
        elsif (p1.dbu_nr.present? && p1.cc_id.present? && p2.ba_id.present? && p2.dbu_nr.blank? && p2.cc_id.blank? && p2.season_participations.empty?) ||
              (p2.dbu_nr.present? && p2.cc_id.present? && p1.ba_id.present? && p1.dbu_nr.blank? && p1.cc_id.blank? && p1.season_participations.empty?)
          patterns[:new_vs_old] += 1
        elsif p1.ba_id.present? && p2.ba_id.present? && p1.dbu_nr.blank? && p2.dbu_nr.blank?
          patterns[:both_ba_id_only] += 1
        else
          patterns[:complex] += 1
        end
      end
      
      patterns
    end
  end
end

