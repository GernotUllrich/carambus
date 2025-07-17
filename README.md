# Carambus - Billiards Tournament Management System

[![Ruby](https://img.shields.io/badge/Ruby-3.2+-red.svg)](https://ruby-lang.org)
[![Rails](https://img.shields.io/badge/Rails-7.2-blue.svg)](https://rubyonrails.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-11+-blue.svg)](https://postgresql.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Carambus is a comprehensive billiards tournament management system that provides complete automation of billiards operations from tournament planning to data collection and result transmission. Built with Ruby on Rails and modern web technologies, it offers real-time scoreboards, league management, and seamless integration with external billiards databases.

## 🎯 Features

### Tournament Management
- **Complete Tournament Lifecycle**: From creation to final results
- **Multiple Game Types**: Support for 3-cushion, 1-cushion, and other disciplines
- **Flexible Formats**: Single elimination, round-robin, and custom formats
- **Real-time Monitoring**: Live game tracking and scoreboard displays

### League Management
- **Team-based Organization**: Manage league teams and player rosters
- **Season Management**: Organize tournaments into seasons
- **Match Scheduling**: Automated and manual match scheduling
- **Result Tracking**: Comprehensive statistics and rankings

### Real-time Features
- **Live Scoreboards**: WebSocket-powered real-time displays
- **Table Monitors**: Individual table monitoring and control
- **Instant Updates**: Real-time data synchronization across devices
- **Responsive Design**: Works on desktop, tablet, and mobile devices

### Data Integration
- **External Database Sync**: Integration with BA (Billiards Association) and CC (Competition Center)
- **Data Protection**: Local data protection with external synchronization
- **Region Management**: Intelligent region-based data organization
- **Multi-language Support**: German and English interfaces

## 🚀 Quick Start

### Prerequisites
- Ruby 3.2 or higher
- PostgreSQL 11 or higher
- Redis 5 or higher
- Node.js 14 or higher

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/carambus.git
   cd carambus
   ```

2. **Install dependencies**
   ```bash
   bundle install
   yarn install
   ```

3. **Database setup**
   ```bash
   cp config/database.yml.example config/database.yml
   # Edit database.yml with your PostgreSQL credentials
   
   rails db:create
   rails db:migrate
   rails db:seed
   ```

4. **Environment configuration**
   ```bash
   cp config/application.yml.example config/application.yml
   # Edit application.yml with your configuration
   ```

5. **Start the application**
   ```bash
   rails server
   ```

6. **Visit the application**
   Open your browser and navigate to `http://localhost:3000`

## 📚 Documentation

- **[Developer Guide](docs/DEVELOPER_GUIDE.md)**: Comprehensive guide for developers
- **[Database Design](docs/database_design.md)**: Detailed database schema and relationships
- **[Scoreboard Setup](docs/scoreboard_autostart_setup.md)**: Scoreboard configuration guide
- **[Tournament Management](docs/tournament.md)**: Tournament workflow documentation
- **[Deployment Guide](doc/doc/Runbook)**: Production deployment instructions

## 🏗️ Architecture

### Technology Stack
- **Backend**: Ruby on Rails 7.2
- **Database**: PostgreSQL with advanced data modeling
- **Frontend**: Hotwire (Turbo + Stimulus) + Stimulus Reflex
- **Real-time**: Action Cable with Redis
- **Authentication**: Devise with role-based authorization
- **Admin Interface**: Administrate for easy administration
- **Deployment**: Capistrano + Puma + Nginx

### Key Components
- **Models**: Rich ActiveRecord models with concerns for shared functionality
- **Controllers**: RESTful controllers with JSON API support
- **Views**: ERB templates with responsive design
- **Channels**: Action Cable channels for real-time features
- **Jobs**: Background job processing
- **Services**: Business logic encapsulation

## 🎮 Usage Examples

### Creating a Tournament
```ruby
# Create a new tournament
tournament = Tournament.create!(
  name: "Regional Championship 2024",
  discipline: Discipline.find_by(name: "3-Cushion"),
  start_date: Date.today + 1.week,
  location: Location.find_by(name: "Billard Club Wedel")
)

# Add participants
players.each do |player|
  tournament.seedings.create!(player: player)
end

# Generate game plan
tournament.generate_game_plan
```

### Real-time Scoreboard
```javascript
// Connect to scoreboard channel
import { createConsumer } from "@rails/actioncable"

const consumer = createConsumer()
const subscription = consumer.subscriptions.create("TableMonitorChannel", {
  received(data) {
    // Update scoreboard display
    updateScoreboard(data)
  }
})
```

## 🤝 Contributing

We welcome contributions from the community! Please see our [Contributing Guide](docs/DEVELOPER_GUIDE.md#contributing) for details.

### Development Setup
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

### Code Quality
- Follow Ruby style guidelines (Standard Ruby)
- Write comprehensive tests
- Update documentation for new features
- Use meaningful commit messages

## 📋 Requirements

### System Requirements
- **Development**: Any modern OS with Ruby 3.2+
- **Production**: Raspberry Pi 4 (4GB RAM) or equivalent
- **Database**: PostgreSQL 11+ with proper indexing
- **Cache**: Redis 5+ for session storage and Action Cable

### Browser Support
- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+

## 🚀 Deployment

### Production Deployment
Carambus is designed for deployment on Raspberry Pi or similar hardware:

```bash
# Server setup (see Runbook for details)
# Application deployment via Capistrano
cap production deploy

# Service management
sudo systemctl start carambus
sudo systemctl enable carambus
```

### Docker Support
```bash
# Build and run with Docker
docker-compose up -d

# Or build custom image
docker build -t carambus .
docker run -p 3000:3000 carambus
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Dr. Gernot Ullrich**: Original developer and project founder
- **Billardclub Wedel 61 e.V.**: The billiards club that inspired this project
- **Ruby on Rails Community**: For the excellent framework and ecosystem
- **Hotwire Team**: For the modern real-time web technologies

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/your-username/carambus/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-username/carambus/discussions)
- **Documentation**: [Project Wiki](https://github.com/your-username/carambus/wiki)

## 🔗 Links

- **Website**: [carambus.de](https://carambus.de)
- **Documentation**: [docs/](docs/)
- **API Documentation**: [docs/api.md](docs/api.md)
- **Changelog**: [CHANGELOG.md](CHANGELOG.md)

---

**Carambus** - *Compromise-free automation of billiards operations*

*Built with ❤️ for the billiards community* 