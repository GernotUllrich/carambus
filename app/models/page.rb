# frozen_string_literal: true

# == Schema Information
#
# Table name: pages
#
#  id                 :integer          not null, primary key
#  title              :string           not null
#  content            :text
#  summary            :text
#  super_page_id      :integer
#  position           :integer
#  author_type        :string
#  author_id          :integer
#  content_type       :string           default("markdown")
#  status             :integer          default(0)
#  published_at       :datetime
#  tags               :json
#  metadata           :json
#  crud_minimum_roles :json
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  version            :string           default("0.1")
#
class Page < ApplicationRecord
  # Enable versioning with PaperTrail
  has_paper_trail
  
  # Associations
  belongs_to :author, polymorphic: true, optional: true
  belongs_to :super_page, class_name: 'Page', optional: true
  has_many :sub_pages, class_name: 'Page', foreign_key: 'super_page_id', dependent: :nullify
  
  # Enums
  enum status: { draft: 0, published: 1, archived: 2 }
  
  # Validations
  validates :title, presence: true
  validates :content_type, inclusion: { in: ['markdown'] }
  validates :position, numericality: { only_integer: true, allow_nil: true }
  
  # Callbacks
  before_validation :set_default_values
  before_save :update_version
  after_save :update_positions
  
  # Scopes
  scope :root_pages, -> { where(super_page_id: nil) }
  scope :published, -> { where(status: :published) }
  scope :ordered, -> { order(position: :asc) }
  
  # Default values for crud_minimum_roles
  DEFAULT_ROLES = {
    'create' => 'system_admin',
    'read' => 'player',
    'update' => 'system_admin',
    'delete' => 'system_admin'
  }.freeze
  
  # Class methods
  
  # Returns pages accessible to the given user based on their role
  def self.accessible_to(user, action = 'read')
    return none unless user
    
    user_role = user.role.to_s
    
    # System admins can access all pages
    return all if user.system_admin?
    
    # For other users, check the crud_minimum_roles
    where("crud_minimum_roles->>'#{action}' IN (?) OR crud_minimum_roles->>'#{action}' IS NULL", 
          roles_accessible_to(user_role))
  end
  
  # Returns an array of roles that the given role can access
  def self.roles_accessible_to(role)
    case role
    when 'system_admin'
      ['system_admin', 'club_admin', 'player']
    when 'club_admin'
      ['club_admin', 'player']
    when 'player'
      ['player']
    else
      []
    end
  end
  
  # Instance methods
  
  # Check if the user can perform the given action on this page
  def accessible_to?(user, action = 'read')
    return false unless user
    
    # System admins can do anything
    return true if user.system_admin?
    
    # Get the minimum role required for this action
    required_role = (crud_minimum_roles || {})[action] || DEFAULT_ROLES[action]
    
    # Check if the user's role is sufficient
    case required_role
    when 'player'
      true # Everyone can access
    when 'club_admin'
      user.club_admin? || user.system_admin?
    when 'system_admin'
      user.system_admin?
    else
      false
    end
  end
  
  # Renders the content as HTML using Redcarpet
  def rendered_content
    return '' if content.blank?
    
    if content_type == 'markdown'
      begin
        renderer = MarkdownRenderer.new
        
        markdown = Redcarpet::Markdown.new(
          renderer,
          autolink: true,
          tables: true,
          fenced_code_blocks: true,
          strikethrough: true,
          superscript: true,
          underline: true,
          highlight: true,
          footnotes: true
        )
        
        markdown.render(content)
      rescue => e
        Rails.logger.error "Error rendering markdown: #{e.message}"
        "<p>Error rendering content: #{e.message}</p>"
      end
    else
      content
    end
  end
  
  # Returns the full hierarchical path of the page
  def path
    if super_page
      "#{super_page.path} > #{title}"
    else
      title
    end
  end
  
  # Increments the minor version (0.1 -> 0.2)
  def increment_minor_version
    current_version = version || '0.1'  # Default to '0.1' if version is nil
    major, minor = current_version.split('.')
    self.version = "#{major}.#{minor.to_i + 1}"
  end
  
  # Increments the major version (0.1 -> 1.0)
  def increment_major_version
    major, _minor = version.split('.')
    self.version = "#{major.to_i + 1}.0"
  end
  
  # Publishes the page
  def publish
    self.status = :published
    self.published_at = Time.current
    increment_major_version
    save
  end
  
  # Archives the page
  def archive
    self.status = :archived
    save
  end
  
  private
  
  # Sets default values for new records
  def set_default_values
    self.content_type ||= 'markdown'
    self.status ||= :draft
    self.crud_minimum_roles ||= DEFAULT_ROLES
    self.tags ||= []
    self.metadata ||= {}
    
    # Set position to the end of the list if not specified
    if position.nil? && super_page
      max_position = super_page.sub_pages.maximum(:position) || 0
      self.position = max_position + 1
    elsif position.nil?
      max_position = Page.where(super_page_id: nil).maximum(:position) || 0
      self.position = max_position + 1
    end
  end
  
  # Updates the version number
  def update_version
    if content_changed? || title_changed?
      increment_minor_version
    end
  end
  
  # Updates positions of sibling pages
  def update_positions
    return unless saved_change_to_position? || saved_change_to_super_page_id?
    
    # Get all siblings
    siblings = super_page ? super_page.sub_pages.where.not(id: id) : Page.where(super_page_id: nil).where.not(id: id)
    
    # Reorder siblings if necessary
    siblings.where('position >= ?', position).order(:position).each do |sibling|
      sibling.update_column(:position, sibling.position + 1)
    end
  end
end 