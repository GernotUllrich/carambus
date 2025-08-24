# Search in Carambus

## Overview

The search function in Carambus is a powerful tool that allows users to navigate quickly and efficiently through all data. The search works on all index pages of the various tables and offers both global and targeted search capabilities.

## Global Search

### How it works
By simply entering text, you can search in different places at the same time. Where exactly the search is performed depends on the context of the current table.

### Search areas (Example: Clubs)
When searching for clubs, the following fields are searched:
- **Name** - Complete club name
- **Shortname** - Abbreviated club name
- **Address** - Complete club address
- **Region.shortname** - Abbreviated region name
- **E-mail** - Club e-mail address
- **CC-ID** - ClubCloud identifier

### Intelligent connections
The search uses intelligent connections between different data fields. For example, you can:
- Search for "NBV" and find all clubs in the region via the `region.shortname` connection
- Search for a specific ClubCloud ID
- Search for parts of addresses or names

### Multiple search
Any number of text segments can be entered. The terms are "AND" linked, meaning all text segments must occur in the found table rows.

**Example:**
- Searching for "Wedel Billard" finds only clubs that contain both "Wedel" and "Billard" in the name

## Targeted search in table columns

### Filter form
To make it as easy as possible for the user, there is a filter form for each search field, which can be activated by clicking on the filter icon next to the search field.

### Search fields in the filter
The filter form contains:
1. **Global search field** - Works as described above
2. **Targeted fields** - Specific search criteria for certain columns
3. **Advanced options** - Additional search parameters

### Linking conditions
All conditions (global search + targeted search) are "AND" linked to provide precise results.

## Special data types

### Date search
For date fields, special comparison operators are supported:
- **=** - Exact date
- **<** - Before the specified date
- **<=** - Before or on the specified date
- **>** - After the specified date
- **>=** - After or on the specified date

#### Special date values
- **'today'** - Today's date
- **Default behavior** - For date searches, one week is subtracted by default
- **Example:** `>today` means "from one week ago to the future"

### Integer search
For number fields, the following comparison operators are supported:
- **=** - Equal
- **<** - Less than
- **<=** - Less than or equal
- **>** - Greater than
- **>=** - Greater than or equal

## Practical application examples

### Club search
```
Search term: "Hamburg"
Result: All clubs in Hamburg or with "Hamburg" in the name
```

### Tournament search
```
Search term: "2024"
Result: All tournaments in 2024
```

### Player search
```
Search term: "Müller"
Result: All players with the name "Müller"
```

## Search tips

### Effective searching
1. **Start with few characters** - The search also finds partial terms
2. **Use abbreviations** - Short names are often found better
3. **Combine terms** - Multiple search terms refine the results
4. **Use the filters** - For more complex search queries

### Avoiding common mistakes
- **Too specific search** - Start with more general terms
- **Wrong spelling** - Pay attention to correct spelling
- **Forgetting the filters** - Use the advanced search options

## Advanced search functions

### Wildcard search
The search automatically supports partial terms, so you don't have to enter the complete term.

### Case sensitivity
The search is not case-sensitive, meaning "hamburg" and "Hamburg" return the same results.

### Accent insensitive
Umlauts and special characters are handled correctly.

## Technical details

### Search algorithm
- **Full-text search** in all relevant fields
- **Fuzzy matching** for similar terms
- **Relevance sorting** of results

### Performance
- **Indexed search** for fast results
- **Caching** of frequently used search terms
- **Lazy loading** of large result sets

## Troubleshooting

### No results found
1. **Check the spelling**
2. **Simplify the search terms**
3. **Use the filter options**
4. **Contact the administrator**

### Slow search
1. **Reduce the number of search terms**
2. **Use more specific search criteria**
3. **Wait for large data sets**

## Future extensions

Planned improvements to the search function:
- **Full-text search** in documents and notes
- **Similarity search** for related terms
- **Search history** for frequently used search queries
- **Advanced filters** for complex data structures
- **Export functions** for search results

