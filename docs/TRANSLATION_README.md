# Translation System - Quick Start

Comprehensive translation system for carom billiard content with billiard-specific glossaries.

## ⚡ Quick Access

**Admin Dashboard Tool:** `/admin/translations`
- Translate any text on-demand
- Choose DeepL or Claude (Anthropic)
- Copy result with one click

**Full Documentation:** [TRANSLATION.md](TRANSLATION.md)

## 🎯 What's Available

### 1. Ad-hoc Translation Tool (NEW!)
- **Location:** Admin Dashboard → "Translations"
- **Features:**
  - Input arbitrary text (multi-line supported)
  - Source languages: NL (default), FR, EN, DE
  - Target languages: DE (default), EN
  - Translation methods: DeepL API (default), Claude (Anthropic)
  - Copy to clipboard with fallback support
  - Line breaks preserved correctly

### 2. Automatic Translation for Models
- Tags, Training Concepts, Training Examples
- Checkbox: "🌐 Translate after saving"
- Uses `Translatable` concern

### 3. Billiard-Specific Glossaries
- **NL→DE, NL→EN, EN→DE, FR→DE, FR→EN**
- ~50 specialized billiard terms per glossary
- Examples: "speelbal" → "Spielball", "in brillenstand" → "in Brillenstellung"
- Automatically used by both DeepL and AI translation

## 🚀 For End Users

### Using the Ad-hoc Translation Tool

1. Open Admin Dashboard
2. Click "Translations" in sidebar
3. Enter your text
4. Select source/target language
5. Choose method (DeepL recommended for NL/EN, Claude for FR)
6. Click "Translate"
7. Copy result with button

**When to use which method:**
- **DeepL:** Fast, cheap, consistent (best for NL/EN → DE/EN)
- **Claude:** Better context understanding (best for FR or complex texts)

### Translating Tags/Concepts

1. Edit Tag/Concept
2. Check "🌐 Translate after saving"
3. Choose method
4. Save → automatic translation!

## 💻 For Developers

### Services

```ruby
# DeepL with glossary
DeeplTranslationService.new.translate(
  text: "De speelbal",
  source_lang: "nl",
  target_lang: "de",
  use_glossary: true
)
# => "Der Spielball"

# Anthropic Claude
AnthropicTranslationService.new.translate(
  text: "Les billes sont en position de lunette",
  source_lang: "fr",
  target_lang: "de"
)
# => "Die Bälle sind in Brillenstellung"
```

### Configuration

```bash
# Edit credentials
bin/rails credentials:edit --environment development
```

```yaml
# Required
deepl_key: "DeepL-Auth-Key xxx..."

# For Claude (recommended)
anthropic:
  api_key: "sk-ant-api03-..."

# For GPT (optional)
openai:
  api_key: "sk-proj-..."
```

### Glossary Management

```bash
# Update glossaries after editing glossary_service.rb
bin/rails glossary:update

# List all glossaries
bin/rails glossary:list

# Test translations
bin/rails glossary:test
```

### Files Overview

| File | Purpose |
|------|---------|
| `app/controllers/admin/translations_controller.rb` | Ad-hoc tool controller |
| `app/views/admin/translations/index.html.erb` | Translation UI |
| `app/services/deepl_translation_service.rb` | DeepL API with glossary |
| `app/services/deepl_glossary_service.rb` | Glossary CRUD |
| `app/services/anthropic_translation_service.rb` | Claude API |
| `app/services/openai_translation_service.rb` | GPT API (optional) |
| `app/models/concerns/translatable.rb` | Model concern |
| `lib/tasks/glossary.rake` | Glossary management tasks |

### Adding New Terms to Glossary

1. Edit `app/services/deepl_glossary_service.rb`
2. Add term to appropriate constant (e.g., `BILLIARD_GLOSSARY_NL_DE`)
3. Run `bin/rails glossary:update`
4. Restart server
5. Test with ad-hoc tool

## 📚 Full Documentation

**See [TRANSLATION.md](TRANSLATION.md) for:**
- Detailed API configuration
- Troubleshooting guide
- Advanced glossary management
- Technical architecture
- Best practices
- Cost comparisons

## 🔗 Related Documentation

- [Training Database](training_database.md) - Uses translations
- [Multilingual System](multilingual_system.md) - Translation architecture
- [Tagging System](tagging_system.md) - Translatable tags

## 🆘 Quick Help

**Problem:** Translation button not visible  
**Solution:** User must be admin, check `Admin::ApplicationController#valid_action?`

**Problem:** Glossary not applied  
**Solution:** Run `bin/rails glossary:update`

**Problem:** Line breaks missing  
**Solution:** Already fixed with `simple_format` helper in view

**Problem:** API key error  
**Solution:** Check credentials with `bin/rails credentials:show`

---

**Need more help?** See [TRANSLATION.md](TRANSLATION.md) for comprehensive documentation.
