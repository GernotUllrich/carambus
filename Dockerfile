# Carambus Rails Application Dockerfile
# Optimiert für Raspberry Pi ARM64 und Produktionsumgebung

# Multi-stage build für optimierte Größe
FROM debian:bookworm-slim AS base

# Setze Umgebungsvariablen
ENV DEBIAN_FRONTEND=noninteractive
ENV RAILS_ENV=production
ENV NODE_ENV=production

# Installiere System-Abhängigkeiten
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    gnupg \
    ca-certificates \
    build-essential \
    libpq-dev \
    libssl-dev \
    pkg-config \
    git \
    && rm -rf /var/lib/apt/lists/*

# Installiere Node.js und Yarn
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && apt-get update \
    && apt-get install -y yarn \
    && rm -rf /var/lib/apt/lists/*

# Installiere rbenv und Ruby 3.2.1
RUN git clone https://github.com/rbenv/rbenv.git /usr/local/rbenv \
    && echo 'export PATH="/usr/local/rbenv/bin:$PATH"' >> /etc/bash.bashrc \
    && echo 'eval "$(rbenv init -)"' >> /etc/bash.bashrc \
    && git clone https://github.com/rbenv/ruby-build.git /usr/local/rbenv/plugins/ruby-build \
    && export PATH="/usr/local/rbenv/bin:$PATH" \
    && eval "$(rbenv init -)" \
    && rbenv install 3.2.1 \
    && rbenv global 3.2.1 \
    && echo 'gem: --no-document' >> ~/.gemrc

# Setze Ruby-Pfad
ENV PATH="/usr/local/rbenv/shims:/usr/local/rbenv/bin:$PATH"
ENV RBENV_ROOT="/usr/local/rbenv"

# Installiere Bundler
RUN gem install bundler

# Erstelle Anwendungsverzeichnis
WORKDIR /app

# Kopiere Gemfiles zuerst (für besseres Caching)
COPY Gemfile Gemfile.lock ./

# Installiere Ruby-Gems
RUN bundle config set --local deployment 'true' \
    && bundle config set --local path 'vendor/bundle' \
    && bundle install --jobs 4 --retry 3

# Kopiere package.json und yarn.lock
COPY package.json yarn.lock ./

# Installiere Node.js-Abhängigkeiten
RUN yarn install --frozen-lockfile

# Kopiere Anwendungscode
COPY . .

# Precompile Assets
RUN bundle exec rails assets:precompile

# Erstelle nicht-root User
RUN groupadd -r rails && useradd -r -g rails rails \
    && chown -R rails:rails /app

# Wechsle zu nicht-root User
USER rails

# Exponiere Port
EXPOSE 3000

# Health Check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Starte Anwendung
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
