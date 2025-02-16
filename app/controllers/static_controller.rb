class StaticController < ApplicationController
  before_action :authenticate_user!, only: [:start]
  before_action only: %i[index start intro] do
    #@navbar = @footer = !(current_user.present? && current_user == User.scoreboard) TODO JS current_user
    @navbar = @footer = true
  end

  def index; end

  def about
    params
  end

  def start
    redirect_to root_path
  end

  def tournament
    filename = I18n.locale == :de ? "Tournament.de.mds" : "Tournament.en.mds"
    @content = File.read(Rails.root.join("doc/doc/#{filename}"))
  rescue Errno::ENOENT
    @content = t("documentation_not_available")
  end

  def league
    filename = I18n.locale == :de ? "League.de.mds" : "League.en.mds"
    @content = File.read(Rails.root.join("doc/doc/#{filename}"))
  rescue Errno::ENOENT
    @content = t("documentation_not_available")
  end

  def intro; end

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
    @agreement = Rails.application.config.agreements.find { _1.id == :terms_of_service }
  end

  def privacy
    @agreement = Rails.application.config.agreements.find { _1.id == :privacy_policy }
  end
end
