# Data Management and ID Ranges

## ID Ranges

| Range           | Description                      | Edit Rights        |
|-----------------|----------------------------------|--------------------|
| < 5,000,000     | Imported ClubCloud data          | Read-only          |
| 5,000,000 - ... | Locally created entries          | Full access        |

**Important fields:**
- `source_url`: Original URL in ClubCloud
- `data`: Local extensions/adjustments

## Data Sources

### ClubCloud Data (ID < 5,000,000)
- **Origin**: Automatic import from ClubCloud
- **Editing**: Read-only, no local changes possible
- **Synchronization**: Daily at 8:00 PM
- **Responsibility**: Central ClubCloud administration

### Local Data (ID ≥ 5,000,000)
- **Origin**: Locally created or adjusted
- **Editing**: Full access, all changes possible
- **Synchronization**: Manually as needed
- **Responsibility**: Local administrators

## Data Management Guidelines

### Imported Data
- **Do not edit**: ClubCloud data must not be changed locally
- **Extend**: Local adjustments only through additional fields
- **Validation**: All imports are checked for consistency

### Local Data
- **Full access**: All CRUD operations allowed
- **Backup**: Regular backup of local data
- **Versioning**: Changes are logged

## Data Integrity

### Consistency Check
```ruby
# Example for data validation
class Tournament < ApplicationRecord
  validate :check_data_consistency
  
  private
  
  def check_data_consistency
    if id < 5_000_000 && changed?
      errors.add(:base, "ClubCloud data cannot be changed")
    end
  end
end
```

### Synchronization Log
- All data imports are logged
- Failed imports are marked
- Retry attempts on errors

## Best Practices

### For Developers
- **Check ID ranges**: Validate ID range before each data change
- **Protect source data**: Never edit ClubCloud data directly
- **Local extensions**: Use additional fields for local adjustments

### For Administrators
- **Regular backups**: Regularly backup local data
- **Import monitoring**: Monitor ClubCloud imports
- **Data quality**: Check consistency of local data 