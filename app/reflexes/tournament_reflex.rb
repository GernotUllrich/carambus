# frozen_string_literal: true

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

  def innings_goal
    morph :nothing
    tournament = Tournament.find(element.dataset["id"])
    val = element.attributes["value"].to_i
    #val = nil if val <=0
    tournament.update_attribute(:innings_goal, val)
  end

  def timeouts
    morph :nothing
    tournament = Tournament.find(element.dataset["id"])
    val = element.attributes["value"].to_i
    val = 0 if val < 0
    tournament.update_attribute(:timeouts, val)
  end

  def balls_goal
    morph :nothing
    tournament = Tournament.find(element.dataset["id"])
    val = element.attributes["value"].to_i
    val = nil if val <= 0
    tournament.update_attribute(:balls_goal, val)
  end

  def timeout
    morph :nothing
    tournament = Tournament.find(element.dataset["id"])
    val = element.attributes["value"].to_i
    val = nil if val <= 0
    tournament.update_attribute(:timeout, val)
  end

  def admin_controlled
    morph :nothing
    tournament = Tournament.find(element.dataset["id"])
    val = element.attributes["value"] == "1"
    tournament.update_attribute(:admin_controlled, val)
  end

  def gd_has_prio
    morph :nothing
    tournament = Tournament.find(element.dataset["id"])
    val = element.attributes["value"] == "1"
    tournament.update_attribute(:gd_has_prio, val)
  end

  def time_out_warm_up_first_min
    morph :nothing
    tournament = Tournament.find(element.dataset["id"])
    val = element.attributes["value"].to_i
    val = nil if val <= 0
    tournament.update_attribute(:time_out_warm_up_first_min, val)
  end

  def time_out_warm_up_follow_up_min
    morph :nothing
    tournament = Tournament.find(element.dataset["id"])
    val = element.attributes["value"].to_i
    val = nil if val <= 0
    tournament.update_attribute(:time_out_warm_up_follow_up_min, val)
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
    party = party_game.party
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
    morph :nothing
    tournament = Tournament.find(element.dataset["id"])
    checked = element.attributes["checked"]
    player = Player.find(element.attributes["id"].split("-")[1].to_i)
    seeding = nil
    if checked
      seeding = tournament.seedings.create(player_id: player.id)
    else
      tournament.seedings.where(player_id: player.id).destroy_all
    end
    balls_goal_html = ApplicationController.render(
      partial: "tournaments/balls_goal",
      locals: { tournament: tournament, player: player, seeding: seeding }
    )
    cable_ready["tournament-stream"].outer_html(
      selector: "#balls-#{player.id}",
      html: balls_goal_html
    )
    cable_ready.broadcast
  end

  def change_no_show
    tournament = Tournament.find(element.dataset["id"])
    checked = element.attributes["checked"]
    player = Player.find(element.attributes["id"].split("-")[1].to_i)
    seeding = tournament.seedings.where(player_id: player.id)
    if checked
      seeding.update(state: "no_show")
    else
      seeding.update(state: "registered")
    end
  end

  def change_position
    tournament = Tournament.find(element.dataset["id"])
    player = Player.find(element.attributes["id"].split("-")[1].to_i)
    seeding = tournament.seedings.where("id > ?", 50000000).where(player_id: player.id).first
    seeding.set_list_position(element.attributes["value"].to_i)
  end

  def change_point_goal
    morph :nothing
    tournament = Tournament.find(element.dataset["id"])
    val = element.attributes["value"].to_i
    player = Player.find(element.attributes["id"].split("-")[1].to_i)
    seeding = tournament.seedings.where(player_id: player.id).first
    seeding.update(balls_goal: val)
  end

end
