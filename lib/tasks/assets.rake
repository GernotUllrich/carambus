namespace :assets do
  desc "Build JavaScript and CSS with Yarn"
  task :yarn_build do
    puts "Building JavaScript and CSS with Yarn..."
    system "yarn build:css"
    system "yarn build"
  end

  # Hook into the precompile task
  Rake::Task["assets:precompile"].enhance(["assets:yarn_build"])
end 