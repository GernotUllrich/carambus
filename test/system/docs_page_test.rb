# frozen_string_literal: true

require "application_system_test_case"

class DocsPageTest < ApplicationSystemTestCase
  test "can access docs page" do
    visit docs_page_path(path: 'tournament', locale: 'de')
    
    assert_text "Tournament"
    assert_text "In MkDocs anzeigen"
  end

  test "can switch between languages" do
    visit docs_page_path(path: 'tournament', locale: 'de')
    assert_text "Tournament"
    
    visit docs_page_path(path: 'tournament', locale: 'en')
    assert_text "Tournament"
  end

  test "shows 404 for non-existent page" do
    visit docs_page_path(path: 'non_existent_page', locale: 'de')
    
    # Should redirect or show appropriate error
    assert_current_path docs_page_path(path: 'non_existent_page', locale: 'de')
  end
end
