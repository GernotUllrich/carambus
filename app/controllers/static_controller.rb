class StaticController < ApplicationController

  before_action only: [:index, :start, :intro] do
    @navbar = @footer = false
  end

  def index

  end

  def about
    params
  end

  def start
  end

  def intro
  end

  def index_t
  end

  def training
  end

  def pricing
    redirect_to root_path, alert: t(".no_plans") unless Plan.without_free.exists?
  end

  def terms
  end

  def privacy
  end
end
