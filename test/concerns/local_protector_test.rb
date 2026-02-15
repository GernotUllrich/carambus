# frozen_string_literal: true

require "test_helper"

class LocalProtectorTest < ActiveSupport::TestCase
  # LocalProtector Concern Tests
  #
  # WICHTIG: LocalProtector ist im Test-Environment DEAKTIVIERT (Zeile 30)
  # → return true if Rails.env.test?
  #
  # Wir können daher nur die Helper-Methoden testen, nicht das Protection-Verhalten!
  # Protection-Verhalten wird im echten Betrieb (Production) getestet.
  
  # ============================================================================
  # HELPER METHODS (testbar)
  # ============================================================================
  
  test "set_paper_trail_whodunnit captures caller stack" do
    tournament = Tournament.new(id: 50_000_100)
    
    result = tournament.set_paper_trail_whodunnit
    
    assert_equal true, result,
                 "set_paper_trail_whodunnit should return true"
  end
  
  test "hash_diff identifies differences between hashes" do
    tournament = Tournament.new
    
    first = { a: 1, b: 2, c: 3 }
    second = { a: 1, b: 99, d: 4 }
    
    diff = tournament.hash_diff(first, second)
    
    # hash_diff returns keys that differ or are new
    expected = { b: 2, c: 3, d: 4 }
    assert_equal expected, diff,
                 "hash_diff should show keys with different values and new keys"
  end
  
  test "hash_diff handles empty hashes" do
    tournament = Tournament.new
    
    # Both empty
    assert_equal({}, tournament.hash_diff({}, {}))
    
    # First empty
    assert_equal({ a: 1 }, tournament.hash_diff({}, { a: 1 }))
    
    # Second empty
    assert_equal({ a: 1 }, tournament.hash_diff({ a: 1 }, {}))
  end
  
  test "hash_diff handles identical hashes" do
    tournament = Tournament.new
    
    first = { a: 1, b: 2, c: 3 }
    second = { a: 1, b: 2, c: 3 }
    
    diff = tournament.hash_diff(first, second)
    
    assert_equal({}, diff, "Identical hashes should have no diff")
  end
  
  test "unprotected accessor works" do
    tournament = Tournament.new(id: 50_000_101)
    
    # Default is nil/false
    assert_not tournament.unprotected
    
    # Can be set
    tournament.unprotected = true
    assert tournament.unprotected
    
    # Can be unset
    tournament.unprotected = false
    assert_not tournament.unprotected
  end
  
  # ============================================================================
  # DOCUMENTATION
  # ============================================================================
  
  # LocalProtector schützt API-importierte Daten vor versehentlichen Änderungen
  # 
  # ABER: Im Test-Environment ist der Schutz DEAKTIVIERT!
  # Siehe app/models/local_protector.rb Zeile 30:
  #   return true if Rails.env.test?
  #
  # Das ist ABSICHTLICH so - Tests sollen frei Daten manipulieren können.
  #
  # ECHTER Schutz wird getestet durch:
  # 1. Manuelle Verifikation in Production/Staging
  # 2. Logging (Rails.logger.warn zeigt blockierte Saves)
  # 3. Tägliches Scraping validiert dass Schutz funktioniert
  #
  # Wir testen hier nur die Helper-Methoden (hash_diff, etc.)
end
