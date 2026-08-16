# frozen_string_literal: true

require "test_helper"

# Aufloesung interner .md-Links zu docs_page-Routen.
#
# Hintergrund: '../' wurde frueher abgeschnitten statt gegen das Verzeichnis des
# aktuellen Dokuments gerechnet. Der Link '../developer-guide.de.md' in
# docs/developers/services/party-monitor.de.md landete dadurch auf
# /docs_page/de/developer-guide (404) statt auf .../de/developers/developer-guide.
class MarkdownRendererTest < ActiveSupport::TestCase
  def render(markdown, current_path:, locale: "de")
    renderer = MarkdownRenderer.new(locale: locale, current_path: current_path)
    Redcarpet::Markdown.new(renderer, fenced_code_blocks: true).render(markdown)
  end

  def href(html)
    html[/href="([^"]+)"/, 1]
  end

  # --- der gemeldete Fall ---

  test "eine Ebene hoch wird gegen das aktuelle Verzeichnis aufgeloest" do
    html = render("[Guide](../developer-guide.de.md)", current_path: "developers/services")

    assert_equal "/docs_page/de/developers/developer-guide", href(html)
  end

  test "Anker bleibt beim Hochgehen erhalten" do
    html = render("[Guide](../developer-guide.de.md#extrahierte-services)", current_path: "developers/services")

    assert_equal "/docs_page/de/developers/developer-guide#extrahierte-services", href(html)
  end

  test "zwei Ebenen hoch" do
    html = render("[X](../../index.de.md)", current_path: "developers/services/detail")

    assert_equal "/docs_page/de/developers/index", href(html)
  end

  # --- Bestandsverhalten ---

  test "Datei im selben Verzeichnis" do
    html = render("[X](tournament.de.md)", current_path: "developers/services")

    assert_equal "/docs_page/de/developers/services/tournament", href(html)
  end

  test "explizites ./ im selben Verzeichnis" do
    html = render("[X](./tournament.de.md)", current_path: "developers/services")

    assert_equal "/docs_page/de/developers/services/tournament", href(html)
  end

  test "Unterverzeichnis" do
    html = render("[X](services/umb.de.md)", current_path: "developers")

    assert_equal "/docs_page/de/developers/services/umb", href(html)
  end

  test "Dokument in der docs-Wurzel" do
    html = render("[X](about.de.md)", current_path: "")

    assert_equal "/docs_page/de/about", href(html)
  end

  test "Locale wird uebernommen" do
    html = render("[X](../developer-guide.en.md)", current_path: "developers/services", locale: "en")

    assert_equal "/docs_page/en/developers/developer-guide", href(html)
  end

  # --- Abgrenzungen ---

  test "externe Links bleiben unangetastet und oeffnen im neuen Tab" do
    html = render("[X](https://example.test/a.md)", current_path: "developers")

    assert_equal "https://example.test/a.md", href(html)
    assert_includes html, 'target="_blank"'
  end

  test "Nicht-md-Links bleiben unangetastet" do
    html = render("[X](/tournaments)", current_path: "developers")

    assert_equal "/tournaments", href(html)
  end

  test "Link aus dem docs-Baum heraus behaelt .. und laeuft in den 404-Guard" do
    html = render("[X](../../CHANGELOG.md)", current_path: "changelog")

    assert_includes href(html), "..",
      "der Directory-Traversal-Guard im Controller soll das als 404 abfangen"
  end
end
