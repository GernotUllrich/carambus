# Carambus TODO

## 🔒 **Security & Access Control**

### **Scoreboard Access Restriction**
- [ ] **Disallow scoreboard access on API server**
  - API servers should not have scoreboard functionality
  - Scoreboard URLs are now set to empty string for API servers
  - Need to implement proper access control in application
  - Consider adding middleware to block scoreboard routes on API servers
  - Add validation in controllers to prevent scoreboard access

### **Implementation Details**
- Current: Scoreboard URL is empty string for `carambus_api` in production
- Future: Add route-level blocking for scoreboard paths
- Future: Add controller-level validation
- Future: Add middleware for API server detection

## 🚀 **Deployment & Infrastructure**

### **Database Management**
- [ ] Implement automatic database backup before deployment
- [ ] Add database migration validation
- [ ] Add database connection health checks

### **Monitoring & Logging**
- [ ] Add application health check endpoints
- [ ] Implement structured logging
- [ ] Add performance monitoring

## 🔧 **Development & Testing**

### **Testing**
- [ ] Add integration tests for mode system
- [ ] Add tests for socket-based deployment
- [ ] Add tests for scoreboard access restrictions

### **Documentation**
- [ ] Update API documentation
- [ ] Add deployment troubleshooting guide
- [ ] Document scoreboard access restrictions
