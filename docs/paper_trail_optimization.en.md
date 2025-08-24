# PaperTrail Optimization for Scraping Operations

## Problem

During tournament scraping operations, PaperTrail was creating unnecessary version records where only the `updated_at` timestamp or `sync_date` field changed, but no meaningful data was modified. Additionally, `data_will_change!` was being called even when the `data` field hadn't actually changed, creating version records for non-existent changes.

Example of the issue:
```ruby
# Version record showing only timestamp changes
{
  "data" => [nil, nil], 
  "updated_at" => [2025-03-17 14:54:40.746295 UTC, 2025-06-27 12:00:32.087019 UTC]
}
```

## Solution

### 1. Configure PaperTrail to Ignore Specific Fields (API Servers Only)

Added `has_paper_trail ignore: [:updated_at, :sync_date] unless Carambus.config.carambus_api_url.present?` to models that are frequently updated during scraping operations. **PaperTrail is only enabled on API servers** (when `carambus_api_url` is present), not on local servers.

Models with PaperTrail configuration:
- `Tournament` - Ignores `updated_at` and `sync_date`
- `Game` - Ignores `updated_at`
- `Party` - Ignores `updated_at` and `sync_date`
- `League` - Ignores `updated_at` and `sync_date`
- `Club` - Ignores `updated_at` and `sync_date`
- `Location` - Ignores `updated_at` and `sync_date`
- `Region` - Ignores `updated_at` and `sync_date`
- `SeasonParticipation` - Ignores `updated_at` and `sync_date`

### 2. Fix Unnecessary `data_will_change!` Calls

Fixed methods that were calling `data_will_change!` even when the `data` field hadn't actually changed:

**Tournament Model:**
- `before_save` callback: Only process data if it's present
- `deep_merge_data!` method: Only call `data_will_change!` if data actually changed
- `reset_tournament` method: Only call `data_will_change!` if data is not already empty

**Game Model:**
- `deep_merge_data!` method: Only call `data_will_change!` if data actually changed
- `deep_delete!` method: Only call `data_will_change!` if data actually changed

### 3. Cleanup Task

Created a rake task to clean up existing unnecessary version records:

```bash
rails cleanup:cleanup_paper_trail_versions
```

This task:
- Identifies version records that only contain `updated_at` or `sync_date` changes
- Removes them from the database
- Provides a summary of deleted records

### 4. Testing

Added tests to verify that PaperTrail correctly ignores the specified fields:

```ruby
test "PaperTrail ignores updated_at and sync_date changes" do
  # Test implementation in test/models/tournament_test.rb
end
```

## Benefits

1. **Reduced Database Storage**: Eliminates unnecessary version records
2. **Cleaner Version History**: Only meaningful changes are tracked
3. **Better Performance**: Fewer records to process during version queries
4. **Maintained Audit Trail**: Important changes are still tracked
5. **Local Server Optimization**: No PaperTrail overhead on local servers
6. **Accurate Change Detection**: Only creates versions when data actually changes

## Usage

### For New Models

When adding PaperTrail to a new model that might be updated during scraping:

```ruby
class NewModel < ApplicationRecord
  include LocalProtector
  include SourceHandler
  
  # Configure PaperTrail to ignore automatic timestamp updates (API servers only)
  has_paper_trail ignore: [:updated_at, :sync_date] unless Carambus.config.carambus_api_url.present?
end
```

### For Existing Models

If you need to add ignore configuration to an existing model:

1. Add the `has_paper_trail ignore: [...] unless Carambus.config.carambus_api_url.present?` line to the model
2. Review and fix any `data_will_change!` calls to only trigger when data actually changes
3. Run the cleanup task to remove existing unnecessary versions
4. Test to ensure important changes are still tracked

### Best Practices for `data_will_change!`

When working with serialized data fields:

```ruby
# ❌ Bad - calls data_will_change! even if no change
def update_data(new_data)
  data_will_change!
  self.data = new_data
end

# ✅ Good - only calls data_will_change! if data actually changes
def update_data(new_data)
  if new_data != data
    data_will_change!
    self.data = new_data
  end
end
```

## Server Configuration

- **API Servers** (`carambus_api_url` is present): PaperTrail is enabled with optimized ignore settings
- **Local Servers** (`carambus_api_url` is blank): PaperTrail is completely disabled

## Monitoring

To monitor the effectiveness of this optimization:

```ruby
# Check if PaperTrail is enabled for a model
Tournament.paper_trail_enabled_for_model?

# Check version counts for a specific model (API servers only)
Tournament.first.versions.count if Tournament.paper_trail_enabled_for_model?

# Check recent versions for a model
Tournament.first.versions.last(10).each do |version|
  changes = YAML.load(version.object_changes)
  puts "Changes: #{changes.keys}"
end if Tournament.paper_trail_enabled_for_model?
```

## Related Files

- `app/models/tournament.rb` - Tournament model with PaperTrail configuration and data_will_change! fixes
- `app/models/game.rb` - Game model with PaperTrail configuration and data_will_change! fixes
- `lib/tasks/cleanup.rake` - Cleanup task for unnecessary versions
- `test/models/tournament_test.rb` - Tests for PaperTrail behavior
- `app/models/concerns/source_handler.rb` - Concern that updates sync_date 