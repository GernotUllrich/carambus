# CarambusEnv Ruby Module

Portable Pfadauflösung für Rails-Anwendungen und Rake-Tasks.

## Verwendung

```ruby
# In Rake-Task
load File.expand_path('../carambus_env.rb', __dir__) unless defined?(CarambusEnv)

# Verfügbare Methoden
CarambusEnv.base_path        # => "/Volumes/.../carambus"
CarambusEnv.data_path        # => "/Volumes/.../carambus/carambus_data"
CarambusEnv.scenarios_path   # => "/Volumes/.../carambus/carambus_data/scenarios"
CarambusEnv.app_path('master')  # => "/Volumes/.../carambus/carambus_master"
```

## Methoden

### CarambusEnv.base_path
Gibt das Basis-Verzeichnis zurück (CARAMBUS_BASE).

### CarambusEnv.data_path
Gibt das `carambus_data/` Verzeichnis zurück.

### CarambusEnv.scenarios_path
Gibt das `carambus_data/scenarios/` Verzeichnis zurück.

### CarambusEnv.app_path(app_name)
Gibt den Pfad zu einer spezifischen Anwendung zurück:
- `'master'` → `carambus_master/`
- `'api'` → `carambus_api/`
- `'bcw'` → `carambus_bcw/`
- `'location_5101'` → `carambus_location_5101/`

### CarambusEnv.reset!
Setzt gecachte Pfade zurück (nützlich für Tests).

### CarambusEnv.debug = true
Aktiviert Debug-Ausgabe.

## Erkennungshierarchie

1. **Environment Variable** `ENV['CARAMBUS_BASE']`
2. **Config File** `~/.carambus_config`
3. **Rails.root** Auto-Detection (sucht nach `carambus_data/`)
4. **File Location** Auto-Detection (relativ zu diesem File)
5. **Fallback** Standard-Pfad

## Beispiel: Rake Task

```ruby
namespace :scenarios do
  desc "List all scenarios"
  task :list => :environment do
    load File.expand_path('../carambus_env.rb', __dir__) unless defined?(CarambusEnv)
    
    scenarios_dir = CarambusEnv.scenarios_path
    scenarios = Dir.glob(File.join(scenarios_dir, '*'))
                   .select { |f| File.directory?(f) }
                   .map { |s| File.basename(s) }
    
    puts "Found #{scenarios.count} scenarios in #{scenarios_dir}:"
    scenarios.each { |s| puts "  - #{s}" }
  end
end
```

## Beispiel: Rails Console

```ruby
# rails console
load File.expand_path('lib/carambus_env.rb', Rails.root)

CarambusEnv.base_path
# => "/Volumes/EXT2TB/gullrich/DEV/carambus"

CarambusEnv.scenarios_path
# => "/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_data/scenarios"

Dir.glob(File.join(CarambusEnv.scenarios_path, '*')).count
# => 8
```

## Debug-Modus

```ruby
CarambusEnv.debug = true
CarambusEnv.base_path
# STDERR: [CARAMBUS_ENV] Found via Rails.root: /Volumes/.../carambus
# => "/Volumes/EXT2TB/gullrich/DEV/carambus"
```

## Konfiguration

Siehe `../.carambus_config.example` für Beispiel-Konfiguration.

```bash
# ~/.carambus_config
CARAMBUS_BASE=/Users/username/Development/carambus
```

## Testing

```ruby
# In Test
require 'minitest/autorun'
require_relative 'lib/carambus_env'

class CarambusEnvTest < Minitest::Test
  def setup
    # Temporärer Pfad für Test
    ENV['CARAMBUS_BASE'] = '/tmp/test_carambus'
    CarambusEnv.reset!
  end
  
  def test_base_path
    assert_equal '/tmp/test_carambus', CarambusEnv.base_path
  end
  
  def teardown
    ENV.delete('CARAMBUS_BASE')
    CarambusEnv.reset!
  end
end
```

## Siehe auch

- `../bin/lib/carambus_env.sh` - Bash-Äquivalent
- `../.carambus_config.example` - Beispiel-Konfiguration
- `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_data/CARAMBUS_BASE_IMPLEMENTATION.md` - Vollständige Dokumentation




