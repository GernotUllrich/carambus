# encoding: utf-8
class HomeController < ApplicationController
  include ApplicationHelper

  def index
  end

  protected

  def set_subtitle
    @subtitle = "Märkte, Börsen, Aktien - Analysen"
    @sitepage = Page.find_by_slug("home")
    @metadescription = @sitepage.description
  end

end
