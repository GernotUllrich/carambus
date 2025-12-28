# Features Overview: Carambus

A comprehensive overview of all features of the Carambus billiards tournament management system.

## 🎯 Tournament Management

### Automatic Match Schedule Creation
- **Multiple Tournament Modes**:
  - Round Robin (Everyone vs Everyone)
  - Knockout System (Single/Double Elimination)
  - Swiss System
  - Group Phases with Knockout Round
- **Flexible Configuration**:
  - Adjustable number of rounds
  - Automatic table rotation
  - Break planning
  - Configurable match times
- **Intelligent Match Pairings**: Automatic optimization based on table availability and player preferences

**Benefit**: Saves 80-90% of time compared to manual schedule creation

### Tournament Formats

#### Carom Tournaments
- **Disciplines**: Straight Rail, Cadre 47/1, Cadre 47/2, Cadre 71/2, One-Cushion, Three-Cushion
- **Flexible Distances**: Freely configurable point targets
- **Innings Tracking**: Automatic calculation of average (GD)
- **High Run**: Recording and display of best run

#### Pool Tournaments
- **Disciplines**: 8-Ball, 9-Ball, 10-Ball, Straight Pool
- **Best-of Modes**: e.g., Best-of-5, Best-of-7
- **Race-to Modes**: e.g., Race-to-9
- **Alternating Break**: Automatic management
- **Ball-in-hand**: Foul system support

#### Snooker Tournaments
- **Frames System**: Best-of-Frames mode
- **Frame Scores**: Detailed point recording per frame
- **Re-spotted Black**: Support for tied frames
- **Century Breaks**: Highlighting of 100+ point breaks

### Live Result Recording
- **Multiple Input Methods**:
  - Desktop interface for tournament managers
  - Tablet interface for referees
  - Touch scoreboard directly at the table
- **Real-time Synchronization**: All devices update automatically
- **Offline Capability**: Local recording during connection issues
- **Error Correction**: Easy reset for input errors

## 📊 League & Championship Management

### League Match Days
- **Season Management**: Multiple seasons in parallel
- **Group Management**: Automatic table creation
- **Match Day Planning**: Home/away match logic
- **Team Competitions**: Team lineups and team rankings

### Rankings
- **Automatic Calculation**: Points, quotients, head-to-head
- **Historical Data**: Season-spanning statistics
- **Export Functions**: PDF, CSV for publication

### ClubCloud Integration
- **Automatic Import**: Tournaments and player data from DBU ClubCloud
- **Bidirectional Synchronization**: Push results back
- **License Validation**: Automatic verification of playing eligibility
- **Mapping Management**: Assignment of local players to ClubCloud IDs

**Benefit**: Eliminates manual data entry and transfer errors

## 🖥️ Display Solutions

### Live Scoreboards

#### Carom Scoreboard
- **Large, Readable Display**:
  - Player names
  - Current score
  - Innings and average
  - High run
  - Remaining points (distance minus achieved points)
- **Animations**: Smooth transitions on score changes
- **Timeout Display**: Countdown for thinking time
- **Foul Display**: Clear marking of fouls

#### Pool Scoreboard
- **Game Score**: Total games won
- **Rack Display**: Current game visualized
- **Break Indicator**: Who has the break
- **Ball Tracking**: Which balls were pocketed
- **Foul System**: Automatic ball-in-hand

#### Snooker Scoreboard
- **Frame Overview**: Total frames and current frame
- **Break Counter**: Running series in current break
- **Balls Remaining**: Remaining points on the table
- **Colors Display**: Which colors still in play
- **Re-spotted Black**: Special display for decider

### Tournament Monitor
- **Current Matches**: All running matches at a glance
- **Table Standings**: Live rankings
- **Next Round**: Preview of upcoming pairings
- **Results**: Completed matches
- **Responsive Design**: Optimized for TV, projector, tablet

### Party Monitor (League Match Days)
- **Group Overview**: All tables and pairings
- **Overall Table**: Team standings
- **Statistics**: Team performances at a glance
- **Countdown**: Time until match day end

**Benefit**: Professional presentation, increased spectator appeal

## 🔍 Search & Navigation

### AI-Powered Search
- **Natural Language Queries**:
  - "Show me all matches by Miller last month"
  - "Who won the tournament in 2023?"
  - "Highest average in the season"
- **Intelligent Filters**: Automatic recognition of search intent
- **Quick Answers**: Direct result display without navigation

### Classic Search
- **Full-Text Search**: Across all players, tournaments, clubs
- **Advanced Filters**:
  - Time period
  - Discipline
  - Venue
  - Tournament type
- **Saved Searches**: Save frequently used filters

## 📅 Table Reservation

### Online Booking System
- **Calendar View**: Clear display of available times
- **Member Login**: Personalized bookings
- **Email Confirmation**: Automatic booking confirmation
- **Cancellation**: Self-service cancellation by members
- **Recurring Bookings**: For training times

### Heating Control
- **Automatic Preheating**: Warm up tables before booking start
- **Energy Optimization**: Heating only during actual use
- **Manual Control**: Override for special cases
- **Integration**: Direct connection to existing heating control

**Benefit**: Reduces energy costs by up to 40%, increases comfort

## 👥 User Management & Permissions

### Role Concept
- **Super Admin**: Full system control
- **Club Admin**: Club management
- **Tournament Manager**: Tournament administration
- **Referee**: Result recording
- **Member**: Player with access to own data
- **Guest**: Read-only access

### Fine-Grained Permissions
- **Tournament-Based**: Assign permissions per tournament
- **Club-Based**: Access to club data
- **Function-Based**: Specific rights (e.g., result recording only)

### Self-Service Portal
- **Player Profile**: Maintain own data
- **Match History**: View personal statistics
- **Registration**: Sign up for tournaments
- **Notifications**: Email for important events

## 📈 Statistics & Analytics

### Player Statistics
- **Overall Record**: Wins/losses across all tournaments
- **Averages**: GD (General Average) over time
- **Best Performances**: High runs, best GDs
- **Development Curve**: Graphical display of performance
- **Head-to-Head**: Direct comparisons with other players

### Tournament Statistics
- **Participant Overview**: Demographic data
- **Performance Distribution**: Averages, high runs
- **Match Duration Analysis**: Average match duration
- **Table Utilization**: Efficiency of match planning

### Club Statistics
- **Member Activity**: Tournament participations per member
- **Utilization**: Table occupancy over time
- **League Performance**: Club performance in leagues
- **Revenue**: Bookings and income (for guest play operations)

### Export & Reports
- **PDF Generation**: Professional tournament reports
- **CSV Export**: For external analysis (Excel)
- **API Access**: Programmatic access to statistics
- **Automatic Reports**: Periodic email reports

## 🔧 Administration & Configuration

### System Settings
- **Basic Data**: Club name, logo, contact details
- **Email Configuration**: SMTP server, sender
- **Language & Localization**: German/English, timezone
- **Backup Settings**: Automatic backups
- **Maintenance Mode**: Temporarily disable system

### Tournament Templates
- **Predefined Formats**: Save frequently used tournament setups
- **Reusable**: Quick tournament creation
- **Customizable**: Edit and extend templates

### Data Import/Export
- **CSV Import**: Player data, tournament results
- **Bulk Operations**: Change multiple records simultaneously
- **Backup/Restore**: Complete database backup

### History Tracking (Paper Trail)
- **Complete Change History**: Who changed what when
- **Rollback Function**: Undo accidental changes
- **Audit Security**: Traceability for federation tournaments

## 🔐 Security & Privacy

### Authentication
- **Secure Password Storage**: bcrypt hashing
- **Session Management**: Automatic timeout
- **Two-Factor Authentication**: Optionally activatable
- **OAuth Integration**: Login via Google/Facebook (optional)

### Data Protection (GDPR)
- **Data Minimization**: Only necessary data is collected
- **Consent**: Explicit agreement during registration
- **Deletion Function**: Player data can be deleted
- **Data Export**: Players can export their data
- **Anonymization**: Anonymize old tournaments

### Encryption
- **HTTPS/TLS**: All transmissions encrypted
- **Database Encryption**: Sensitive data encrypted
- **Credentials Management**: Secure storage of API keys

## 📱 Mobile & Responsive

### Responsive Design
- **Desktop**: Full functionality
- **Tablet**: Optimized for tournament management
- **Smartphone**: Read access, result queries
- **Touch Optimization**: Large buttons, swipe gestures

### Progressive Web App (PWA)
- **Offline Mode**: Basic functions even without internet
- **Home Screen Icon**: Installable like native app
- **Push Notifications**: For important events
- **App-Like Feel**: Fast and responsive

## 🚀 Performance & Scalability

### Optimized Performance
- **Fast Load Times**: < 1 second for main pages
- **Real-Time Updates**: WebSocket updates in < 100ms
- **Caching**: Intelligent caching strategies
- **Lazy Loading**: Load images and data on-demand

### Scalability
- **Small Clubs**: 50 members, 10 parallel tournaments
- **Large Clubs**: 500+ members, 50+ parallel tournaments
- **Federations**: 5,000+ players, 100+ clubs
- **Load Tests**: Successfully tested with 1,000+ concurrent users

## 🔌 Integration & Extensibility

### API
- **REST API**: Standardized JSON API
- **Documented**: Complete API documentation
- **Authentication**: Token-based
- **Rate Limiting**: Protection against abuse

### Webhooks
- **Event Notifications**: On tournament events
- **External Integration**: Connection to other systems
- **Configurable**: Which events trigger webhooks

### Extensions
- **Plugin System**: Add custom modules
- **Custom Themes**: Implement own design
- **Discipline Extensions**: Add new game variants

## 🎓 Training & Documentation

### Comprehensive Documentation
- **User Manuals**: Step-by-step guides
- **Video Tutorials**: Visual introductions
- **FAQ**: Frequently asked questions
- **Glossary**: Explanation of all technical terms

### Multilingual
- **German**: Complete
- **English**: Complete
- **Extensible**: Additional languages easily addable

### Support Channels
- **Documentation**: Available online
- **GitHub Issues**: Community support
- **Email Support**: For registered users
- **Commercial Support**: Available upon request

## 💡 Innovative Features

### Automatic Match Recognition
- **Camera Integration**: Automatic point counting via computer vision (in development)
- **Score Import**: Import from electronic counters

### AI Functions
- **Player Recommendations**: Suggestions for balanced pairings
- **Performance Predictions**: Expected tournament performance
- **Anomaly Detection**: Mark unusual results

### Social Features
- **Player Profiles**: Public profiles with statistics
- **Comments**: Comment on tournament matches
- **Photo Upload**: Share tournament photos
- **Social Media**: Share results on Facebook/Twitter

---

## Roadmap: Planned Features

### Short Term (3-6 months)
- Live streaming integration
- Mobile app (iOS/Android)
- Extended statistics dashboards
- Automatic tournament highlights

### Medium Term (6-12 months)
- Computer vision score tracking
- Extended AI functions
- Multi-tenant SaaS platform
- Payment integration (entry fees)

### Long Term (12+ months)
- International tournament aggregation
- Player ranking system
- Live commentator function
- VR/AR visualizations

---

*The feature list is continuously expanded. Current information can be found in the [GitHub Repository](https://github.com/GernotUllrich/carambus).*





