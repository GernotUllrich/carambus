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
    gosu \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 18.x
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs

# Install yarn globally
RUN npm install -g yarn

# Create rails user and group
RUN groupadd -g 33 www-data || true && useradd -u 33 -g 33 www-data || true

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
RUN mkdir -p log storage app/assets/builds && \
    mkdir -p tmp/cache/assets tmp/cache tmp/pids tmp/sockets tmp/sessions && \
    mkdir -p tmp/cache/bootsnap tmp/cache/bootsnap-compile-cache tmp/cache/bootsnap-load-path-cache && \
    chown -R www-data:www-data log storage tmp app/assets/builds && \
    chmod -R 755 tmp && \
    chmod -R 777 tmp/cache tmp/pids tmp/sockets tmp/sessions

# Build assets using the correct process (if package.json exists)
RUN if [ -f "package.json" ]; then yarn build:css && yarn build; else echo "No package.json found, skipping asset build"; fi

# Create startup script for cron service (as root)
RUN echo '#!/bin/bash\ncron -f' > /usr/local/bin/cron-start.sh && \
    chmod +x /usr/local/bin/cron-start.sh

# Create entrypoint script that ensures tmp directories exist before switching user
RUN echo '#!/bin/bash\n# This runs as root first\nmkdir -p /app/tmp/cache /app/tmp/pids /app/tmp/sockets /app/tmp/sessions\nmkdir -p /app/tmp/cache/bootsnap /app/tmp/cache/bootsnap-compile-cache /app/tmp/cache/bootsnap-load-path-cache\nchown -R www-data:www-data /app/tmp\nchmod -R 777 /app/tmp\n# Now switch to www-data user and execute command\nexec gosu www-data "$@"' > /usr/local/bin/docker-entrypoint.sh && \
    chmod +x /usr/local/bin/docker-entrypoint.sh

# Expose port
EXPOSE 3000

# Don't switch user here - entrypoint script will handle it

# Default command (can be overridden)
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["bundle", "exec", "puma", "-p", "3000", "-e", "production"]
