# Carambus Documentation

Welcome to the Carambus documentation! This directory contains comprehensive documentation for the Carambus billiards tournament management system.

## 🎯 Quick Start by Target Audience

### 🎯 For Decision Makers
Evaluating Carambus for your club or federation?
**Start**: [Decision Makers Overview](decision-makers/index.md)

### 🎮 For Players
Using Carambus as tournament participant?
**Start**: [Players Overview](players/index.md)

### 🏆 For Tournament Managers
Organizing tournaments and league match days?
**Start**: [Managers Overview](managers/index.md)

### 🖥️ For System Administrators
Installing and operating Carambus?
**Start**: [Administrators Overview](administrators/index.md)

### 💻 For Developers
Developing with or on Carambus?
**Start**: [Developers Overview](developers/index.md)

## 📚 Documentation Structure

The documentation is now clearly structured by target audience:

```
docs/
├── index.md                        # Main landing page
├── README.md                       # This file
│
├── decision-makers/                # For Decision Makers
│   ├── index.md                   # Overview
│   ├── executive-summary.md       # Executive Summary
│   ├── features-overview.md       # Features Overview
│   └── deployment-options.md      # Deployment Options
│
├── players/                        # For Players
│   ├── index.md                   # Overview
│   ├── scoreboard-guide.md        # Scoreboard Operation
│   ├── tournament-participation.md # Tournament Participation
│   └── ai-search.md              # AI Search
│
├── managers/                       # For Tournament Managers
│   ├── index.md                   # Overview
│   ├── tournament-management.md   # Tournament Management
│   ├── league-management.md       # League Management
│   ├── single-tournament.md       # Single Tournament
│   ├── table-reservation.md       # Table Reservation
│   ├── admin_roles.md            # Admin Roles
│   ├── clubcloud_integration.md   # ClubCloud
│   └── search-filters.md         # Search & Filters
│
├── administrators/                 # For Admins
│   ├── index.md                   # Overview
│   ├── installation_overview.md   # Installation
│   ├── quickstart_raspberry_pi.md # Raspberry Pi
│   ├── raspberry-pi-client.md     # RasPi Client
│   ├── scoreboard_autostart_setup.md # Autostart
│   ├── server-architecture.md     # Architecture
│   ├── email_configuration.md     # E-Mail
│   └── database-setup.md         # Database
│
├── developers/                     # For Developers
│   ├── index.md                   # Overview
│   ├── getting-started.md         # Getting Started
│   ├── developer-guide.md         # Developer Guide
│   ├── database_design.md         # DB Design
│   ├── er_diagram.md             # ER Diagram
│   ├── scenario_management.md     # Scenarios
│   ├── rake-tasks-debugging.md    # Testing
│   ├── deployment_workflow.md     # Deployment
│   ├── data_management.md         # Data Management
│   ├── database-partitioning.md   # DB Partitioning
│   └── ... (more technical docs)
│
└── reference/                      # Reference
    ├── API.md                     # API Docs
    ├── glossary.md                # Glossary
    ├── terms.md                   # Terms
    └── privacy.md                 # Privacy
```

## 🔍 Most Important Documents

### Getting Started
- **[Main Index](index.md)**: Overview of all target audiences
- **[About the Project](about.md)**: Background and history

### For Decision Makers
- **[Executive Summary](decision-makers/executive-summary.md)**: Compact overview
- **[Features Overview](decision-makers/features-overview.md)**: All features
- **[Deployment Options](decision-makers/deployment-options.md)**: Operating models compared

### For Users
- **[Scoreboard Guide](players/scoreboard-guide.md)**: Operation at the table
- **[Tournament Management](managers/tournament-management.md)**: Organize tournaments
- **[League Management](managers/league-management.md)**: Conduct league match days

### For Administrators
- **[Installation](administrators/installation-overview.md)**: All installation options
- **[Raspberry Pi Setup](administrators/raspberry-pi-quickstart.md)**: RasPi in 30 minutes
- **[Server Architecture](administrators/server-architecture.md)**: System overview

### For Developers
- **[Getting Started](developers/getting-started.md)**: Development environment
- **[Developer Guide](developers/developer-guide.md)**: Comprehensive handbook
- **[Database Design](developers/database-design.md)**: Schema and models
- **[API Reference](reference/api.md)**: REST API documentation

## 🌍 Languages

The documentation is available in:
- 🇩🇪 **German** (Primary language)
- 🇺🇸 **English** (Translations for most important documents)

Use the language selector in the mkdocs navigation to switch languages.

## 🔄 Documentation Maintenance

### Contributing to Documentation
- Follow the [Contribution Guide](developers/developer-guide.md)
- Update relevant documentation when adding features
- Add code examples for new APIs
- Maintain consistency across all documents

### Documentation Standards
- Use clear, concise language
- Include practical examples
- Provide German and English versions where appropriate
- Keep documentation up-to-date with code changes

### Version Control
- Documentation is versioned with the codebase
- Major changes require documentation updates
- API changes must be documented before release

## 📞 Getting Help

### Search Documentation
- Use the **search function** (top right in mkdocs)
- Use the **table of contents** on each page
- Check the **[Glossary](reference/glossary.md)** for technical terms

### Support Channels
- **GitHub Issues**: [https://github.com/GernotUllrich/carambus/issues](https://github.com/GernotUllrich/carambus/issues)
- **Email**: gernot.ullrich@gmx.de
- **Project**: [Billardclub Wedel 61 e.V.](http://www.billardclub-wedel.de/)

### Missing Documentation?
If you find missing documentation or errors:
1. Create a GitHub issue
2. Or send an email to gernot.ullrich@gmx.de
3. Pull requests are welcome!

## 🚀 Quick Links

### For New Users
- [What is Carambus?](about.md)
- [Which target audience am I?](index.md)
- [How do I install Carambus?](administrators/installation-overview.md)

### For Experienced Users
- [API Documentation](reference/api.md)
- [Database Schema](developers/database-design.md)
- [Deployment Workflow](developers/deployment-workflow.md)

---

**Version**: 2.0 (Reorganized December 2024)  
**Status**: Complete  
**Languages**: German, English

*Welcome to the newly structured Carambus documentation! Choose your target audience above for the best entry point.*
