# frozen_string_literal: true

class LocationReflex < ApplicationReflex

  def finish
    location = Location.find(element.data_location_id)
    editing_location = session[:editing_location]

    session[:editing_location] = nil if editing_location == location
  end

  def merge(attrs)
    #TODO
    # parent = Location.where(id: attrs[:parent]).first
    # location = Location.find(attrs[:location])
    #
    # return if parent == location
    #
    # location.parent = parent
    # location.save
  end
end
