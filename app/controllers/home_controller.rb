class HomeController < ApplicationController
  include ApplicationHelper

  def index
    @no_home = true
  end
end
