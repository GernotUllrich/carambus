# Database Operations - Coding Rules

## CRITICAL: Always Use `.destroy` Instead of `.delete`

### ❌ NEVER Use `.delete` or `.delete_all`

```ruby
# BAD - Bypasses callbacks and PaperTrail
record.delete
Model.where(condition).delete_all
```

### ✅ ALWAYS Use `.destroy` or `.destroy_all`

```ruby
# GOOD - Triggers callbacks and PaperTrail versioning
record.destroy
Model.where(condition).destroy_all

# Or iterate for better control and logging
Model.where(condition).each do |record|
  puts "Destroying: #{record.name} (ID #{record.id})"
  record.destroy
end
```

## Why This Matters

### 1. **PaperTrail Versioning**
- `.delete` bypasses PaperTrail
- No audit trail is created
- Cannot track who deleted what and when
- Cannot restore deleted records from versions

### 2. **Multi-Tenant Synchronization**
- Local servers need to sync deletions from API server
- `.delete` may not trigger synchronization mechanisms
- Can cause data inconsistencies between servers
- May break replication/sync processes

### 3. **ActiveRecord Callbacks**
- `.delete` skips all callbacks:
  - `before_destroy`
  - `after_destroy`
  - `around_destroy`
- Can leave orphaned records in associated tables
- May skip cleanup logic

### 4. **Dependent Associations**
- `has_many :items, dependent: :destroy` won't work with `.delete`
- Orphaned records remain in database
- Violates referential integrity

## Example: Correct Pattern

```ruby
# Script to clean up old records
def cleanup_old_plans
  plans_to_remove = TournamentPlan.where("created_at < ?", 1.year.ago)
  
  count = 0
  plans_to_remove.each do |plan|
    Rails.logger.info "Destroying TournamentPlan: #{plan.name} (ID #{plan.id})"
    
    if plan.destroy
      count += 1
    else
      Rails.logger.error "Failed to destroy #{plan.name}: #{plan.errors.full_messages}"
    end
  end
  
  Rails.logger.info "Successfully destroyed #{count} plans"
end
```

## Performance Considerations

If you have legitimate performance reasons to use `.delete`:

1. **Document why** in comments
2. **Get approval** from team
3. **Consider alternatives**:
   - Batch processing with `.destroy_all`
   - Background jobs
   - Database-level cascading deletes (with caution)

## Exceptions

The ONLY acceptable use of `.delete`:

```ruby
# Cleaning up truly temporary data that:
# - Is not versioned (no PaperTrail)
# - Has no important callbacks
# - Does not need to sync between servers
# - Is documented as temporary/cache data

# Example: Clearing Redis-backed cache table
SessionCache.where("expires_at < ?", Time.current).delete_all
```

**Even then:** Document with a comment explaining why `.delete` is safe!

## Code Review Checklist

When reviewing code, check for:
- [ ] All `.delete` calls should be `.destroy`
- [ ] All `.delete_all` calls should be `.destroy_all`
- [ ] Batch operations iterate with `.destroy` for logging
- [ ] Exceptions are documented with comments

## Related

- PaperTrail documentation: https://github.com/paper-trail-gem/paper_trail
- Multi-tenant sync architecture: `doc/MULTI_TENANT_SYNC.md` (if exists)
- LocalProtector concerns: `app/models/concerns/local_protector.rb`

## Enforcement

This rule is **CRITICAL** for:
- ✅ Data integrity
- ✅ Audit compliance
- ✅ Multi-server synchronization
- ✅ Production stability

**Violations should be caught in code review before merge.**
