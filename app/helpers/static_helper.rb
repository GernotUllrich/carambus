module StaticHelper
  # Get git changelog between current deployment and latest version
  # Returns array of commit messages in --oneline format
  def git_changelog(current_commit, latest_commit)
    return [] if current_commit.blank? || latest_commit.blank?
    return [] if current_commit == latest_commit

    begin
      if Rails.env.development?
        # In development, use regular git in Rails.root
        changelog = `cd #{Rails.root} && git log --oneline #{current_commit}..#{latest_commit} 2>/dev/null`
      else
        # In production, use bare repository
        repo_path = get_repo_path
        return [] unless repo_path && File.directory?(repo_path)
        
        changelog = `git --git-dir=#{repo_path} log --oneline #{current_commit}..#{latest_commit} 2>/dev/null`
      end

      if $?.success?
        changelog.split("\n").reject(&:blank?)
      else
        []
      end
    rescue => e
      Rails.logger.error "Failed to get git changelog: #{e.message}"
      []
    end
  end

  # Get the path to the bare git repository
  def get_repo_path
    return nil unless Rails.env.production?

    # In production, the bare repo is typically at: /var/www/scenario_name/repo
    # Rails.root is something like: /var/www/scenario_name/releases/20260116122318
    # or /var/www/scenario_name/current (symlink to a release)

    rails_root = Rails.root.to_s

    # Extract deployment path (everything before /releases or /current)
    if rails_root.include?('/releases/')
      deploy_path = rails_root.split('/releases/').first
    elsif rails_root.include?('/current')
      deploy_path = rails_root.split('/current').first
    else
      return nil
    end

    repo_path = File.join(deploy_path, 'repo')
    File.directory?(repo_path) ? repo_path : nil
  end
end
