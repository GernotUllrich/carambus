# Developer Documentation

Welcome to the Carambus developer documentation! Here you'll find all technical information for developing, extending, and contributing to the project.

## 🎯 For Developers

As a developer, you'll find here:
- 🚀 **Getting Started**: Set up development environment
- 🏗️ **Architecture**: System design and components
- 💾 **Database**: Schema, models, optimizations
- 🔌 **API**: REST API and WebSocket integration
- 🧪 **Testing**: Test framework and best practices
- 📦 **Deployment**: Deployment workflows and automation
- 🤝 **Contribution**: How to contribute to the project

## 🚀 Quick Start for New Developers

### 1. Set Up Development Environment (15-30 minutes)

**Prerequisites**:
- Ruby 3.2+
- Rails 7.2+
- PostgreSQL 14+
- Node.js 18+ & Yarn
- Git

**Setup steps**:
```bash
# Clone repository
git clone https://github.com/GernotUllrich/carambus.git
cd carambus

# Install dependencies
bundle install
yarn install

# Set up database
rails db:create
rails db:migrate
rails db:seed  # Test data

# Compile assets
yarn build
yarn build:css

# Start server
rails server
```

➡️ **[Detailed Getting Started Guide](getting-started.en.md)**

### 2. First Steps (30 minutes)

1. **Explore code structure**: `app/`, `config/`, `db/`
2. **Read developer guide**: Conventions and patterns
3. **Run tests**: `rails test` or `rspec`
4. **First change**: Implement small improvement
5. **Pull request**: Submit contribution

➡️ **[Developer Guide](developer-guide.en.md)**

## 📚 Main Topics

### 1. Getting Started

**Development environment**:
- Install Ruby, Rails, PostgreSQL
- Repository setup
- Configure credentials
- First steps

➡️ **[Getting Started for Developers](getting-started.en.md)**

### 2. Architecture & Design

**System overview**:
- MVC architecture (Rails)
- Hotwire/Turbo for SPA-like UX
- Stimulus for JavaScript sprinkles
- Action Cable for WebSockets
- Background jobs with Sidekiq/Solid Queue

**Design patterns**:
- Service Objects
- Form Objects
- Presenters/Decorators
- Repository Pattern (partial)

➡️ **[Developer Guide - Architecture](developer-guide.en.md#architecture)**

### 3. Database

**Schema & Models**:
- ER diagram
- Core models (Tournament, Game, Player, etc.)
- Associations
- Validations
- Scopes

**Optimizations**:
- Indexes
- Query optimization
- Avoid N+1 problem
- Caching strategies

➡️ **[Database Design](database-design.en.md)**  
➡️ **[ER Diagram](er-diagram.en.md)**

### 4. API & Integration

**REST API**:
- Endpoints
- Authentication (token-based)
- Versioning
- Rate limiting

**WebSocket (Action Cable)**:
- Channels
- Broadcasting
- Client integration
- Troubleshooting

➡️ **[API Reference](../reference/API.en.md)**

### 5. Frontend Development

**Technology stack**:
- **Hotwire**: Turbo Drive, Turbo Frames, Turbo Streams
- **Stimulus**: JavaScript controllers
- **Tailwind CSS**: Utility-first CSS
- **ViewComponent**: Component-based UI

**Asset pipeline**:
- esbuild for JavaScript
- Tailwind for CSS
- Build process

➡️ **[Developer Guide - Frontend](developer-guide.en.md#frontend)**

### 6. Testing

**Test framework**:
- Minitest (standard) or RSpec
- System tests (Capybara)
- Integration tests
- Unit tests

**Coverage**:
- SimpleCov for code coverage
- Goal: > 80% coverage

**Best practices**:
- TDD/BDD
- Fixtures vs. Factories
- Mocking & Stubbing

➡️ **[Testing & Debugging](rake-tasks-debugging.en.md)**

### 7. Deployment & DevOps

**Deployment strategies**:
- Capistrano (classic)
- Docker (containerized)
- Kamal (Rails 7.2+)

**CI/CD**:
- GitHub Actions
- Automated tests
- Deployment pipeline

**Scenario management**:
- Multi-environment setup
- Deployment scripts

➡️ **[Deployment Workflow](deployment-workflow.en.md)**  
➡️ **[Scenario Management](scenario-management.en.md)**

### 8. Performance & Optimization

**Monitoring**:
- Performance metrics
- N+1 query detection
- Memory profiling
- WebSocket health

**Optimizations**:
- Database optimization
- Caching (Fragment, Action, Russian Doll)
- Asset optimization
- Background jobs

➡️ **[Paper Trail Optimization](paper-trail-optimization.en.md)**

### 9. Data Management

**Migrations**:
- Schema changes
- Data migrations
- Rollback strategies

**Seeding**:
- Test data
- Production seeds

**Partitioning**:
- Database partitioning
- Sharding strategies

➡️ **[Data Management](data-management.en.md)**  
➡️ **[Database Partitioning](database-partitioning.en.md)**

## 🔧 Important Rake Tasks

```bash
# Database
rails db:create              # Create DB
rails db:migrate             # Run migrations
rails db:seed                # Load test data
rails db:reset               # Reset DB

# Assets
yarn build                   # Compile JavaScript
yarn build:css               # Compile CSS
rails assets:precompile      # Assets for production

# Tests
rails test                   # All tests
rails test:system            # System tests

# Scenarios (Multi-environment)
rake scenario:list           # Available scenarios
rake scenario:prepare[bcw]   # Prepare scenario
rake scenario:deploy[bcw]    # Deploy scenario

# Maintenance
rails log:clear              # Clear logs
rails tmp:clear              # Clear tmp files
rails restart                # Restart server

# Custom tasks
rails clubcloud:sync         # Sync ClubCloud data
rails tournament:reconstruct # Reconstruct schedule
```

➡️ **[Rake Tasks & Debugging](rake-tasks-debugging.en.md)**

## 🤝 Contribution Guidelines

### How can I contribute?

1. **Issues**: Report bugs, suggest features
2. **Discussions**: Ask questions, discuss ideas
3. **Pull Requests**: Code contributions
4. **Documentation**: Improve docs
5. **Testing**: Test edge cases

### Pull Request Process

1. **Fork** the repository
2. **Create branch**: `feature/description`
3. **Develop** with tests
4. **Commit** with meaningful messages
5. **Push** to your fork
6. **Create PR** with description
7. **Wait for review** and incorporate feedback

### Commit Messages

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: Add snooker scoreboard
fix: #123 - Correct calculation of average
docs: Update installation guide
refactor: Extract service object for game creation
test: Add integration tests for tournament creation
chore: Update dependencies
```

## 📚 Important Resources

### Internal Documentation

- **[Getting Started](getting-started.en.md)**: Development environment
- **[Developer Guide](developer-guide.en.md)**: Comprehensive developer handbook
- **[Database Design](database-design.en.md)**: Database schema
- **[ER Diagram](er-diagram.en.md)**: Visual database overview
- **[API Reference](../reference/API.en.md)**: API documentation
- **[Deployment Workflow](deployment-workflow.en.md)**: Deployment processes
- **[Scenario Management](scenario-management.en.md)**: Multi-environment
- **[Testing & Debugging](rake-tasks-debugging.en.md)**: Test strategies

### External Resources

**Rails**:
- [Rails Guides](https://guides.rubyonrails.org/)
- [Rails API Docs](https://api.rubyonrails.org/)
- [Rails Security Guide](https://guides.rubyonrails.org/security.html)

**Hotwire**:
- [Turbo Handbook](https://turbo.hotwired.dev/handbook/introduction)
- [Stimulus Handbook](https://stimulus.hotwired.dev/handbook/introduction)

**Testing**:
- [Minitest Docs](https://github.com/minitest/minitest)
- [Capybara](https://github.com/teamcapybara/capybara)

**PostgreSQL**:
- [PostgreSQL Docs](https://www.postgresql.org/docs/)

## 🔗 All Developer Documents

1. **[Getting Started](getting-started.en.md)** - Set up development environment
2. **[Developer Guide](developer-guide.en.md)** - Comprehensive developer handbook
3. **[Database Design](database-design.en.md)** - Database schema and models
4. **[ER Diagram](er-diagram.en.md)** - Visual database overview
5. **[API Reference](../reference/API.en.md)** - REST API documentation
6. **[Scenario Management](scenario-management.en.md)** - Multi-environment setup
7. **[Testing & Debugging](rake-tasks-debugging.en.md)** - Test strategies
8. **[Deployment Workflow](deployment-workflow.en.md)** - Deployment processes
9. **[Server Management Scripts](../administrators/server-scripts.en.md)** - Automation scripts
10. **[Raspberry Pi Scripts](../administrators/raspberry_pi_scripts.en.md)** - RasPi-specific tools
11. **[Data Management](data-management.en.md)** - Data management
12. **[Database Partitioning](database-partitioning.en.md)** - Partitioning strategies
13. **[Paper Trail Optimization](paper-trail-optimization.en.md)** - Audit log performance
14. **[Game Plan Reconstruction](game-plan-reconstruction.en.md)** - Schedule algorithms
15. **[Tournament Duplicates](tournament-duplicate-handling.en.md)** - Duplicate handling
16. **[Region Tagging](region-tagging-cleanup-summary.en.md)** - Geographic assignment

---

**Happy Coding! 💻**

*We welcome your contributions! Questions: gernot.ullrich@gmx.de or GitHub Discussions.*




