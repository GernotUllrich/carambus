# Filter Popup Usage Guide

This guide explains how to use the filter popup component in your application.

## Overview

The filter popup provides a user-friendly interface for filtering data in tables. It automatically generates filter fields based on the `COLUMN_NAMES` hash defined in your models.

## Requirements

1. Your model must have a `self.search_hash` method that returns a hash with a `:column_names` key.
2. The `:column_names` key should contain a hash mapping display names to column definitions.

## Adding the Filter Popup to a View

To add the filter popup to a view, use the shared partial:

```erb
<%= render partial: 'shared/search_with_filter', locals: { 
  model_class: YourModel, 
} %>
```

## Model Configuration

Your model should have a `COLUMN_NAMES` hash and a `self.search_hash` method:

```ruby
class YourModel < ApplicationRecord
  COLUMN_NAMES = {
    "ID" => "your_models.id",
    "Name" => "your_models.name",
    "Date" => "your_models.created_at::date",
    "Related Model" => "related_models.name"
  }.freeze

  def self.search_hash(params)
    {
      model: YourModel,
      sort: params[:sort],
      direction: sort_direction(params[:direction]),
      search: [params[:sSearch], params[:search]].compact.join("&").to_s,
      column_names: YourModel::COLUMN_NAMES,
      raw_sql: "(your_models.name ilike :search)",
      joins: [:related_model]
    }
  end
end
```

## Field Types

The filter popup automatically determines field types based on the column definition:

- Date fields: Columns ending with `::date`
- Number fields: Columns ending with `_id` or `.id`
- Text fields: All other columns

## Comparison Operators

For date and number fields, the filter popup provides comparison operators:
- Contains (default)
- Equal to (=)
- Greater than (>)
- Greater than or equal to (>=)
- Less than (<)
- Less than or equal to (<=)

## Search Syntax

The filter popup generates search queries in the format:

```
field:value field2:>value2 field3:<=value3
```

This syntax is processed by the `apply_filters` method in the `FiltersHelper` module.

## Customization

To customize the appearance of the filter popup, modify the CSS in `app/assets/stylesheets/filter_popup.css`.

To customize the behavior, modify the Stimulus controller in `app/javascript/controllers/filter_popup_controller.js`. 
