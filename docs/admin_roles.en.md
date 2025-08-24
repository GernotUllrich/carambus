# Admin Roles and Permissions

## Role Matrix

| Permission           | Player | Club Admin | System Admin |
|----------------------|--------|------------|--------------|
| Create tournaments   | No     | Yes        | Yes          |
| Manage users        | No     | No         | Yes          |
| System settings     | No     | No         | Yes          |

## Role Descriptions

### Player
- **Permissions**: Basic player functions
- **Restrictions**: Cannot perform administrative actions
- **Access**: Only to own player data and current tournaments

### Club Admin
- **Permissions**: Management of club data and tournaments
- **Restrictions**: No access to system level
- **Responsibilities**: 
  - Create and manage tournaments
  - Manage club members
  - Adjust local settings

### System Admin
- **Permissions**: Full access to all system functions
- **Responsibilities**:
  - User management at system level
  - System configuration
  - Database administration
  - Backup and maintenance

## Permission Management

### Assigning Roles
```bash
# Via the admin interface
Admin -> Users -> Select user -> Change role

# Via console (System Admin only)
rails console
user = User.find_by(email: 'admin@example.com')
user.role = 'system_admin'
user.save!
```

### Checking Permissions
```ruby
# In the application
if current_user.can_create_tournaments?
  # Allow tournament creation
end

if current_user.is_system_admin?
  # Show system functions
end
```

## Security Guidelines

### Best Practices
- **Principle of least privilege**: Users receive only the permissions they actually need
- **Regular review**: Admin roles should be reviewed regularly
- **Audit log**: All administrative actions are logged

### Role Changes
- Role changes must be performed by a System Admin
- All changes are logged in the audit log
- Notifications are sent to affected users 