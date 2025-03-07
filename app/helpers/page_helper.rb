module PageHelper

  private

  def generate_markdown_file
    # Determine the path based on hierarchy or tags
    return unless saved_change_to_status? && published?
    base_path = Rails.root.join('docs')
    file_path = determine_file_path(base_path)

    # Create the Markdown content
    markdown_content = add_front_matter(content)

    # Ensure the directory exists
    FileUtils.mkdir_p(File.dirname(file_path))

    # Write the file
    File.write(file_path, markdown_content)

    # Optional: Git operations
    commit_to_git(file_path) if Rails.env.development?
  rescue => e
    Rails.logger.error(I18n.t('pages.markdown_file.error_generating', message: e.message))
    Rails.logger.error(e.backtrace&.join("\n"))
  end

  def add_front_matter(content)
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
    "---\n#{front_matter}---\n\n#{content}"
  end

  def determine_file_path(base_path)
    # Logic to determine the file path
    # e.g., based on hierarchy, tags, or other metadata

    if super_page
      # If there is a parent page, create a subdirectory structure
      parent_path = get_parent_path(super_page)
      base_path.join(parent_path, "#{slug}.md")
    else
      # Otherwise, save directly in the base directory
      base_path.join("#{slug}.md")
    end
  end

  def get_parent_path(page)
    path = []
    current_page = page

    # Recursively go through the hierarchy
    while current_page
      path.unshift(current_page.slug)
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
    Rails.logger.error(e.backtrace&.join("\n"))
  end

  def split_front_matter(text)
    before, sep, after = text.rpartition(/---\n+/)
    [before+sep, after]
  end

end
