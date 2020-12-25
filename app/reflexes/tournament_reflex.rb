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
    val = nil if val <=0
    tournament.update_attribute(:innings_goal, val)
  end

  def balls_goal
    morph :nothing
    tournament = Tournament.find(element.dataset["id"])
    val = element.attributes["value"].to_i
    val = nil if val <=0
    tournament.update_attribute(:balls_goal, val)
  end

  def time_out_stoke_preparation_sec
    morph :nothing
    tournament = Tournament.find(element.dataset["id"])
    val = element.attributes["value"].to_i
    val = nil if val <=0
    tournament.update_attribute(:time_out_stoke_preparation_sec, val)
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

end
