# Test Snapshots

This directory contains snapshots used for testing.

## Structure

```
snapshots/
├── vcr/              # HTTP interaction recordings (VCR cassettes)
│   ├── nbv_tournament_2025.yml
│   ├── league_details.yml
│   └── ...
├── data/             # Data snapshots for comparison
│   ├── tournament_structure.yml
│   └── ...
└── html/             # HTML fixtures (optional, for manual inspection)
    └── ...
```

## VCR Cassettes

VCR cassettes record HTTP interactions with ClubCloud and other external services.

### Recording New Cassettes

1. Delete the cassette file (or use `:record => :all`)
2. Run the test - it will make real HTTP requests
3. VCR saves the response
4. Subsequent test runs use the saved response

### Updating Cassettes

When ClubCloud structure changes:

1. Delete outdated cassette
2. Re-run test to record new response
3. Review changes to ensure scraping logic still works
4. Commit updated cassette

### Sensitive Data

VCR automatically filters:
- Usernames (replaced with `<CC_USERNAME>`)
- Passwords (replaced with `<CC_PASSWORD>`)
- Session IDs (if configured)

## Data Snapshots

Data snapshots capture expected data structures for comparison.

### Creating Snapshots

```ruby
# In a test
snapshot_data = {
  title: tournament.title,
  date: tournament.date,
  # ...
}

assert_matches_snapshot("tournament_basic_structure", snapshot_data)
```

First run creates the snapshot, subsequent runs compare against it.

### Updating Snapshots

When intentional changes occur:

```ruby
update_snapshot("tournament_basic_structure", new_data)
```

## HTML Fixtures

Saved HTML files for manual inspection or testing without VCR.

### Usage

```ruby
html_content = read_html_fixture("nbv_tournament.html")
mock_clubcloud_html(url, html_content)
```

## Best Practices

1. **Keep cassettes small**: Only record what's needed
2. **Document changes**: When updating cassettes, note why in commit message
3. **Version control**: Commit all snapshots to track changes over time
4. **Regular updates**: Update cassettes periodically to catch structural changes early

## Maintenance

Review snapshots quarterly to ensure they're still relevant:

```bash
# Find old snapshots
find test/snapshots -type f -mtime +90

# Consider updating or removing outdated snapshots
```

## Troubleshooting

### Test fails with "VCR cassette not found"

The cassette file is missing. Run the test to record it.

### Test fails with "Response doesn't match"

ClubCloud structure may have changed. Delete cassette and re-record.

### Sensitive data in cassette

Check VCR filters in `test/support/vcr_setup.rb`.

---

For more info: https://github.com/vcr/vcr
