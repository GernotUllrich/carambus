# strong_migrations flags `force: :cascade` in each create_table block of
# db/schema.rb whenever Rails loads the schema (e.g. via `db:test:prepare`).
# Schema loading is not a real migration and cannot damage production data,
# so we opt the test environment out wholesale. Production and development
# keep all checks active.
ENV["SAFETY_ASSURED"] = "1" if Rails.env.test?
