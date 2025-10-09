# Carambus - Billiards Management System

[![Build Status](https://github.com/GernotUllrich/carambus/workflows/Build%20and%20Deploy%20Documentation/badge.svg)](https://github.com/GernotUllrich/carambus/actions)
[![Documentation](https://img.shields.io/badge/docs-mkdocs-blue.svg)](https://gernotullrich.github.io/carambus/)

Carambus is a comprehensive billiards management system built with Ruby on Rails, designed to handle tournaments, leagues, clubs, and player management for billiards organizations.

## 🌟 Features

- **Tournament Management**: Complete tournament organization and management
- **League Management**: League match day scheduling and tracking
- **Club Management**: Club and location management with regional organization
- **Player Management**: Player profiles, rankings, and statistics
- **Scoreboard Integration**: Real-time scoreboard with Action Cable
- **Multi-Region Support**: Support for multiple regional organizations
- **Responsive Design**: Modern UI built with Tailwind CSS and Hotwire
- **API Support**: RESTful API for external integrations
- **Multi-language**: German and English support

## 🚀 Quick Start

### Prerequisites

- Ruby 3.2+
- Rails 7.2+
- PostgreSQL 12+
- Redis 6+
- Node.js 18+

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/GernotUllrich/carambus.git
   cd carambus
   ```

2. **Install dependencies**
   ```bash
   bundle install
   yarn install
   ```

3. **Setup database**
   ```bash
   # Option 1: Import existing database dump (recommended)
   # Ensure you have a database dump file (e.g., carambus_api_development_YYYYMMDD_HHMMSS.sql)
   # Create database and import dump:
   createdb carambus_development
   psql -d carambus_development -f /path/to/your/dump.sql
   
   # Note: Some errors during import are normal and can be ignored:
   # - "relation already exists" - table already exists
   # - "multiple primary keys not allowed" - primary key already defined
   # - "index already exists" - index already exists
   # - "constraint already exists" - constraint already defined
   
   # Option 2: Create fresh database (if no dump available)
   bin/rails db:create
   bin/rails db:migrate
   bin/rails db:seed
   ```

4. **Start the server**
   ```bash
   bin/rails server
   ```

5. **Visit the application**
   - Open `http://localhost:3000` in your browser
   - Default admin user: `admin@carambus.de` / `password`

## 📚 Documentation

- **User Guide**: [Tournament Management](https://gernotullrich.github.io/carambus/de/user_guide/tournament/)
- **Developer Guide**: [Getting Started](https://gernotullrich.github.io/carambus/de/developer_guide/getting_started/)
- **API Documentation**: [API Reference](https://gernotullrich.github.io/carambus/de/reference/api/)

## 🏗️ Architecture

- **Backend**: Ruby on Rails 7.2 with PostgreSQL
- **Frontend**: Hotwire (Turbo + Stimulus) with Tailwind CSS
- **Real-time**: Action Cable for live updates
- **Authentication**: Devise with Pundit authorization
- **Testing**: RSpec with Capybara
- **Deployment**: Capistrano with Docker support

## 🔧 Development

### Running Tests
```bash
bin/rails test                    # Run all tests
bin/rails test:system            # Run system tests
bin/rails test:controllers       # Run controller tests
bin/rails test:models            # Run model tests
```

### Code Quality
```bash
bundle exec standardrb --fix     # Fix code style issues
bundle exec brakeman             # Security analysis
bundle exec rubocop              # Code linting
```

### Database
```bash
bin/rails db:migrate             # Run migrations
bin/rails db:rollback            # Rollback last migration
bin/rails db:seed                # Seed database
```

## 🐳 Docker Support

### Development
```bash
docker-compose up -d
docker-compose exec web bin/rails console
```

### Production
```bash
docker build -t carambus .
docker run -p 3000:3000 carambus
```

## 📁 Project Structure

```
carambus/
├── app/                    # Rails application
│   ├── controllers/       # Controllers
│   ├── models/           # Models
│   ├── views/            # Views
│   ├── javascript/       # JavaScript components
│   └── assets/           # CSS, images, fonts
├── docs/                  # Documentation (MkDocs)
├── config/                # Configuration files
├── db/                    # Database migrations
├── lib/                   # Custom libraries
├── test/                  # Test files
└── docker/                # Docker configuration
```

## 🌍 Internationalization

Carambus supports multiple languages:
- **German (de)**: Primary language
- **English (en)**: Secondary language

Language switching is available in the footer of the application.

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### How to contribute

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Billards Association**: For domain expertise and requirements
- **Rails Community**: For the excellent framework and ecosystem
- **Open Source Contributors**: For various gems and tools used

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/GernotUllrich/carambus/issues)
- **Documentation**: [MkDocs](https://gernotullrich.github.io/carambus-docs/)
- **Email**: [Contact via GitHub](https://github.com/GernotUllrich)

## 🔄 Changelog

See [CHANGELOG.md](docs/changelog/CHANGELOG.md) for a list of changes and version history.

---

**Made with ❤️ for the billiards community** 