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
#  slug               :string           not null
#
class Page < ApplicationRecord
  include PageHelper
  # Enable versioning with PaperTrail
  has_paper_trail

  # Associations
  # noinspection RailsParamDefResolve
  belongs_to :author, polymorphic: true, optional: true
  belongs_to :super_page, class_name: 'Page', optional: true
  has_many :sub_pages, class_name: 'Page', foreign_key: 'super_page_id', dependent: :nullify

  # Enums
  enum :status, {:draft=>"draft", :published=>"published", :archived=>"archived"}
  enum :content_type, {:markdown=>"markdown"}

  # Validations
  validates :title, presence: true
  validates :content_type, presence: true
  validates :status, presence: true
  validates :slug, uniqueness: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  # Callbacks
  before_validation :set_defaults, on: :create
  before_save :update_version
  after_save :generate_markdown_file

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
      %w[system_admin club_admin player]
    when 'club_admin'
      %w[club_admin player]
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

    # Directly set the status attribute
    self[:status] = 'published'
    self.published_at = Time.current

    # Save with exception handling
    begin
      save!
    rescue => e
      Rails.logger.error "Error saving: #{e.message}"
      Rails.logger.error e.backtrace&.join("\n")
      false
    end
  end

  # Archives the page
  def archive
    return unless published?

    self.status = 'archived'
    save!  # Use save! to detect errors
  end

  # Attribute methods
  def tags
    self[:tags] || []
  end

  def metadata
    self[:metadata] || {}
  end

  def crud_minimum_roles
    self[:crud_minimum_roles] || {}
  end

  # Explicit methods for status that also handle nil values
  def draft?
    status == 'draft'
  end

  def published?
    status == 'published'
  end

  def archived?
    status == 'archived'
  end

  # Add to your existing Page model
  def publish_with_translation
    # Ensure we have content to publish
    return false if content.blank?

    begin
      # Create directory if it doesn't exist
      FileUtils.mkdir_p(File.dirname(published_path))

      marked_content = add_front_matter(content)
      front_matter, translated_content = split_front_matter(marked_content)
      markdown = Redcarpet::Markdown.new(CarambusRender)
      html_content = markdown.render(translated_content)
      if html_content.present?
        File.write(published_path(:de), "<!--#{front_matter}-->\n#{html_content}")
      end
      # Write the original German content

      marked_content = add_front_matter(content_en.presence || content)
      # Use DeepL for translation
      front_matter, translated_content = DeeplTranslationService.translate(marked_content)
      markdown = Redcarpet::Markdown.new(CarambusRender)
      html_content = markdown.render(translated_content)
      if html_content.present?
        File.write(published_path(:en), "<!--#{front_matter}-->\n#{html_content}")
        update(last_translated_at: Time.current)
        true
      else
        # Still publish the German version even if translation fails
        Rails.logger.error("Failed to translate page #{id}: #{title}")
        false
      end
    rescue => e
      Rails.logger.error("Error in publish_with_translation for page #{id}: #{e.message}")
      Rails.logger.error(e.backtrace&.join("\n"))
      false
    end
  end

  # Helper method to get the published file path with language
  def published_path(language = :de)
    language = language.to_s.downcase
    File.join(Rails.root, 'app/views/static', "#{slug}.#{language}.html.erb")
  end

  private

  # Sets default values for new records
  def set_defaults
    self.status ||= 'draft'
    self.content_type ||= 'markdown'
    self.tags ||= []
    self.slug ||= self.title.parameterize
    self.metadata ||= {}
    self.crud_minimum_roles ||= {}
    self.position ||= 0
    self.version ||= '0.1'  # Add default version
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

end
