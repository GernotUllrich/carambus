# i18n: add missing English translations for the `notification` subtree

**Labels:** good first issue, help wanted

## Summary

`config/locales/de.yml` contains a top-level `notification` subtree (attribute labels such as `recipient_id`, `read_at`, `params`, …) that is completely absent from `config/locales/en.yml`. English users fall back to raw keys or German defaults for these labels.

## Why it matters

Carambus supports German and English (`I18n` default `:de`, fallback `:en`). Every missing English subtree makes the English UI look half-finished. This is a small, self-contained translation task — a perfect first contribution with no Ruby knowledge required beyond YAML.

## Where

- `config/locales/de.yml` — top-level key `notification` (10 keys: `account_id`, `created_at`, `id`, `interacted_at`, `params`, `read_at`, `recipient_id`, `recipient_type`, `type`, `updated_at`)
- `config/locales/en.yml` — the `notification` key is missing entirely

(Background: `de.yml` has 118 top-level keys, `en.yml` has 114 — `notification`, `locales`, and `views` are among the missing subtrees. This issue covers ONLY `notification` to stay small; the others can be follow-up issues.)

## Suggested approach

1. Open `config/locales/de.yml` and locate the `notification:` block.
2. Copy the block into `config/locales/en.yml` in the correct alphabetical position under the `en:` root.
3. Translate each value to English (they are short attribute labels, e.g. "Gelesen am" → "Read at").
4. Run the YAML sanity check: `ruby -ryaml -e 'YAML.load_file("config/locales/en.yml", aliases: true)'` (should print nothing).
5. Boot the app or run the test suite to confirm nothing breaks: `bin/rails test:critical`.

## Definition of done

- `config/locales/en.yml` has a `notification` subtree with the same 10 keys as `de.yml`, translated to English.
- This one-liner prints an empty array:
  ```bash
  ruby -ryaml -e 'de=YAML.load_file("config/locales/de.yml",aliases:true)["de"]["notification"];en=YAML.load_file("config/locales/en.yml",aliases:true)["en"]["notification"]||{};p de.keys-en.keys'
  ```
- `bin/rails test:critical` passes.
