# Filter Popup Usage Guide

This guide explains how to use the filter popup component in your application.

## Overview

The filter popup provides a user-friendly interface for filtering data in tables. It automatically generates filter fields based on the `COLUMN_NAMES` hash defined in your models.

## Requirements

1. The model includes the `Searchable` concern (`app/models/concerns/searchable.rb`). It provides `search_hash`
   including `:column_names` and the field type detection (`filter_field_types`).
2. For that, the model defines `COLUMN_NAMES` (display name → SQL expression), `self.text_search_sql` and
   `self.search_joins`.

Technically, the popup only needs a `self.search_hash` returning `:column_names`. Without `Searchable`, however,
there is no field type detection and all fields appear as text fields.

## Adding the Filter Popup to a View

To add the filter popup to a view, use the shared partial:

```erb
<%= render partial: 'shared/search_with_filter', locals: { 
  model_class: YourModel, 
} %>
```

## Model Configuration

Your model includes `Searchable` and defines the three building blocks (pattern from the header of `searchable.rb`):

```ruby
class YourModel < ApplicationRecord
  include Searchable

  COLUMN_NAMES = {
    "id" => "your_models.id",
    "Name" => "your_models.name",
    "Date" => "your_models.created_at::date",
    "Region" => "regions.shortname"
  }.freeze

  def self.text_search_sql
    "(your_models.name ilike :search)"
  end

  def self.search_joins
    [:region]
  end
end
```

A custom `self.search_hash` is only needed in special cases where the concern's default behaviour does not fit.
The values in `COLUMN_NAMES` must be real SQL expressions that resolve with the `search_joins`.

## Field Types

With `Searchable`, `detect_field_type` determines the type of each field, mostly by its **display name**:

- **Hidden** (`:hidden`): display name `id` or lower-case ending in `_id` (e.g. `region_id`). These fields do not
  appear in the popup but can still be filtered.
- **Number** (`:number`): display name ends in `_ID`/`_id` and is not a lower-case `…_id` (e.g. `CC_ID`).
- **Date** (`:date`): the SQL expression contains `::date`.
- **Select** (`:select`): the SQL expression refers to `shortname` or `name` of `regions`, `seasons`, `clubs`,
  `disciplines`, `leagues`, `parties`, `tournaments` or `locations`.
- **Chips** (`:chips`): display name `Status`.
- **Text**: all other fields.

Without `Searchable`, all fields appear as text fields.

## Comparison Operators

For date and number fields, the filter popup provides comparison operators:
- Equal to (=)
- Greater than (>)
- Greater than or equal to (>=)
- Less than (<)
- Less than or equal to (<=)

Without an operator, number and date fields compare for equality; text fields search for "contains" (`ilike`).

## Search Syntax

The filter popup generates search queries in the format:

```
field:value field2:>value2 field3:<=value3
```

This syntax is processed by the `apply_filters` method in the `FiltersHelper` module. The following applies:

- Spaces, commas and `&` separate search terms. Put values containing spaces in quotes: `Location:"BC Wedel"`.
- There are no multiple values per field (such as `status:active,inactive`). The comma separates two terms; the
  second becomes an additional free-text search.
- Only the first condition per field counts. `score:>=100 score:<=200` only filters on `>=100`.
- Terms without `field:` search the columns from `text_search_sql` and are combined with AND.

## Customization

The popup is styled with Tailwind utilities directly in the partial: `app/views/shared/_filter_popup.html.erb` (and
`app/views/shared/_search_with_filter.html.erb`). Colours only via the design tokens described in
[docs/ui-conventions.md](../ui-conventions.md), no hard-coded colours.

To customize the behavior, modify the Stimulus controller in `app/javascript/controllers/filter_popup_controller.js`.

## Implementation Example

Excerpt from the real `Tournament` model (`app/models/tournament.rb`):

```ruby
class Tournament < ApplicationRecord
  include Searchable

  COLUMN_NAMES = {
    "id" => "tournaments.id",               # hidden
    "region_id" => "regions.id",            # hidden
    "CC_ID" => "tournament_ccs.cc_id",      # number
    "Region" => "regions.shortname",        # select
    "Season" => "seasons.name",             # select
    "Location" => "locations.name",         # select
    "Title" => "tournaments.title",         # text
    "Date" => "tournaments.date::date"      # date
    # … (shortened)
  }.freeze

  # text_search_sql and search_joins: see the model. The organizer is polymorphic
  # and is therefore joined via its own JOIN string, not via joins(:organizer).
end
```

## Troubleshooting

### Common Problems

1. **Filters do not work**: check that `COLUMN_NAMES` is defined correctly
2. **Missing joins**: make sure all required joins are defined in `search_joins`
3. **SQL errors**: a broken SQL expression in `COLUMN_NAMES` or `text_search_sql` does not abort. `apply_filters`
   writes the error to the log, and filtering is silently skipped.

### Debugging

```ruby
# Enable debug information
Rails.logger.level = Logger::DEBUG

# Check field types and columns
YourModel.filter_field_types
YourModel.search_hash({})[:column_names]
```
