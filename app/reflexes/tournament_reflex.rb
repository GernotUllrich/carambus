# frozen_string_literal: true

class TournamentReflex < ApplicationReflex
  # Add Reflex methods in this file.
  #
  # All Reflex instances expose the following properties:
  #
  #   - connection - the ActionCable connection
  #   - channel - the ActionCable channel
  #   - request - an ActionDispatch::Request proxy for the socket connection
  #   - session - the ActionDispatch::Session store for the current visitor
  #   - url - the URL of the page that triggered the reflex
  #   - element - a Hash like object that represents the HTML element that triggered the reflex
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
    val = 0 if val <0
    tournament.update_attribute(:timeouts, val)
  end

  def balls_goal
    morph :nothing
    tournament = Tournament.find(element.dataset["id"])
    val = element.attributes["value"].to_i
    val = nil if val <=0
    tournament.update_attribute(:balls_goal, val)
  end

  def timeout
    morph :nothing
    tournament = Tournament.find(element.dataset["id"])
    val = element.attributes["value"].to_i
    val = nil if val <=0
    tournament.update_attribute(:timeout, val)
  end

  def time_out_warm_up_first_min
    morph :nothing
    tournament = Tournament.find(element.dataset["id"])
    val = element.attributes["value"].to_i
    val = nil if val <=0
    tournament.update_attribute(:time_out_warm_up_first_min, val)
  end

  def time_out_warm_up_follow_up_min
    morph :nothing
    tournament = Tournament.find(element.dataset["id"])
    val = element.attributes["value"].to_i
    val = nil if val <=0
    tournament.update_attribute(:time_out_warm_up_follow_up_min, val)
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

  def change_point_goal
    morph :nothing
    tournament = Tournament.find(element.dataset["id"])
    val = element.attributes["value"].to_i
    player = Player.find(element.attributes["id"].split("-")[1].to_i)
    seeding = tournament.seedings.where(player_id: player.id).first
    seeding.update(balls_goal: val)
  end

end
