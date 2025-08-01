# frozen_string_literal: true

class Api::LocationsController < ApplicationController
  def autocomplete
    query = params[:q]
    return render json: [] if query.blank?

    locations = Location.where("name ILIKE ?", "%#{query}%")
                       .order(:name)
                       .limit(10)

    suggestions = locations.map do |location|
      {
        value: location.name,
        label: location.name
      }
    end

    render json: suggestions
  end
end 