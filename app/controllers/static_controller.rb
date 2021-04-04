class StaticController < ApplicationController
  before_action :authenticate_user!, only: [:start]
  before_action only: [:index, :start, :intro] do
    @navbar = @footer = false
  end

  def index

  end

  def about
    params
  end

  def start
    redirect_to root_path
  end

  def intro
  end

  def index_t
  end

  def training
    params
  end

  def pricing
    redirect_to root_path, alert: t(".no_plans") unless Plan.without_free.exists?
  end

  def terms
  end

  def privacy
    params
  end
end
