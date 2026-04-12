# AI-Powered Search

The AI-powered search enables the use of natural English or German language to find data in Carambus. The feature uses OpenAI's GPT-4o-mini model to translate search queries into structured filter syntax.

## 📋 Table of Contents

- [Setup](#setup)
- [Usage](#usage)
- [Examples](#examples)
- [Supported Entities](#supported-entities)
- [Filter Syntax](#filter-syntax)
- [Troubleshooting](#troubleshooting)
- [Costs](#costs)

## 🚀 Setup

### Add OpenAI API Key

1. **Get OpenAI API Key**
   - Create an account at https://platform.openai.com
   - Generate an API key under "API Keys"
   - Copy the key (starts with `sk-...`)

2. **Add Key to Rails Credentials**

   ```bash
   cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
   EDITOR="code --wait" rails credentials:edit --environment development
   ```

3. **Add the following lines:**

   ```yaml
   openai:
     api_key: sk-your-actual-api-key-here
   ```

4. **Save and close**
   - Save the file (Cmd+S in VS Code)
   - Close the editor
   - Rails will automatically encrypt the credentials

5. **For Production** (on the API server):

   ```bash
   EDITOR="nano" rails credentials:edit --environment production
   ```

## 💡 Usage

### Access

1. **AI Assistant Button** in the left navigation (between logo and menu)
2. Button shows a ✨ Sparkle icon
3. Click to open the search field

### Submit a Search Query

1. Enter query in natural English or German language
2. Press Enter or click "Search"
3. AI analyzes the query (1-3 seconds)
4. Automatic navigation to results page

### Example Workflow

```
Input: "Tournaments in Hamburg last 2 weeks"
        ↓
AI analyzes...
        ↓
Translates to: "Region:HH Date:>today-2w"
        ↓
Navigates to: /tournaments?sSearch=Region:HH+Date:>today-2w
```

## 📝 Examples

### Find Tournaments

```
"Tournaments in Hamburg"
→ tournaments with filter: Region:HH

"Three-cushion tournaments 2024"
→ tournaments with filter: Discipline:Dreiband Season:2024/2025

"Tournaments last 2 weeks"
→ tournaments with filter: Date:>today-2w

"Straight rail in Westphalia today"
→ tournaments with filter: Discipline:Freie Partie Region:WL Date:today
```

### Find Players

```
"All players from Westphalia"
→ players with filter: Region:WL

"Meyer Hamburg"
→ players with filter: Meyer Region:HH

"Players from Berlin season 2024"
→ players with filter: Region:BE Season:2024/2025
```

### Find Clubs

```
"Clubs in Hamburg"
→ clubs with filter: Region:HH

"Clubs Westphalia"
→ clubs with filter: Region:WL
```

### Match Days and Leagues

```
"Match days last week"
→ parties with filter: Date:>today-1w

"Team matches today"
→ party_games with filter: Date:today

"Match days Hamburg 2024"
→ parties with filter: Region:HH Season:2024/2025
```

## 🎯 Supported Entities

The AI can search the following data types:

| Entity | English/German Names | Common Filters |
|--------|---------------------|----------------|
| `players` | Players, Spieler, Participants | Region, Club, Firstname, Lastname, Season |
| `clubs` | Clubs, Vereine | Region, Name |
| `tournaments` | Tournaments, Turniere, Events | Season, Region, Discipline, Date, Title |
| `locations` | Locations, Spielorte, Venues | Region, Name, City |
| `regions` | Regions, Regionen | Shortname, Name |
| `seasons` | Seasons, Saisons | Name |
| `season_participations` | Season Participations, Saisonteilnahmen | Season, Player, Club, Region |
| `parties` | Match Days, Spieltage | Season, League, Date, Region |
| `game_participations` | Game Participations, Spielteilnahmen | Player, Game, Season |
| `seedings` | Tournament Seedings, Setzungen | Tournament, Player, Season, Discipline |
| `party_games` | Team Matches, Mannschaftsspiele | Party, Player, Date |
| `disciplines` | Disciplines, Disziplinen | Name |

## 🔍 Filter Syntax

The AI translates your query into the following filter syntax:

### Regions (use abbreviations!)

```
Region:WL   → Westfalen-Lippe (Westphalia)
Region:HH   → Hamburg
Region:BE   → Berlin
Region:BY   → Bayern (Bavaria)
Region:NI   → Niedersachsen (Lower Saxony)
Region:BW   → Baden-Württemberg
Region:HE   → Hessen (Hesse)
Region:NW   → Nordrhein-Westfalen (North Rhine-Westphalia)
Region:RP   → Rheinland-Pfalz (Rhineland-Palatinate)
Region:SH   → Schleswig-Holstein
Region:SL   → Saarland
```

### Disciplines

```
Discipline:Freie Partie    (Straight Rail)
Discipline:Dreiband        (Three-cushion)
Discipline:Einband         (One-cushion)
Discipline:Cadre           (Cadre)
Discipline:Pool            (Pool)
Discipline:Snooker         (Snooker)
```

### Seasons

```
Season:2024/2025
Season:2023/2024
```

### Date (relative and absolute)

```
# Relative
Date:today              → today
Date:>today-2w          → after 2 weeks ago
Date:<today+7           → before in 7 days
Date:>today-1m          → after 1 month ago

# Units
d = days
w = weeks  
m = months

# Absolute
Date:>2025-01-01
Date:<2025-12-31
Date:2025-10-24
```

### Free Text

```
Meyer                   → Searches "Meyer" in all text fields
Three-cushion Hamburg   → Combines multiple search terms with AND logic
```

### Combination (multiple filters)

```
Season:2024/2025 Region:HH              → Season AND Region
Discipline:Dreiband Date:>today-2w      → Discipline AND Date
Meyer Region:WL Season:2024/2025        → Free text AND filters
```

## 🔧 Troubleshooting

### "OpenAI not configured"

**Problem:** API Key missing in credentials  
**Solution:** Follow setup steps above, add API key

### "AI could not understand your query"

**Problem:** Query too vague or ambiguous  
**Solution:** 
- Be more specific: "Tournaments" instead of "Events"
- Explicitly mention region/discipline/timeframe
- Use examples as templates

### Low Confidence (<70%)

**Problem:** AI is uncertain  
**Solution:**
- Use more explicit terms
- Provide more context
- Use filter syntax directly (in normal search field)

### Wrong Entity Detected

**Problem:** Search for "Players" leads to "Tournaments"  
**Solution:**
- Be clearer: "All players from..." instead of "Players Hamburg"
- Use entity names from table above

## 💰 Costs

Using OpenAI GPT-4o-mini is **very affordable**:

| Action | Input Tokens | Output Tokens | Cost |
|--------|-------------|---------------|------|
| 1 Query | ~500 | ~100 | ~€0.0001 |
| 1,000 queries/month | - | - | ~€0.08 |
| 10,000 queries/month | - | - | ~€0.80 |

**Note:** Actual costs are minimal and negligible for normal usage.

### Cost Monitoring

OpenAI Dashboard shows real-time usage: https://platform.openai.com/usage

## 📊 Technical Details

### Architecture

```
User Input (German/English)
        ↓
Stimulus Controller (ai_search_controller.js)
        ↓
POST /api/ai_search
        ↓
AiSearchController
        ↓
AiSearchService
        ↓
OpenAI GPT-4o-mini (JSON Response)
        ↓
Filter Syntax
        ↓
Navigation to filtered results
```

### Service Structure

```ruby
AiSearchService.call(
  query: "Tournaments in Hamburg",
  user: current_user
)

# Returns:
{
  success: true,
  entity: "tournaments",
  filters: "Region:HH",
  confidence: 95,
  explanation: "Searching for tournaments in Hamburg",
  path: "/tournaments?sSearch=Region:HH"
}
```

### System Prompt

The AI service uses an optimized system prompt:
- German and English billiards terminology (Dreiband/Three-cushion, Freie Partie/Straight Rail, etc.)
- Carambus entity mapping
- Filter syntax with examples
- JSON schema enforcement
- Context about available regions and disciplines

### Security

- ✅ User authentication required
- ✅ CSRF protection
- ✅ API key encrypted in Rails credentials
- ✅ Input sanitization
- ✅ Error handling with fallbacks

## 🎓 Best Practices

### Good Queries

✅ "Tournaments in Hamburg last 2 weeks"  
✅ "Three-cushion players from Berlin"  
✅ "Straight rail season 2024/2025"  
✅ "Match days Hamburg today"

### Less Effective Queries

❌ "Stuff" (too vague)  
❌ "Something about billiards" (not specific)  
❌ "All data" (no filters)

### Tips

1. **Be specific:** Mention region/discipline/timeframe
2. **Use standard terms:** "Tournament" instead of "Event"
3. **Combine:** Multiple filters in one query possible
4. **When unsure:** Use examples as templates

## 📚 Further Links

- [OpenAI Platform](https://platform.openai.com)
- [GPT-4o-mini Pricing](https://openai.com/pricing)
- Carambus Filter Documentation

## 🤝 Support

For issues or questions:
1. Check troubleshooting section above
2. Check log files: `log/development.log` or `log/production.log`
3. Create GitHub issues

---

**Version:** 1.0.0  
**Last Updated:** October 2024  
**Status:** MVP (Minimum Viable Product)

