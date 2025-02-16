class DashboardController < ApplicationController
  def show
    return unless request.host == "roald.carambus.de"

    nil unless current_user.present?
    # redirect_to "/roald/#{current_user.code.crypt('roald').gsub('/', 'x')}/ANTARKTIS_BILDERTAUSCH/album/index.html"
  end
end
