# Carambus Rails Application Dockerfile
# Optimiert für Ruby 3.2.1 und Produktionsumgebung

FROM ruby:3.2.1-slim AS base

# Setze Umgebungsvariablen
ENV DEBIAN_FRONTEND=noninteractive
ENV RAILS_ENV=production
ENV NODE_ENV=production

# Installiere System-Abhängigkeiten
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    libssl-dev \
    pkg-config \
    git \
    curl \
    wget \
    gnupg \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Installiere Node.js und Yarn
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && apt-get update \
    && apt-get install -y yarn \
    && rm -rf /var/lib/apt/lists/*

# Erstelle nicht-root User
RUN groupadd -r rails && useradd -r -g rails rails

# Erstelle Anwendungsverzeichnis, Log- und Temp-Verzeichnisse und setze Rechte
RUN mkdir -p /app/log /app/tmp/cache/assets \
    && touch /app/log/production.log \
    && chown -R rails:rails /app

# Setze Arbeitsverzeichnis
WORKDIR /app

# Wechsle zu nicht-root User (auskommentiert für tmp-Rechte)
# USER rails

# Kopiere Gemfiles zuerst (für besseres Caching)
COPY Gemfile Gemfile.lock .ruby-version ./

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

# Setze Rechte für Log- und Temp-Verzeichnisse als root
USER root
RUN mkdir -p /app/log /app/tmp/cache/assets \
    && touch /app/log/production.log \
    && chown -R rails:rails /app/log /app/tmp /app/public

# Precompile Assets (mit temporärem secret_key_base)
# Skip asset precompilation for now to avoid credentials issues
# RUN SECRET_KEY_BASE=dummy_key_for_build_only bundle exec rails assets:precompile

# Wechsle zu rails User für sicheren Betrieb
USER rails

# Exponiere Port
EXPOSE 3000

# Health Check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Starte Anwendung
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
