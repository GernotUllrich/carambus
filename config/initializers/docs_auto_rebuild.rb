# frozen_string_literal: true

# Development-only listener that rebuilds public/docs/ whenever a markdown file
# in docs/ changes. Closes the manual-rebuild gap that Quick 260415-26d
# (overcommit-hook approach, rolled back) tried to address.
#
# Disabled in test / production. Opt-out in development:
#   DOCS_AUTO_REBUILD=0 bin/rails server

return unless Rails.env.development?
return if ENV["DOCS_AUTO_REBUILD"] == "0"

require "listen"

docs_dir = Rails.root.join("docs")
return unless docs_dir.exist?

Rails.application.config.after_initialize do
  listener = Listen.to(docs_dir.to_s, only: /\.md\z/, wait_for_delay: 2.0) do |modified, added, removed|
    changed = modified + added + removed
    sample = changed.first(3).map { |p| Pathname.new(p).relative_path_from(Rails.root).to_s }
    extra = changed.size > 3 ? " (+#{changed.size - 3} more)" : ""
    Rails.logger.info "[docs-rebuild] triggered by: #{sample.join(', ')}#{extra}"

    Thread.new do
      Dir.chdir(Rails.root) do
        output = `bin/rails mkdocs:build 2>&1`
        if $?.success?
          last = output.lines.reverse.find { |l| !l.strip.empty? }&.strip
          Rails.logger.info "[docs-rebuild] OK — #{last}"
        else
          Rails.logger.error "[docs-rebuild] FAILED:\n#{output}"
        end
      end
    end
  end
  listener.start
  Rails.logger.info "[docs-rebuild] listener active on #{docs_dir} (set DOCS_AUTO_REBUILD=0 to disable)"
end
