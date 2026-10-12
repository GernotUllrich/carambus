# Search & Filters

Every list in Carambus (tournaments, players, clubs, results …) has its own search field and a filter popup, even
without signing in.

## Searching a list {#list-search}

- **Free terms** search the main text columns of the current list, e.g. tournament title or player name. With
  several terms, all of them must match.
- **`field:value`** filters on a specific field, also with comparisons such as `>=` or `<`.
- Carambus remembers the search term per list for the current session.

There is no search across all lists at once.

➡️ Which fields exist and how the filter popup builds them: [Filter Popup](filter_popup_usage.md)

## Scope: region, season, branch {#scope}

Above the lists, the **Ausschnitt** (scope) band sets the fields **Region**, **Saison** (season) and **Branch**
(e.g. carom), and for players also **Club**. The lists then show only this scope. Signed-in users keep their scope
beyond the session.

## AI assistant {#ai}

The **AI Assistant** button in the sidebar takes a question in plain language, picks the matching list and sets the
filter. It requires signing in and an AI access configured on the server.
➡️ [AI-Powered Search](../players/ai-search.md)

## What is not available {#not-available}

- **No saved searches.** Named search filters cannot be stored.
- **No export of filtered lists** as CSV or PDF. The only exports are a table's game protocol (PDF for printing) and
  the tournament results as CSV for the ClubCloud.
