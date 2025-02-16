class HomeController < ApplicationController
  include ApplicationHelper

  def index
    @no_home = true
  end

  protected

  def set_subtitle
    @subtitle = "Märkte, Börsen, Aktien - Analysen"
    @sitepage = Page.find_by_slug("home")
    @metadescription = @sitepage.description
  end
end
