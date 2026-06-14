# frozen_string_literal: true

# Redcarpet-Renderer, der NUR externe (absolute http/https) Links in einem neuen Tab öffnet
# (target="_blank" + rel="noopener noreferrer"). Interne/relative Links (z.B. /docs/...) bleiben
# normal. Genutzt vom Spielleiter-Chat (ApplicationHelper#markdown) — User-Wunsch 2026-06-14:
# „Die Links nach aussen sollten in neuem Tab laufen."
#
# Hinweis: Redcarpet::Render::HTML ist C-implementiert → `super` ist im Renderer NICHT verfügbar,
# daher bauen wir das <a>-Tag in beiden Fällen selbst (Markdown-Link `[text](url)`). Bloße
# Auto-Links (autolink) bleiben dem Default überlassen — der Chat-Prompt nutzt explizite Links.
class ExternalLinkRenderer < Redcarpet::Render::HTML
  def link(link, title, content)
    href = CGI.escapeHTML(link.to_s)
    title_attr = title.to_s.empty? ? "" : %( title="#{CGI.escapeHTML(title)}")
    if external?(link)
      %(<a href="#{href}" target="_blank" rel="noopener noreferrer"#{title_attr}>#{content}</a>)
    else
      %(<a href="#{href}"#{title_attr}>#{content}</a>)
    end
  end

  private

  def external?(link)
    link.to_s.match?(%r{\Ahttps?://}i)
  end
end
