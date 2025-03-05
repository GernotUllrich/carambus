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
  enum status: { draft: 'draft', published: 'published', archived: 'archived' }
  enum content_type: { markdown: 'markdown' }
  
  # Validations
  validates :title, presence: true
  validates :content_type, presence: true
  validates :status, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  
  # Callbacks
  before_validation :set_defaults
  before_save :update_version
  after_save :generate_markdown_file, if: -> { saved_change_to_status? && published? }
  
  # Scopes
  scope :root_pages, -> { where(super_page_id: nil) }
  scope :published, -> { where(status: 'published') }
  scope :draft, -> { where(status: 'draft') }
  scope :archived, -> { where(status: 'archived') }
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
    
    if markdown?
      renderer = MarkdownRenderer.new
      markdown = Redcarpet::Markdown.new(renderer, {
        autolink: true,
        tables: true,
        fenced_code_blocks: true,
        strikethrough: true,
        superscript: true,
        underline: true,
        highlight: true,
        quote: true,
        footnotes: true
      })
      
      markdown.render(content)
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
    return if published?
    
    self.status = 'published'
    self.published_at = Time.current
    increment_major_version
    save
  end
  
  # Archives the page
  def archive
    return unless published?
    
    self.status = 'archived'
    save
  end
  
  # Attribute-Methoden
  def tags
    self[:tags] || []
  end
  
  def metadata
    self[:metadata] || {}
  end
  
  def crud_minimum_roles
    self[:crud_minimum_roles] || {}
  end
  
  private
  
  # Sets default values for new records
  def set_defaults
    self.status ||= 'draft'
    self.content_type ||= 'markdown'
    self.tags ||= []
    self.metadata ||= {}
    self.crud_minimum_roles ||= {}
    self.position ||= 0
  end
  
  # Updates the version number
  def update_version
    self.version = SecureRandom.uuid if new_record? || content_changed?
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
  
  # Neue Methode zur Generierung von Markdown-Dateien
  def generate_markdown_file
    # Bestimme den Pfad basierend auf Hierarchie oder Tags
    base_path = Rails.root.join('docs')
    file_path = determine_file_path(base_path)
    
    # Erstelle YAML Front Matter
    front_matter = {
      'title' => title,
      'summary' => summary,
      'version' => version,
      'published_at' => published_at,
      'tags' => tags,
      'metadata' => metadata,
      'position' => position,
      'id' => id
    }.to_yaml
    
    # Erstelle den Markdown-Inhalt
    markdown_content = "---\n#{front_matter}---\n\n#{content}"
    
    # Stelle sicher, dass das Verzeichnis existiert
    FileUtils.mkdir_p(File.dirname(file_path))
    
    # Schreibe die Datei
    File.write(file_path, markdown_content)
    
    # Optional: Git-Operationen
    commit_to_git(file_path) if Rails.env.production?
  rescue => e
    Rails.logger.error(I18n.t('pages.markdown_file.error_generating', message: e.message))
    Rails.logger.error(e.backtrace.join("\n"))
  end
  
  def determine_file_path(base_path)
    # Logik zur Bestimmung des Dateipfads
    # z.B. basierend auf Hierarchie, Tags oder anderen Metadaten
    slug = title.parameterize
    
    if super_page
      # Wenn es eine übergeordnete Seite gibt, erstelle eine Unterverzeichnisstruktur
      parent_path = get_parent_path(super_page)
      return base_path.join(parent_path, "#{slug}.md")
    else
      # Andernfalls speichere direkt im Basisverzeichnis
      return base_path.join("#{slug}.md")
    end
  end
  
  def get_parent_path(page)
    path = []
    current_page = page
    
    # Rekursiv durch die Hierarchie gehen
    while current_page
      path.unshift(current_page.title.parameterize)
      current_page = current_page.super_page
    end
    
    path.join('/')
  end
  
  def commit_to_git(file_path)
    relative_path = file_path.relative_path_from(Rails.root)
    
    system("cd #{Rails.root} && git add #{relative_path}")
    system("cd #{Rails.root} && git commit -m '#{I18n.t('pages.markdown_file.commit_message', title: title)}'")
    # system("cd #{Rails.root} && git push origin main")
  rescue => e
    Rails.logger.error(I18n.t('pages.markdown_file.error_git_operations', message: e.message))
    Rails.logger.error(e.backtrace.join("\n"))
  end
end 