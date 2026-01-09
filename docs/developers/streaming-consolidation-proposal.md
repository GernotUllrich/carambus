# Streaming Architecture Consolidation Proposal

## Current State Analysis

### ✅ What's Good (Keep As-Is)

**Model Layer:**
- `StreamConfiguration` model - Well-structured, clean
- Status state machine (inactive → starting → active → stopping → error)
- Encryption for YouTube keys
- Associations (Table → Location)

**Controller Layer:**
- `Admin::StreamConfigurationsController` - Good CRUD + control actions
- Clean separation of concerns

**Job Layer:**
- `StreamControlJob` - Handles SSH operations
- `StreamHealthJob` - Monitors stream health
- Good retry logic for network errors

### ❌ What Needs Consolidation

1. **Multiple streaming destinations hard-coded**
   - YouTube RTMP URL hard-coded in model
   - No support for local RTMP server
   - No support for custom RTMP endpoints

2. **Scattered configuration**
   - Config file generation in `StreamControlJob`
   - Overlay URL logic in `StreamConfiguration` model
   - Shell script on Raspi has its own config parsing

3. **Missing features**
   - No way to choose destination (YouTube vs. Local RTMP)
   - No support for OBS integration
   - No multi-destination streaming

4. **Documentation scattered**
   - Multiple README files for different approaches
   - No single source of truth

---

## Proposed Consolidation

### Phase 1: Add Flexible Destination Support

#### 1.1 Update Database Schema

```ruby
# Migration: Add stream_destination to stream_configurations
class AddStreamDestinationToStreamConfigurations < ActiveRecord::Migration[7.0]
  def change
    add_column :stream_configurations, :stream_destination, :string, default: 'youtube'
    add_column :stream_configurations, :custom_rtmp_url, :string
    add_column :stream_configurations, :custom_rtmp_key, :string
    
    add_index :stream_configurations, :stream_destination
  end
end
```

**Supported destinations:**
- `youtube` - Stream to YouTube (existing behavior)
- `local` - Stream to local RTMP server (Mac mini)
- `custom` - Stream to custom RTMP URL
- `multi` - Stream to multiple destinations (future)

#### 1.2 Update StreamConfiguration Model

```ruby
class StreamConfiguration < ApplicationRecord
  # Add new validations
  validates :stream_destination, inclusion: { 
    in: %w[youtube local custom multi] 
  }
  validates :youtube_stream_key, presence: true, 
    if: -> { stream_destination == 'youtube' && (active? || starting?) }
  validates :custom_rtmp_url, presence: true, 
    if: -> { stream_destination == 'custom' && (active? || starting?) }
  
  # Encrypt custom RTMP key too
  encrypts :custom_rtmp_key, deterministic: false
  
  # Get RTMP URL based on destination
  def rtmp_url
    case stream_destination
    when 'youtube'
      youtube_rtmp_url
    when 'local'
      local_rtmp_url
    when 'custom'
      custom_rtmp_url_with_key
    else
      raise "Unknown stream destination: #{stream_destination}"
    end
  end
  
  private
  
  def youtube_rtmp_url
    return nil if youtube_stream_key.blank?
    "rtmp://a.rtmp.youtube.com/live2/#{youtube_stream_key}"
  end
  
  def local_rtmp_url
    # Determine local RTMP server IP (Mac mini)
    # Default to location's server IP or localhost
    server_ip = location&.server_ip || 'localhost'
    "rtmp://#{server_ip}:1935/live/table#{table.id}"
  end
  
  def custom_rtmp_url_with_key
    return nil if custom_rtmp_url.blank?
    
    # If custom_rtmp_key is set, append it to the URL
    if custom_rtmp_key.present?
      "#{custom_rtmp_url}/#{custom_rtmp_key}"
    else
      custom_rtmp_url
    end
  end
end
```

#### 1.3 Update Controller

```ruby
# app/controllers/admin/stream_configurations_controller.rb
def stream_configuration_params
  params.require(:stream_configuration).permit(
    :table_id,
    :stream_destination,      # NEW
    :youtube_stream_key,
    :youtube_channel_id,
    :custom_rtmp_url,         # NEW
    :custom_rtmp_key,         # NEW
    :camera_device,
    :camera_width,
    # ... rest unchanged
  )
end
```

#### 1.4 Update Form View

```erb
<!-- app/views/admin/stream_configurations/_form.html.erb -->
<div class="mb-6">
  <label class="block text-sm font-medium mb-2">Stream-Ziel</label>
  
  <%= form.select :stream_destination, 
      [
        ['YouTube Live', 'youtube'],
        ['Lokaler RTMP Server (Mac/OBS)', 'local'],
        ['Eigener RTMP Server', 'custom']
      ],
      {},
      class: "form-select",
      data: { 
        controller: "stream-destination",
        action: "change->stream-destination#toggle"
      }
  %>
</div>

<!-- YouTube fields (show if destination == 'youtube') -->
<div data-stream-destination-target="youtubeFields" 
     class="<%= 'hidden' unless @stream_configuration.stream_destination == 'youtube' %>">
  <!-- Existing YouTube fields -->
</div>

<!-- Local RTMP info (show if destination == 'local') -->
<div data-stream-destination-target="localFields"
     class="<%= 'hidden' unless @stream_configuration.stream_destination == 'local' %>">
  <div class="p-4 bg-blue-50 dark:bg-blue-900/20 rounded">
    <p class="text-sm">
      Stream wird an lokalen RTMP Server gesendet:<br>
      <code>rtmp://[SERVER-IP]:1935/live/table<%= @stream_configuration.table_id %></code>
    </p>
    <p class="text-sm mt-2">
      In OBS als Media Source einbinden.
    </p>
  </div>
</div>

<!-- Custom RTMP fields (show if destination == 'custom') -->
<div data-stream-destination-target="customFields"
     class="<%= 'hidden' unless @stream_configuration.stream_destination == 'custom' %>">
  <%= form.text_field :custom_rtmp_url, 
      placeholder: "rtmp://example.com:1935/live",
      class: "form-input" 
  %>
  <%= form.text_field :custom_rtmp_key, 
      placeholder: "optional-stream-key",
      class: "form-input" 
  %>
</div>
```

---

### Phase 2: Simplify Raspberry Pi Setup

#### 2.1 Single Setup Rake Task

```ruby
# lib/tasks/streaming.rake
namespace :streaming do
  desc "Setup streaming on Raspberry Pi"
  task :setup_raspi, [:raspi_ip, :table_id] => :environment do |t, args|
    require_relative '../streaming/raspi_installer'
    
    installer = Streaming::RaspiInstaller.new(
      raspi_ip: args[:raspi_ip],
      table_id: args[:table_id]
    )
    
    installer.install!
  end
  
  desc "Update streaming script on all Raspberry Pis"
  task :update_all_raspis => :environment do
    StreamConfiguration.find_each do |config|
      puts "Updating Raspi at #{config.raspi_ip}..."
      Streaming::RaspiInstaller.new(
        raspi_ip: config.raspi_ip,
        table_id: config.table_id
      ).update_script_only!
    end
  end
end
```

#### 2.2 Unified Installer Class

```ruby
# lib/streaming/raspi_installer.rb
module Streaming
  class RaspiInstaller
    def initialize(raspi_ip:, table_id:)
      @raspi_ip = raspi_ip
      @table = Table.find(table_id)
      @ssh_user = ENV['RASPI_SSH_USER'] || 'pi'
    end
    
    def install!
      puts "🚀 Installing streaming software on Raspi..."
      
      # 1. Install dependencies
      install_dependencies
      
      # 2. Upload streaming script
      upload_streaming_script
      
      # 3. Create systemd service
      create_systemd_service
      
      # 4. Create config directory
      create_config_directory
      
      puts "✅ Installation complete!"
      puts "Configure stream in Admin UI: /admin/stream_configurations"
    end
    
    def update_script_only!
      upload_streaming_script
      restart_service if service_running?
    end
    
    private
    
    def install_dependencies
      ssh_exec <<~BASH
        sudo apt-get update
        sudo apt-get install -y ffmpeg xvfb chromium-browser v4l-utils
      BASH
    end
    
    def upload_streaming_script
      script_path = Rails.root.join('bin', 'carambus-stream.sh')
      script_content = File.read(script_path)
      
      ssh_upload(script_content, '/usr/local/bin/carambus-stream.sh')
      ssh_exec('sudo chmod +x /usr/local/bin/carambus-stream.sh')
    end
    
    # ... more methods
  end
end
```

---

### Phase 3: Unified Configuration File Format

#### 3.1 Enhanced Config File

```bash
# /etc/carambus/stream-table-N.conf
# Generated by StreamControlJob

# Stream Destination
STREAM_DESTINATION=youtube  # youtube, local, custom
RTMP_URL=rtmp://a.rtmp.youtube.com/live2/xxxx-yyyy-zzzz

# Camera Settings
CAMERA_DEVICE=/dev/video0
CAMERA_WIDTH=1280
CAMERA_HEIGHT=720
CAMERA_FPS=30

# Overlay Settings
OVERLAY_ENABLED=true
OVERLAY_URL=http://192.168.1.100:3000/locations/abc123/scoreboard_overlay?table_id=2
OVERLAY_POSITION=bottom
OVERLAY_HEIGHT=200

# Quality Settings
VIDEO_BITRATE=2000
AUDIO_BITRATE=128

# Metadata
TABLE_ID=2
TABLE_NUMBER=1
LOCATION_NAME="Billard Club München"
GENERATED_AT="2025-01-09 15:30:00"
```

#### 3.2 Update StreamControlJob

```ruby
def generate_config_file
  <<~CONFIG
    # Carambus Stream Configuration for Table #{@table_number}
    # Generated: #{Time.current}
    
    # Stream Destination
    STREAM_DESTINATION=#{@config.stream_destination}
    RTMP_URL=#{@config.rtmp_url}
    
    # Camera Settings
    CAMERA_DEVICE=#{@config.camera_device}
    CAMERA_WIDTH=#{@config.camera_width}
    CAMERA_HEIGHT=#{@config.camera_height}
    CAMERA_FPS=#{@config.camera_fps}
    
    # Overlay Settings
    OVERLAY_ENABLED=#{@config.overlay_enabled ? 'true' : 'false'}
    OVERLAY_URL=#{@config.scoreboard_overlay_url}
    OVERLAY_POSITION=#{@config.overlay_position}
    OVERLAY_HEIGHT=#{@config.overlay_height}
    
    # Quality Settings
    VIDEO_BITRATE=#{@config.video_bitrate}
    AUDIO_BITRATE=#{@config.audio_bitrate}
    
    # Metadata
    TABLE_ID=#{@config.table.id}
    TABLE_NUMBER=#{@table_number}
    LOCATION_NAME="#{@config.location.name}"
    GENERATED_AT="#{Time.current}"
  CONFIG
end
```

---

### Phase 4: Simplified Shell Script

#### 4.1 Update carambus-stream.sh

The script on Raspberry Pi should be dumb - just read config and execute:

```bash
#!/bin/bash
# /usr/local/bin/carambus-stream.sh
# Universal streaming script - all configuration comes from /etc/carambus/stream-table-N.conf

set -e

TABLE_NUMBER=$1

if [ -z "$TABLE_NUMBER" ]; then
  echo "Usage: $0 <table_number>"
  exit 1
fi

CONFIG_FILE="/etc/carambus/stream-table-${TABLE_NUMBER}.conf"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Configuration file not found: $CONFIG_FILE"
  exit 1
fi

# Load configuration
source "$CONFIG_FILE"

echo "🎥 Starting stream for Table ${TABLE_NUMBER}"
echo "📡 Destination: ${STREAM_DESTINATION}"
echo "🎯 RTMP URL: ${RTMP_URL}"

# The script is simple - FFmpeg does all the work
ffmpeg \
  -f v4l2 -i "$CAMERA_DEVICE" \
  -video_size "${CAMERA_WIDTH}x${CAMERA_HEIGHT}" \
  -framerate "$CAMERA_FPS" \
  -c:v h264_v4l2m2m \
  -b:v "${VIDEO_BITRATE}k" \
  -f flv "$RTMP_URL"
```

**No more:**
- Overlay PNG generation (moved to separate service)
- Xvfb handling (separate process)
- Complex logic (all in Rails/Jobs)

---

## Implementation Plan

### Step 1: Database Migration ✅
```bash
rails g migration AddStreamDestinationToStreamConfigurations
rails db:migrate
```

### Step 2: Update Model ✅
- Add destination logic
- Add RTMP URL selection
- Backward compatible (defaults to 'youtube')

### Step 3: Update Controller & Views ✅
- Add destination selector
- Show/hide fields based on destination
- Stimulus controller for UI toggling

### Step 4: Test with Local RTMP ✅
- Docker RTMP server on Mac mini
- Create test stream configuration
- Verify Raspi → Mac → OBS pipeline

### Step 5: Update Documentation ✅
- Single consolidated guide
- Remove redundant docs
- Clear decision tree (YouTube vs. Local vs. Custom)

### Step 6: Deploy & Test ✅
- Update production Raspis
- Monitor first tournament
- Gather feedback

---

## Benefits

### For Administrators

**Before:**
- Complex setup, multiple scripts
- Hard-coded YouTube destination
- No flexibility

**After:**
- Two simple steps: `rake streaming:setup_raspi` + Admin UI config
- Choose destination: YouTube, Local RTMP, or Custom
- One place to configure everything

### For Developers

**Before:**
- Logic scattered across models, jobs, scripts
- Hard to test
- Hard to extend

**After:**
- Clean separation: Model (config) → Job (SSH) → Script (execute)
- Testable components
- Easy to add new destinations

### For Users

**Before:**
- Only YouTube streaming
- Need separate setup for OBS
- Can't reuse Raspi streams in OBS

**After:**
- Stream to YouTube OR Mac/OBS OR both
- Flexible multi-view setups
- Reuse infrastructure

---

## Migration Path

### Existing Installations

All existing `StreamConfiguration` records will continue to work:

```ruby
# In migration
def change
  add_column :stream_configurations, :stream_destination, :string, default: 'youtube'
  
  # Existing records default to 'youtube' - no action needed!
end
```

### Updating Raspberry Pis

```bash
# Update all Raspis to new script version
rake streaming:update_all_raspis

# Or one at a time
rake streaming:setup_raspi[192.168.1.100,2]
```

---

## Questions to Resolve

1. **Location.server_ip** - Should we add this field to Location model for local RTMP?
   - Or auto-detect from Rails server?
   - Or manual input in StreamConfiguration?

2. **Multi-destination streaming** - Support in Phase 1 or later?
   - e.g., Stream to YouTube AND local RTMP simultaneously
   - Requires FFmpeg tee muxer

3. **OBS integration** - Should Rails manage OBS scenes?
   - Or keep OBS completely separate?
   - Just provide RTMP streams for OBS to consume?

---

## Next Steps

1. **Review this proposal** - Feedback from team?
2. **Implement Phase 1** - Add destination support (2-3 hours)
3. **Test with real hardware** - Mac mini + Raspi + OBS (1 hour)
4. **Update docs** - Single consolidated guide (1 hour)
5. **Deploy to production** - Next tournament

---

**Estimated Total Effort:** 1 day  
**Risk Level:** Low (backward compatible)  
**Value:** High (much more flexible, cleaner code)

---

## Appendix: File Structure After Consolidation

```
carambus_master/
├── app/
│   ├── models/
│   │   └── stream_configuration.rb          ← Enhanced with destinations
│   ├── controllers/
│   │   └── admin/
│   │       └── stream_configurations_controller.rb  ← Unchanged
│   ├── jobs/
│   │   ├── stream_control_job.rb            ← Enhanced config generation
│   │   └── stream_health_job.rb             ← Unchanged
│   └── views/
│       └── admin/
│           └── stream_configurations/
│               ├── _form.html.erb           ← Add destination selector
│               └── index.html.erb           ← Show destination type
├── lib/
│   ├── tasks/
│   │   └── streaming.rake                   ← NEW: Unified setup tasks
│   └── streaming/
│       └── raspi_installer.rb               ← NEW: Setup automation
├── bin/
│   └── carambus-stream.sh                   ← Simplified, no logic
└── docs/
    ├── administrators/
    │   └── streaming-setup.md               ← Single consolidated guide
    └── developers/
        └── streaming-architecture.md         ← Updated architecture
```

**Files to REMOVE:**
- `bin/build-overlay-drawtext.sh` (obsolete)
- `bin/streaming-quick-start.sh` (replaced by rake task)
- Multiple scattered streaming docs (consolidated into one)

---

**Version:** 1.0  
**Date:** January 2025  
**Status:** 📝 Proposal - Awaiting Review

