# frozen_string_literal: true

# Controller for managing content pages
class PagesController < ApplicationController
  before_action :authenticate_user!, except: [:index, :show]
  before_action :set_page, only: [:show, :edit, :update, :destroy, :publish, :archive]
  before_action :authorize_page, except: [:index, :new, :create]
  before_action :authorize_action, only: [:new, :create]

  # GET /pages
  def index
    @pages = Page.accessible_to(current_user)
                .includes(:super_page)
                .order('super_page_id NULLS FIRST, position')

    # Filter by tag if provided
    if params[:tag].present?
      @pages = @pages.where("tags @> ?", [params[:tag]].to_json)
      @tag = params[:tag]
    end

    # Only show root pages in the main index
    @root_pages = @pages.root_pages.ordered
  end

  # GET /pages/1
  def show
    @sub_pages = @page.sub_pages
                     .accessible_to(current_user)
                     .ordered
  end

  # GET /pages/new
  def new
    @page = Page.new(super_page_id: params[:super_page_id])
    @parent_pages = Page.accessible_to(current_user, 'update').ordered
  end

  # GET /pages/1/edit
  def edit
    @parent_pages = Page.accessible_to(current_user, 'update')
                       .where.not(id: @page.id)
                       .where.not(id: @page.sub_pages.pluck(:id))
                       .ordered
  end

  # POST /pages
  def create
    @page = Page.new(page_params)
    @page.author = current_user

    if @page.save
      redirect_to @page, notice: 'Page was successfully created.'
    else
      @parent_pages = Page.accessible_to(current_user, 'update').ordered
      render :new
    end
  end

  # PATCH/PUT /pages/1
  def update
    if @page.update(page_params)
      redirect_to @page, notice: 'Page was successfully updated.'
    else
      @parent_pages = Page.accessible_to(current_user, 'update')
                         .where.not(id: @page.id)
                         .where.not(id: @page.sub_pages.pluck(:id))
                         .ordered
      render :edit
    end
  end

  # DELETE /pages/1
  def destroy
    @page.destroy
    redirect_to pages_url, notice: 'Page was successfully deleted.'
  end

  # POST /pages/1/publish
  def publish
    @page.publish
    redirect_to @page, notice: 'Page was successfully published.'
  end

  # POST /pages/1/archive
  def archive
    @page.archive
    redirect_to @page, notice: 'Page was successfully archived.'
  end

  # POST /pages/preview
  def preview
    content = params[:content]

    # Create a temporary page object to render the content
    page = Page.new(content: content, content_type: 'markdown')

    render json: { html: page.rendered_content }
  end

  private

  # Use callbacks to share common setup or constraints between actions
  def set_page
    @page = Page.find(params[:id])
  end

  # Only allow a list of trusted parameters through
  def page_params
    params.require(:page).permit(
      :title, :content, :summary, :super_page_id, :position,
      :content_type, :status, :published_at, tags: [],
      crud_minimum_roles: [:create, :read, :update, :delete]
    )
  end

  # Authorize the page for the current action
  def authorize_page
    action = case params[:action]
             when 'show' then 'read'
             when 'edit', 'update', 'publish', 'archive' then 'update'
             when 'destroy' then 'delete'
             else params[:action]
             end

    unless @page.accessible_to?(current_user, action)
      flash[:alert] = "You don't have permission to #{action} this page."
      redirect_to pages_path
    end
  end

  # Authorize the action for creating new pages
  def authorize_action
    unless Page.accessible_to(current_user, 'create').exists? || current_user&.system_admin?
      flash[:alert] = "You don't have permission to create pages."
      redirect_to pages_path
    end
  end
end
