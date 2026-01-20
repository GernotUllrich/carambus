module StaticHelper
  # Get git changelog between current deployment and latest version
  # Returns array of commit messages in --oneline format
  # current_commit: the version currently deployed/running
  # latest_commit: the newer version from API server
  def git_changelog(current_commit, latest_commit)
    return [] if current_commit.blank? || latest_commit.blank?
    return [] if current_commit == latest_commit

    begin
      # Determine which commit is older/newer using git merge-base
      if Rails.env.development?
        # Check if current is ancestor of latest (normal case: current is older)
        is_behind = system("cd #{Rails.root} && git merge-base --is-ancestor #{current_commit} #{latest_commit} 2>/dev/null")
        
        if is_behind
          # Current is behind latest (normal case)
          from_commit = current_commit
          to_commit = latest_commit
        else
          # Current is ahead of latest (development is newer than API server)
          # Show commits in reverse: what's in current that's not in latest
          from_commit = latest_commit
          to_commit = current_commit
        end
        
        changelog = `cd #{Rails.root} && git log --oneline #{from_commit}..#{to_commit} 2>&1`
      else
        # In production, assume local is always behind (never develops on production)
        repo_path = get_repo_path
        return [] unless repo_path && File.directory?(repo_path)
        
        changelog = `git --git-dir=#{repo_path} log --oneline #{current_commit}..#{latest_commit} 2>&1`
      end

      Rails.logger.info "git_changelog: #{current_commit[0..7]}..#{latest_commit[0..7]}, exit_status=#{$?.success?}, output=#{changelog.inspect}"

      if $?.success? && changelog.present?
        result = changelog.split("\n").reject(&:blank?)
        Rails.logger.info "git_changelog: returning #{result.length} commits"
        result
      else
        Rails.logger.info "git_changelog: failed or empty (exit: #{$?.success?})"
        []
      end
    rescue => e
      Rails.logger.error "Failed to get git changelog: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
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
