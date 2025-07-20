class StaticController < ApplicationController
  before_action :authenticate_user!, only: [:start]
  before_action only: %i[index start intro] do
    #@navbar = @footer = !(current_user.present? && current_user == User.scoreboard) TODO JS current_user
    @navbar = @footer = true
  end

  def index; end

  def about
  end

  def start
    redirect_to root_path
  end



  def search

  end

  def intro
    render 'carambus-turnier-management'
  end

  def index_t; end

  def training
    params
  end

  def pricing
    plans = Plan.visible.sorted
    unless plans.any?
      redirect_to root_path,
                  alert: t(".no_plans_html",
                           link: helpers.link_to_if(current_user&.admin?, "Add a visible plan in the admin",
                                                    admin_plans_path))
    end
    @monthly_plans, @yearly_plans = plans.partition(&:monthly?)
  end

  def terms
  end

  def privacy
  end

  def database_synching
  end
end
