# Scoreboard Screenshots

This directory contains screenshots for the Scoreboard User Guide documentation.

## Required Screenshots

The following screenshots are referenced in `scoreboard_benutzerhandbuch.md` / `scoreboard_benutzerhandbuch.en.md`:

### Main Screens

1. **scoreboard_welcome.png**
   - Welcome screen showing tournament/table selection
   - URL: `/locations/[id]/scoreboard?sb_state=welcome`

2. **scoreboard_tables.png**
   - Table overview showing available tables
   - URL: `/locations/[id]/scoreboard?sb_state=tables`
   - Shows color-coded table status (green=free, yellow=reserved, red=occupied)

3. **scoreboard_game_choice.png**
   - Game type selection dialog
   - Shows options: Quick Game, New Carom Game, Pool Game

4. **scoreboard_player_selection.png**
   - Player selection dropdowns
   - Shows Player A and Player B selection fields

### Setup Screens

5. **scoreboard_free_game_setup.png**
   - Carom free game setup screen
   - Shows all configuration parameters

6. **scoreboard_quick_game.png**
   - Quick game preset selection
   - Shows preset buttons (Free Game 50, Free Game 100, etc.)

7. **scoreboard_pool_setup.png**
   - Pool game setup screen
   - Shows pool-specific parameters (8-Ball, 9-Ball, etc.)

### Game Flow Screens

8. **scoreboard_warmup.png**
   - Warm-up phase screen
   - Shows timer and start buttons for both players

9. **scoreboard_shootout.png**
   - Shootout/lag screen
   - Shows player selection for break rights

10. **scoreboard_playing.png**
    - Main scoreboard during game play
    - Shows both players' scores, current inning, timer, input buttons

11. **scoreboard_dark.png**
    - Scoreboard in dark mode
    - Same as playing screen but in dark theme

### Game Results

12. **scoreboard_game_results.png** (optional)
    - End game screen with final statistics
    - Shows final scores and game summary

## Screenshot Guidelines

### Resolution
- Minimum: 1920x1080
- Recommended: 2560x1440 or higher
- Use Raspberry Pi native resolution if documenting Pi-specific features

### Content
- Use realistic data (sample players, realistic scores)
- German language for `.de.md` documentation
- English language for `.en.md` documentation
- Ensure all text is clearly readable
- Hide or blur any sensitive personal information

### Format
- PNG format (lossless)
- Optimize file size (use tools like `pngquant` or `optipng`)
- Keep aspect ratio intact

### Naming Convention
- Use descriptive names matching the references in documentation
- Use lowercase with underscores
- Include language suffix if language-specific: `scoreboard_welcome_de.png`

## How to Capture Screenshots

### Using Browser Developer Tools (Recommended)

1. Open the scoreboard in Chrome/Firefox
2. Press F12 to open Developer Tools
3. Click the device toolbar icon (or Ctrl+Shift+M)
4. Set viewport to desired resolution
5. Press Ctrl+Shift+P and type "Capture screenshot"
6. Select "Capture full size screenshot"

### Using Raspberry Pi

```bash
# Install screenshot tool
sudo apt-get install scrot

# Capture fullscreen
scrot scoreboard_screenshot.png

# Capture after 5 seconds delay (to position window)
scrot -d 5 scoreboard_screenshot.png

# Capture specific window
scrot -u scoreboard_screenshot.png
```

### Using Firefox Screenshot Tool

1. Open the scoreboard page
2. Right-click and select "Take Screenshot"
3. Choose "Save full page" or select region
4. Save as PNG

## Post-Processing

### Recommended Tools

- **GIMP** - For annotations and editing
- **ImageMagick** - For batch processing
- **pngquant** - For file size optimization

### Annotations

Add annotations where helpful:
- Red arrows pointing to important elements
- Red boxes highlighting key areas
- Brief text labels explaining features

Example ImageMagick command for adding border:
```bash
convert input.png -bordercolor black -border 2x2 output.png
```

## Placeholder Images

Until actual screenshots are available, the documentation will still be functional. The image references use standard markdown syntax that will show alt text if images are missing.

## Updating Screenshots

When updating screenshots:
1. Ensure the UI hasn't changed significantly
2. Update both German and English versions if language-specific
3. Update the documentation if UI elements have changed
4. Commit screenshots with descriptive commit messages

## File Organization

```
screenshots/
├── README.md (this file)
├── scoreboard_welcome.png
├── scoreboard_tables.png
├── scoreboard_game_choice.png
├── scoreboard_player_selection.png
├── scoreboard_free_game_setup.png
├── scoreboard_quick_game.png
├── scoreboard_pool_setup.png
├── scoreboard_warmup.png
├── scoreboard_shootout.png
├── scoreboard_playing.png
├── scoreboard_dark.png
└── scoreboard_game_results.png
```

---

*Note: Screenshots are not yet included in the repository. They should be captured from a running instance of the Carambus application and added to this directory.*



