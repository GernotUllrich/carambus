module Taggable
  extend ActiveSupport::Concern
  
  included do
    has_many :taggings, as: :taggable, dependent: :destroy
    has_many :tags, through: :taggings
    
    # Scope to find records with specific tags
    scope :with_tag, ->(tag_name) {
      joins(:tags).where(tags: { name: tag_name })
    }
    
    scope :with_any_tag, ->(tag_names) {
      joins(:tags).where(tags: { name: tag_names }).distinct
    }
    
    scope :with_all_tags, ->(tag_names) {
      tag_names.inject(self) { |relation, tag_name| relation.with_tag(tag_name) }
    }
  end
  
  # Add tags by name (creates tags if they don't exist)
  def tag_list=(names)
    self.tags = names.split(',').map do |name|
      Tag.find_or_create_by!(name: name.strip)
    end
  end
  
  # Get comma-separated tag names
  def tag_list
    tags.pluck(:name).join(', ')
  end
  
  # Add a single tag
  def add_tag(tag_name, category: nil)
    tag = Tag.find_or_create_by!(name: tag_name) do |t|
      t.category = category if category
    end
    tags << tag unless tags.include?(tag)
  end
  
  # Remove a tag
  def remove_tag(tag_name)
    tag = Tag.find_by(name: tag_name)
    tags.delete(tag) if tag
  end
  
  # Check if has a specific tag
  def has_tag?(tag_name)
    tags.exists?(name: tag_name)
  end
  
  # Get tags by category
  def tags_by_category(category)
    tags.where(category: category)
  end
end
