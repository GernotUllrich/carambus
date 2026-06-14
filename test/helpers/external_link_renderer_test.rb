# frozen_string_literal: true

require "test_helper"

# User-Wunsch 2026-06-14: externe Links im Chat öffnen in neuem Tab, interne/relative nicht.
class ExternalLinkRendererTest < ActiveSupport::TestCase
  def render(md)
    Redcarpet::Markdown.new(
      ExternalLinkRenderer.new(filter_html: true, hard_wrap: true),
      autolink: true, tables: true
    ).render(md)
  end

  test "externer Markdown-Link → target=_blank + rel=noopener" do
    html = render("[Turnier ansehen](https://www.ndbv.de/sb_meisterschaft.php?p=20--2025/2026-939----1-100000-)")
    assert_includes html, 'target="_blank"'
    assert_includes html, 'rel="noopener noreferrer"'
    assert_includes html, "https://www.ndbv.de/sb_meisterschaft.php"
  end

  test "interner/relativer Link → KEIN neues Tab" do
    html = render("[Doku](/docs/foo)")
    refute_includes html, 'target="_blank"'
    assert_includes html, 'href="/docs/foo"'
  end
end
