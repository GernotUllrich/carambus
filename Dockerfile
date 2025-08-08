# Carambus Rails Application Dockerfile
# Optimiert für Ruby 3.2.1 und Produktionsumgebung

FROM ruby:3.2.1-slim

ENV RAILS_ENV=production
ENV RAILS_SERVE_STATIC_FILES=true
ENV RAILS_LOG_TO_STDOUT=true

# Install system dependencies
RUN apt-get update -qq && apt-get install -y \
    build-essential \
    libpq-dev \
    cron \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 18.x
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs

# Install yarn globally
RUN npm install -g yarn

# Create rails user and group
RUN groupadd -r rails && useradd -r -g rails rails

# Set working directory
WORKDIR /app

# Copy Gemfile and install gems
COPY Gemfile Gemfile.lock .ruby-version ./
RUN bundle install --jobs 4 --retry 3

# Copy package.json and install Node.js dependencies (if they exist)
COPY package.json yarn.lock ./
RUN if [ -f "package.json" ]; then yarn install; else echo "No package.json found, skipping yarn install"; fi

# Copy application code
COPY . .

# Create necessary directories and set ownership
RUN mkdir -p log storage tmp/cache/assets app/assets/builds && \
    chown -R rails:rails log storage tmp app/assets/builds

# Build assets using the correct process (if package.json exists)
RUN if [ -f "package.json" ]; then yarn build:css && yarn build; else echo "No package.json found, skipping asset build"; fi

# Create startup script for cron service
RUN echo '#!/bin/bash\ncron -f' > /usr/local/bin/cron-start.sh && \
    chmod +x /usr/local/bin/cron-start.sh

# Switch to rails user
USER rails

# Expose port
EXPOSE 3000

# Default command (can be overridden)
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
