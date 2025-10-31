# frozen_string_literal: true

# PlayerFinder - Intelligent Player Search and Creation
# 
# This concern provides methods to find existing players with fuzzy matching
# and create new players only when absolutely necessary.
# 
# Key Features:
# - Multi-criteria search (cc_id, dbu_nr, name + club, name only)
# - Prevents duplicate player creation
# - Comprehensive logging for debugging
# - Handles ambiguous cases intelligently
module PlayerFinder
  extend ActiveSupport::Concern

  class_methods do
    # Find or create a player with intelligent matching
    #
    # Search priority:
    # 1. cc_id (unique identifier from Carambolage Cloud)
    # 2. dbu_nr (unique identifier from Deutsche Billard Union)
    # 3. firstname + lastname + club_id (best match)
    # 4. firstname + lastname only (if unambiguous)
    # 5. Create new player (last resort)
    #
    # @param firstname [String] First name
    # @param lastname [String] Last name
    # @param cc_id [Integer, nil] Carambolage Cloud ID
    # @param dbu_nr [Integer, nil] DBU member number
    # @param club_id [Integer, nil] Club ID for better matching
    # @param region_id [Integer, nil] Region ID
    # @param season_id [Integer, nil] Season ID for club matching
    # @param allow_create [Boolean] Allow creation of new player (default: true)
    # @return [Player, nil] Found or created player
    def find_or_create_player(firstname:, lastname:, cc_id: nil, dbu_nr: nil,
                               club_id: nil, region_id: nil, season_id: nil,
                               allow_create: true)
      
      # Normalize names
      firstname = firstname.to_s.strip
      lastname = lastname.to_s.strip
      
      return nil if firstname.blank? && lastname.blank?
      
      # 1. Priority: cc_id (most reliable identifier)
      if cc_id.present? && cc_id.to_i > 0
        player = Player.where(type: nil, cc_id: cc_id).first
        if player.present?
          Rails.logger.debug "==== find_player ==== Found by cc_id: #{cc_id} → Player #{player.id}"
          update_player_if_needed(player, firstname, lastname, nil, dbu_nr, region_id)
          return player
        end
      end
      
      # 2. Priority: dbu_nr (unique identifier, but only for "real" players)
      if dbu_nr.present? && dbu_nr.to_i > 0 && dbu_nr.to_i < 999_000_000
        player = Player.where(type: nil, dbu_nr: dbu_nr).first
        if player.present?
          Rails.logger.debug "==== find_player ==== Found by dbu_nr: #{dbu_nr} → Player #{player.id}"
          update_player_if_needed(player, firstname, lastname, cc_id, nil, region_id)
          return player
        end
      end
      
      # 3. Priority: firstname + lastname + club association
      if club_id.present? && season_id.present?
        players = find_by_name_and_club(firstname, lastname, club_id, season_id)
        if players.count == 1
          player = players.first
          Rails.logger.debug "==== find_player ==== Found by name+club: '#{firstname} #{lastname}' + club #{club_id} → Player #{player.id}"
          update_player_if_needed(player, firstname, lastname, cc_id, dbu_nr, region_id)
          return player
        elsif players.count > 1
          Rails.logger.warn "==== find_player ==== AMBIGUOUS: #{players.count} players with name '#{firstname} #{lastname}' in club #{club_id}"
          # Select player with most associations
          player = select_best_player(players)
          Rails.logger.warn "==== find_player ==== Selected player #{player.id} (most associations)"
          update_player_if_needed(player, firstname, lastname, cc_id, dbu_nr, region_id)
          return player
        end
      end
      
      # 4. Priority: firstname + lastname only (if unambiguous)
      players = Player.where(type: nil, firstname: firstname, lastname: lastname).to_a
      
      if players.count == 1
        player = players.first
        Rails.logger.debug "==== find_player ==== Found by name: '#{firstname} #{lastname}' → Player #{player.id}"
        update_player_if_needed(player, firstname, lastname, cc_id, dbu_nr, region_id)
        return player
        
      elsif players.count > 1
        Rails.logger.warn "==== find_player ==== AMBIGUOUS: #{players.count} players with name '#{firstname} #{lastname}'"
        
        # Try to disambiguate by cc_id or dbu_nr
        if cc_id.present?
          matching = players.find { |p| p.cc_id == cc_id }
          if matching
            Rails.logger.warn "==== find_player ==== Disambiguated by cc_id → Player #{matching.id}"
            return matching
          end
        end
        
        if dbu_nr.present? && dbu_nr.to_i < 999_000_000
          matching = players.find { |p| p.dbu_nr == dbu_nr }
          if matching
            Rails.logger.warn "==== find_player ==== Disambiguated by dbu_nr → Player #{matching.id}"
            return matching
          end
        end
        
        # Select player with most associations
        player = select_best_player(players)
        Rails.logger.warn "==== find_player ==== Selected player #{player.id} (most associations)"
        update_player_if_needed(player, firstname, lastname, cc_id, dbu_nr, region_id)
        return player
      end
      
      # 5. Last resort: Create new player
      if allow_create
        create_new_player(firstname, lastname, cc_id, dbu_nr, club_id, region_id)
      else
        Rails.logger.warn "==== find_player ==== Player not found and creation not allowed: '#{firstname} #{lastname}'"
        nil
      end
    end
    
    private
    
    def find_by_name_and_club(firstname, lastname, club_id, season_id)
      Player.joins(:season_participations)
            .where(type: nil, firstname: firstname, lastname: lastname)
            .where(season_participations: { club_id: club_id, season_id: season_id })
            .distinct
    end
    
    def select_best_player(players)
      # Select player with most associations (most likely the "real" one)
      players.max_by do |p|
        p.game_participations.count * 10 +
        p.season_participations.count * 5 +
        p.seedings.count * 3 +
        p.player_rankings.count * 2 +
        (p.party_a_games.count + p.party_b_games.count) * 1
      end
    end
    
    def update_player_if_needed(player, firstname, lastname, cc_id, dbu_nr, region_id)
      changed = false
      
      # Update cc_id if missing
      if cc_id.present? && player.cc_id.blank?
        player.cc_id = cc_id
        changed = true
      end
      
      # Update dbu_nr if missing (and it's a "real" number)
      if dbu_nr.present? && dbu_nr.to_i < 999_000_000 && player.dbu_nr.blank?
        player.dbu_nr = dbu_nr
        changed = true
      end
      
      # Update region_id if missing
      if region_id.present? && player.region_id.blank?
        player.region_id = region_id
        changed = true
      end
      
      # Update names if they differ (handle "Dr." and other title variations)
      if player.firstname.blank? && firstname.present?
        player.firstname = firstname
        changed = true
      end
      
      if player.lastname.blank? && lastname.present?
        player.lastname = lastname
        changed = true
      end
      
      if changed
        player.save if player.valid?
        Rails.logger.debug "==== find_player ==== Updated player #{player.id} with new data"
      end
      
      player
    end
    
    def create_new_player(firstname, lastname, cc_id, dbu_nr, club_id, region_id)
      # Generate unique ba_id
      max_id = Player.maximum(:id).to_i
      ba_id = 999_000_000 + max_id + 1
      
      player = Player.new(
        firstname: firstname,
        lastname: lastname,
        cc_id: cc_id,
        dbu_nr: dbu_nr,
        region_id: region_id,
        ba_id: ba_id
      )
      
      if player.save
        Rails.logger.warn "==== find_player ==== NEW PLAYER CREATED: Player #{player.id} - '#{firstname} #{lastname}' (cc_id: #{cc_id}, dbu_nr: #{dbu_nr}, ba_id: #{ba_id})"
        player
      else
        Rails.logger.error "==== find_player ==== FAILED TO CREATE PLAYER: '#{firstname} #{lastname}' - Errors: #{player.errors.full_messages.join(', ')}"
        nil
      end
    end
  end
end

