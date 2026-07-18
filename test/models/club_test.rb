# frozen_string_literal: true

require "test_helper"

class ClubTest < ActiveSupport::TestCase
  # --- Change-Gate-Content (Phase 23, Roster): Club.roster_content ---

  def players_doc(links_html)
    Nokogiri::HTML(<<~HTML)
      <aside>
        <table class="silver"><tr><th>Info</th></tr></table>
        <table class="silver">
          <tr><th>Mitglieder</th></tr>
          #{links_html}
        </table>
      </aside>
    HTML
  end

  test "roster_content extrahiert Spielerzeilen (Name|href), sortiert" do
    doc = players_doc(<<~ROWS)
      <tr><td><a class="cc_bluelink" href="person.php?p=1|2|3|4|5|77">Zabel, Anton</a></td></tr>
      <tr><td><a class="cc_bluelink" href="person.php?p=1|2|3|4|5|42">Alt, Berta</a></td></tr>
    ROWS
    content = Club.roster_content(doc)
    assert_includes content, "Zabel, Anton|person.php?p=1|2|3|4|5|77"
    assert_includes content, "Alt, Berta|person.php?p=1|2|3|4|5|42"
    # deterministisch sortiert → "Alt…" vor "Zabel…"
    assert content.index("Alt, Berta") < content.index("Zabel, Anton")
  end

  test "roster_content: neuer Spieler ändert den content (digest kippt → deep)" do
    base = Club.roster_content(players_doc(
      '<tr><td><a class="cc_bluelink" href="person.php?p=|5|11">A, X</a></td></tr>'
    ))
    added = Club.roster_content(players_doc(<<~ROWS))
      <tr><td><a class="cc_bluelink" href="person.php?p=|5|11">A, X</a></td></tr>
      <tr><td><a class="cc_bluelink" href="person.php?p=|5|12">B, Y</a></td></tr>
    ROWS
    refute_equal base, added
  end

  test "roster_content: entfernter Spieler ändert den content (kein Fehl-Skip bei Roster-Schrumpfung)" do
    full = Club.roster_content(players_doc(<<~ROWS))
      <tr><td><a class="cc_bluelink" href="person.php?p=|5|11">A, X</a></td></tr>
      <tr><td><a class="cc_bluelink" href="person.php?p=|5|12">B, Y</a></td></tr>
    ROWS
    shrunk = Club.roster_content(players_doc(
      '<tr><td><a class="cc_bluelink" href="person.php?p=|5|11">A, X</a></td></tr>'
    ))
    refute_equal full, shrunk
  end

  test "roster_content: fehlende Tabelle bzw. nil → leerer String (führt zu stale→deep)" do
    assert_equal "", Club.roster_content(nil)
    no_table = Nokogiri::HTML("<aside><table class=\"silver\"><tr><th>x</th></tr></table></aside>")
    assert_equal "", Club.roster_content(no_table)
  end
end
