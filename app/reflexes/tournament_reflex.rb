# frozen_string_literal: true

# The TournamentReflex class in Ruby on Rails handles the real-time updating of
# various attributes of a Tournament object using StimulusReflex and ActionCable
# for real-time, websocket-based communication. The attributes include
# innings goal, timeouts, balls goal, and others.
# Each method in the class corresponds to an attribute update action.
class TournamentReflex < ApplicationReflex
  # Add Reflex methods in this file.
  #
  # All Reflex instances expose the following properties:
  #
  #   - connection - the Action  Cable connection
  #   - channel - the ActionCable channel
  #   - request - an ActionDispatch::Request proxy for the socket connection
  #   - session - the ActionDispatch::Session store for the current visitor
  #   - url - the URL of the page that triggered the reflex
  #   - element - a Hash like object  that represents the HTML element that triggered the reflex
  #   - params - parameters from the element's closest form (if any)
  #
  # Example:
  #
  #   def example(argument=true)
  #     # Your logic here...
  #     # Any declared instance variables will be made available to the Rails controller and view.
  #   end
  #
  # Learn more at: https://docs.stimulusreflex.com

  ATTRIBUTE_METHODS = {
    innings_goal: "I",
    timeouts: "I",
    balls_goal: "I",
    timeout: "I",
    auto_upload_to_cc: "B",
    continuous_placements: "B",
    gd_has_prio: "B",
    kickoff_switches_with: "S",
    allow_follow_up: "B",
    allow_overflow: "B",
    color_remains_with_set: "B",
    fixed_display_left: "K",
    sets_to_play: "I",
    sets_to_win: "I",
    time_out_warm_up_first_min: "I",
    time_out_warm_up_follow_up_min: "I"
  }

  PARTICIPANT_LIST_REFLEXES = %i[change_seeding change_no_show change_position move_up move_down
    change_point_goal sort_by_ranking sort_by_handicap].freeze

  # Plan 17-05: dieselben Rechte wie im TournamentsController — die Teilnehmerliste nach
  # manage_teilnehmerliste?, die Felder des Start-Formulars nach prepare_tournament?.
  # Bis hierher pruefte der Reflex nichts; jeder Besucher der Seite konnte die Liste umbauen.
  # Plan 20-02: die Party-Reflexe (change_party_seeding, change_party_game_seeding) haengen am
  # Recht des Start-Formulars. Sie sind toter Code (party_games hat keine Spalte tournament_id,
  # die ausloesenden Partials werden nirgends gerendert) — gegatet statt entfernt (Betreiber).
  before_reflex :authorize_participant_list, only: PARTICIPANT_LIST_REFLEXES
  before_reflex :authorize_tournament_setup, only: ATTRIBUTE_METHODS.keys + %i[change_party_seeding change_party_game_seeding]

  ATTRIBUTE_METHODS.keys.each do |attribute|
    define_method(attribute.to_s) do
      morph :nothing
      tournament = Tournament.find(element.dataset["id"])
      val = case ATTRIBUTE_METHODS[attribute]
            when "I"
              element.value.to_i
            when "K"
              element.value.to_s.presence
            when "S"
              element.value.to_s.presence || "set"
            when "B"
              !!element.checked
            end
      
      # Use setter to trigger delegation to TournamentLocal (for local tournaments)
      # Direct update would bypass delegation and write to wrong table!
      tournament.unprotected = true
      tournament.send("#{attribute}=", val)
      tournament.save!
      tournament.unprotected = false
    end
  end

  def change_party_seeding
    tournament = Tournament.find(element.dataset["id"])
    checked = element.attributes["checked"]
    party = Party.find(element.attributes["id"].match(/party_(\d+)/)[1].to_i)
    if checked
      party.party_games.each do |pg|
        pg.update(tournament: tournament)
      end
    else
      party.party_games.each do |pg|
        pg.update(tournament: nil)
      end
    end
    party_record_html = ApplicationController.render(
      partial: "tournaments/party_record",
      locals: { tournament: tournament, party: party }
    )
    cable_ready["tournament-stream"].inner_html(
      selector: "#party_record_#{party.id}",
      html: party_record_html
    )
    cable_ready.broadcast
  end

  def change_party_game_seeding
    tournament = Tournament.find(element.dataset["id"])
    checked = element.attributes["checked"]
    party_game = PartyGame.find(element.attributes["id"].match(/party_game_(\d+)/)[1].to_i)
    @party = party_game.party
    party = @party
    if checked
      party_game.update(tournament: tournament)
    else
      party_game.update(tournament: nil)
    end
    party_record_html = ApplicationController.render(
      partial: "tournaments/party_record",
      locals: { tournament: tournament, party: party }
    )
    cable_ready["tournament-stream"].inner_html(
      selector: "#party_record_#{party.id}",
      html: party_record_html
    )
    cable_ready.broadcast
  end

  def change_seeding
    tournament = Tournament.find(element.dataset["id"])
    checked = element.attributes["checked"]
    player = Player.find(element.attributes["id"].split("-")[1].to_i)
    # Plan 36-05: Logik in RegionServer::PlayerRegistration — sie muss vor jeder Aenderung die
    # Liste materialisieren (sonst verdeckt die erste Aenderung alle bisherigen Teilnehmer) und
    # ist dort ohne StimulusReflex-Infrastruktur pruefbar.
    RegionServer::PlayerRegistration.set_participation(
      tournament: tournament, player: player, participating: checked
    )
    tournament.save!

    # Plan 44-02: Mitgliedschaftsänderung atomar in die CC zurückpushen (async, Queue+Retry).
    PushAccreditationToCcJob.enqueue_for(
      tournament: tournament, player: player,
      target: checked ? :ensure_participant : :remove_participant, acting_user: current_user
    )

    # Rendere die ganze Seite neu, damit Gruppenzuordnungen aktualisiert werden
    morph :page
  end

  def change_no_show
    tournament = Tournament.find(element.dataset["id"])
    checked = element.attributes["checked"]
    player = Player.find(element.attributes["id"].split("-")[1].to_i)
    seeding = tournament.seedings.where(player_id: player.id)
    if checked
      seeding.find_each(&:mark_no_show!)
      target = :deaccredit
    else
      seeding.find_each(&:reset_seeding_state!)
      target = :accredit
    end
    # Plan 44-01: TL-Akkreditierungsänderung atomar in die CC zurückpushen (async, Queue+Retry).
    PushAccreditationToCcJob.enqueue_for(
      tournament: tournament, player: player, target: target, acting_user: current_user
    )
  end

  def change_position
    tournament = Tournament.find(element.dataset["id"])
    player = Player.find(element.attributes["id"].split("-")[1].to_i)
    seeding = tournament.seedings.where("id > ?", 50_000_000).where(player_id: player.id).first
    seeding&.set_list_position(element.attributes["value"].to_i)
    
    # Rendere die ganze Seite neu, damit Gruppenzuordnungen aktualisiert werden
    morph :page
  end
  
  def move_up
    tournament = Tournament.find(element.dataset["tournament-id"])
    seeding = Seeding.find(element.dataset["seeding-id"])
    seeding.move_higher
    seeding.reload
    
    # Rendere die ganze Seite neu, damit Gruppenzuordnungen aktualisiert werden
    morph :page
  end
  
  def move_down
    tournament = Tournament.find(element.dataset["tournament-id"])
    seeding = Seeding.find(element.dataset["seeding-id"])
    seeding.move_lower
    seeding.reload
    
    # Rendere die ganze Seite neu, damit Gruppenzuordnungen aktualisiert werden
    morph :page
  end

  def change_point_goal
    morph :nothing
    tournament = Tournament.find(element.dataset["id"])
    val = element.attributes["value"].to_i
    player = Player.find(element.attributes["id"].split("-")[1].to_i)
    seeding = tournament.seedings.where(player_id: player.id).first
    seeding&.update(balls_goal: val)
  end

  def sort_by_ranking
    tournament = Tournament.find(element.dataset["id"])
    
    # Sortiere nach Ranking - OHNE balls_goal zu verändern
    hash = {}
    
    # Bestimme den Scope für lokale Seedings
    seeding_scope = "seedings.id >= #{Seeding::MIN_ID}"
    
    tournament.seedings.where(seeding_scope).each do |seeding|
      # Vorsaison name-basiert (Season#previous). Der frühere ba_id-Versatz inkl.
      # "2021/2022 ? 2 : 1"-Hack kompensierte eine ba_id-Lücke und ist damit hinfällig.
      hash[seeding] = if tournament.team_size > 1
                        999
                      else
                        seeding.player.player_rankings.where(discipline_id: Discipline.find_by_name("Freie Partie klein"),
                                                             season_id: Season.current_season&.previous&.id)
                               .first&.rank.presence || 999
                      end
    end
    
    # Sortiere und aktualisiere NUR die Position (balls_goal bleibt erhalten)
    sorted = hash.to_a.sort_by { |a| a[1] }
    sorted.each_with_index do |a, ix|
      seeding, = a
      seeding.update_column(:position, ix + 1)
    end
    
    # Rendere die ganze Seite neu, damit neue Sortierung sichtbar wird
    morph :page
  end

  def sort_by_handicap
    tournament = Tournament.find(element.dataset["id"])
    
    # Sortiere nach Vorgabeziel (balls_goal, höher = stärker = niedrigere Position)
    # Bester Spieler hat höchstes Punktziel (kleinstes Handicap)
    hash = {}
    
    # Bestimme den Scope für lokale Seedings
    seeding_scope = "seedings.id >= #{Seeding::MIN_ID}"
    
    tournament.seedings.where(seeding_scope).each do |seeding|
      hash[seeding] = seeding.balls_goal.to_i
    end
    
    # Sortiere absteigend (höchstes balls_goal = Position 1)
    # Aktualisiere NUR die Position (balls_goal bleibt natürlich erhalten)
    sorted = hash.to_a.sort_by { |a| -a[1] }
    sorted.each_with_index do |a, ix|
      seeding, = a
      seeding.update_column(:position, ix + 1)
    end
    
    # Rendere die ganze Seite neu, damit neue Sortierung sichtbar wird
    morph :page
  end

  private

  def authorize_participant_list
    abort_unless_allowed(:manage_teilnehmerliste?)
  end

  def authorize_tournament_setup
    abort_unless_allowed(:prepare_tournament?)
  end

  # move_up/move_down tragen das Turnier als data-tournament-id, alle anderen als data-id.
  def abort_unless_allowed(rule)
    tournament = Tournament.find_by(id: element.dataset["id"] || element.dataset["tournament-id"])
    return if tournament && TournamentPolicy.new(current_user, tournament).public_send(rule)

    Rails.logger.warn "[TournamentReflex] #{method_name} abgewiesen (#{rule}): " \
      "Benutzer #{current_user&.id.inspect}, Turnier #{tournament&.id.inspect}"
    throw :abort
  end
end
