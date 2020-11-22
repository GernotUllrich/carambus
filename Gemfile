source 'https://rubygems.org'


# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
#gem 'rails', '4.2.8'
gem 'rails', '~> 6'
# Use sqlite3 as the database for Active Record
#gem 'sqlite3'
gem 'pg', '0.19.0'
# Transpile app-like JavaScript. Read more: https://github.com/rails/webpacker
gem 'webpacker', '>= 4.0.x'
gem "slim-rails"


gem 'devise'

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.7'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use Active Model has_secure_password
# gem 'bcrypt', '~> 3.1.7'
gem 'bcrypt'

gem 'jwt'

# Use Unicorn as the app server
# gem 'unicorn'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development
#
gem "andand"
gem "kaminari"
gem 'stalker'
gem 'daemons'
#gem 'therubyracer'
gem 'acts_as_list'
gem 'paper_trail'

gem 'thor'
gem 'aasm'
gem 'i15r', '~> 0.5.1'
gem 'i18n'

group :production do
  # Use unicorn as the app server
  gem 'unicorn'
  gem 'unicorn-rails'
end
# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.4.2', require: false

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
end

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 3.3.0'
  gem 'listen', '>= 3.0.5', '< 3.2'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'capistrano'
  gem 'capistrano-unicorn-nginx'
  gem 'capistrano-rails'
  gem 'capistrano-bundler'
  gem 'capistrano-rbenv', github: "capistrano/rbenv"
  gem 'capistrano-secrets-yml'
end

