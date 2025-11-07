# Game Protocol Modal - Implementation Guide

## Overview

This document describes the implementation of a new **Game Protocol Modal** to replace the confusing Undo/Edit function in the scoreboard.

## Current Problem

The existing Undo/Edit function has several UX issues:
- **Confusing**: "Undo" doesn't actually undo, it moves a cursor
- **Hidden**: Users can't see all innings at once
- **Error-prone**: Users get "stuck" and don't know how to return
- **Limited**: Can't handle complex corrections (e.g., forgotten player switches)

## Proposed Solution

### Concept

Replace the **[Undo]** button with a **[📋 Spielprotokoll / Game Protocol]** button that opens a modal dialog showing the complete game history in a table format.

### UI Mockup

#### View Mode (Default)

```
┌─────────────────── Spielprotokoll ───────────────────┐
│  ✕ Close                                              │
│                                                       │
│  Spieler A: Max Mustermann    Spieler B: Hans Test  │
│  Disziplin: Freie Partie      Ziel: 50 Punkte       │
│                                                       │
│  Aufn. │ Punkte │ Total     Aufn. │ Punkte │ Total  │
│  ──────┼────────┼─────     ──────┼────────┼───── │
│    1   │   5    │   5         1   │   6    │   6    │
│    2   │   8    │  13         2   │   7    │  13    │
│    3   │  12    │  25         3   │  10    │  23    │
│    4   │  20    │  45  ◄──   4   │  15    │  38    │
│  ──────┴────────┴─────     ──────┴────────┴───── │
│                                                       │
│  [Bearbeiten] [Fertig] [Drucken]                    │
└───────────────────────────────────────────────────────┘
```

**Features:**
- Readonly table
- Scrollable for long games
- Current inning highlighted with arrow ◄──
- Three action buttons at bottom

#### Edit Mode

```
┌─────────────────── Spielprotokoll (Bearbeiten) ──────┐
│  ⚠️  Bearbeitungsmodus - Änderungen werden erst       │
│      nach [Speichern] übernommen                      │
│                                                       │
│  Aufn. │ Punkte        │ Total   Aufn. │ Punkte  │...│
│  ──────┼───────────────┼─────   ──────┼──────────┼───│
│    1   │  5 [↑][↓][✗] │   5       1   │  6 [↑][↓]│   │
│    2   │  8 [↑][↓][✗] │  13       2   │  7 [↑][↓]│   │
│        │  [+ Aufnahme einfügen]                        │
│    3   │ 12 [↑][↓][✗] │  25       3   │ 10 [↑][↓]│   │
│        │  [+ Aufnahme einfügen]                        │
│    4   │ 20 [↑][↓][✗] │  45       4   │ 15 [↑][↓]│   │
│                                                       │
│  [Speichern] [Abbrechen]                             │
└───────────────────────────────────────────────────────┘
```

**Features:**
- Input fields with increment/decrement buttons
- [✗] button to delete inning
- [+ Aufnahme einfügen] between each row
- Totals automatically recalculated
- Warning message at top
- Save/Cancel buttons

## Technical Implementation

### 1. Backend Changes

#### TableMonitor Model

Add method to get innings history:

```ruby
# app/models/table_monitor.rb

def innings_history
  {
    player_a: {
      name: player_a_name,
      innings: data['playera']['innings_redo_list'] || [],
      totals: calculate_running_totals('playera')
    },
    player_b: {
      name: player_b_name,
      innings: data['playerb']['innings_redo_list'] || [],
      totals: calculate_running_totals('playerb')
    },
    current_inning: current_inning_number,
    current_player: data['current_inning']['active_player']
  }
end

private

def calculate_running_totals(player_id)
  innings = data[player_id]['innings_redo_list'] || []
  totals = []
  sum = 0
  innings.each do |points|
    sum += points
    totals << sum
  end
  totals
end
```

#### Controller Action

```ruby
# app/controllers/table_monitors_controller.rb

def game_protocol
  @table_monitor = TableMonitor.find(params[:id])
  @history = @table_monitor.innings_history
  
  respond_to do |format|
    format.html { render partial: 'game_protocol_modal' }
    format.json { render json: @history }
  end
end

def update_innings
  @table_monitor = TableMonitor.find(params[:id])
  
  # Validate and update innings
  if @table_monitor.update_innings_history(params[:innings])
    render json: { success: true }
  else
    render json: { success: false, errors: @table_monitor.errors }, status: :unprocessable_entity
  end
end
```

### 2. Frontend Changes

#### View Partial

```erb
<!-- app/views/table_monitors/_game_protocol_modal.html.erb -->

<div id="game-protocol-modal" class="modal hidden" data-controller="game-protocol">
  <div class="modal-backdrop"></div>
  
  <div class="modal-content">
    <div class="modal-header">
      <h2>Spielprotokoll</h2>
      <button class="close-button" data-action="click->game-protocol#close">✕</button>
    </div>
    
    <div class="game-info">
      <div class="player-names">
        <span>Spieler A: <%= @history[:player_a][:name] %></span>
        <span>Spieler B: <%= @history[:player_b][:name] %></span>
      </div>
    </div>
    
    <div class="protocol-table-container">
      <table class="protocol-table">
        <thead>
          <tr>
            <th>Aufn.</th>
            <th>Punkte</th>
            <th>Total</th>
            <th>Aufn.</th>
            <th>Punkte</th>
            <th>Total</th>
          </tr>
        </thead>
        <tbody data-game-protocol-target="tbody">
          <%= render partial: 'protocol_rows', locals: { history: @history } %>
        </tbody>
      </table>
    </div>
    
    <div class="modal-actions">
      <button class="btn btn-primary" 
              data-action="click->game-protocol#edit"
              data-game-protocol-target="editButton">
        Bearbeiten
      </button>
      <button class="btn btn-secondary" 
              data-action="click->game-protocol#close">
        Fertig
      </button>
      <button class="btn btn-secondary" 
              data-action="click->game-protocol#print">
        Drucken
      </button>
    </div>
  </div>
</div>
```

#### Stimulus Controller

```javascript
// app/javascript/controllers/game_protocol_controller.js

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ 
    "tbody", 
    "editButton", 
    "saveButton", 
    "cancelButton" 
  ]
  
  connect() {
    this.editMode = false
    this.originalData = null
  }
  
  open() {
    this.element.classList.remove('hidden')
  }
  
  close() {
    if (this.editMode) {
      if (confirm('Ungespeicherte Änderungen verwerfen?')) {
        this.cancelEdit()
      } else {
        return
      }
    }
    this.element.classList.add('hidden')
  }
  
  edit() {
    this.editMode = true
    this.originalData = this.getCurrentData()
    this.renderEditMode()
  }
  
  save() {
    const data = this.getCurrentData()
    
    fetch(`/table_monitors/${this.data.get('id')}/update_innings`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({ innings: data })
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        this.editMode = false
        this.renderViewMode()
        // Reload scoreboard to show changes
        window.location.reload()
      } else {
        alert('Fehler beim Speichern: ' + data.errors.join(', '))
      }
    })
  }
  
  cancelEdit() {
    this.editMode = false
    this.restoreOriginalData()
    this.renderViewMode()
  }
  
  incrementPoints(event) {
    const input = event.target.closest('td').querySelector('input')
    input.value = parseInt(input.value) + 1
    this.recalculateTotals()
  }
  
  decrementPoints(event) {
    const input = event.target.closest('td').querySelector('input')
    const newValue = parseInt(input.value) - 1
    input.value = Math.max(0, newValue) // Don't go below 0
    this.recalculateTotals()
  }
  
  deleteInning(event) {
    if (confirm('Diese Aufnahme wirklich löschen?')) {
      event.target.closest('tr').remove()
      this.recalculateTotals()
    }
  }
  
  insertInning(event) {
    const row = event.target.closest('tr')
    const newRow = this.createEmptyInningRow()
    row.parentNode.insertBefore(newRow, row)
    this.renumberInnings()
    this.recalculateTotals()
  }
  
  recalculateTotals() {
    // Recalculate running totals for both players
    ['a', 'b'].forEach(player => {
      let total = 0
      this.element.querySelectorAll(`[data-player="${player}"] input`).forEach(input => {
        total += parseInt(input.value) || 0
        input.closest('tr').querySelector(`[data-total="${player}"]`).textContent = total
      })
    })
  }
  
  renderEditMode() {
    // Replace readonly cells with input fields
    // Add increment/decrement buttons
    // Add delete and insert buttons
    // This would be done via Turbo Stream or innerHTML replacement
  }
  
  renderViewMode() {
    // Replace input fields with readonly cells
    // Remove action buttons
  }
  
  print() {
    window.print()
  }
}
```

#### Styling

```css
/* app/assets/stylesheets/game_protocol_modal.css */

.modal {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  z-index: 9999;
  display: flex;
  align-items: center;
  justify-content: center;
}

.modal.hidden {
  display: none;
}

.modal-backdrop {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0, 0, 0, 0.7);
}

.modal-content {
  position: relative;
  background: white;
  border-radius: 8px;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  max-width: 90%;
  max-height: 90%;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.dark .modal-content {
  background: #1a1a1a;
  color: #e0e0e0;
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem;
  border-bottom: 1px solid #e0e0e0;
}

.protocol-table-container {
  flex: 1;
  overflow-y: auto;
  padding: 1rem;
}

.protocol-table {
  width: 100%;
  border-collapse: collapse;
}

.protocol-table th {
  background: #f5f5f5;
  padding: 0.5rem;
  text-align: center;
  border-bottom: 2px solid #ddd;
}

.dark .protocol-table th {
  background: #2a2a2a;
}

.protocol-table td {
  padding: 0.5rem;
  text-align: center;
  border-bottom: 1px solid #eee;
}

.protocol-table tr.current-inning {
  background: #fffacd;
  font-weight: bold;
}

.dark .protocol-table tr.current-inning {
  background: #3a3a00;
}

.protocol-table tr.current-inning::after {
  content: " ◄──";
  color: #ff6b6b;
}

/* Edit mode styles */
.protocol-table.edit-mode input {
  width: 60px;
  text-align: center;
  padding: 0.25rem;
  border: 1px solid #ddd;
  border-radius: 4px;
}

.increment-btn, .decrement-btn {
  width: 24px;
  height: 24px;
  padding: 0;
  margin: 0 2px;
  font-size: 14px;
  line-height: 1;
}

.insert-row-btn {
  width: 100%;
  padding: 0.5rem;
  background: #e8f5e9;
  border: 1px dashed #4caf50;
  border-radius: 4px;
  cursor: pointer;
  transition: background 0.2s;
}

.insert-row-btn:hover {
  background: #c8e6c9;
}

.modal-actions {
  display: flex;
  gap: 0.5rem;
  padding: 1rem;
  border-top: 1px solid #e0e0e0;
  justify-content: flex-end;
}

/* Print styles */
@media print {
  .modal-backdrop,
  .modal-actions,
  .close-button {
    display: none;
  }
  
  .modal-content {
    max-width: 100%;
    max-height: 100%;
    box-shadow: none;
  }
  
  .protocol-table {
    page-break-inside: avoid;
  }
}
```

### 3. Routes

```ruby
# config/routes.rb

resources :table_monitors do
  member do
    get :game_protocol
    patch :update_innings
  end
end
```

### 4. Testing

#### Feature Spec

```ruby
# spec/features/game_protocol_spec.rb

require 'rails_helper'

RSpec.describe 'Game Protocol Modal', type: :feature do
  let(:table_monitor) { create(:table_monitor, :with_innings) }
  
  before do
    visit table_monitor_path(table_monitor)
  end
  
  it 'opens the game protocol modal' do
    click_button 'Spielprotokoll'
    
    expect(page).to have_selector('#game-protocol-modal')
    expect(page).to have_content('Spielprotokoll')
  end
  
  it 'displays all innings' do
    click_button 'Spielprotokoll'
    
    within('.protocol-table') do
      expect(page).to have_content('Aufn.')
      expect(page).to have_content('Punkte')
      expect(page).to have_content('Total')
    end
  end
  
  it 'allows editing innings in edit mode' do
    click_button 'Spielprotokoll'
    click_button 'Bearbeiten'
    
    within('.protocol-table') do
      first('.increment-btn').click
      expect(page).to have_selector('input')
    end
    
    click_button 'Speichern'
    expect(page).to have_current_path(table_monitor_path(table_monitor))
  end
  
  it 'allows inserting new innings' do
    click_button 'Spielprotokoll'
    click_button 'Bearbeiten'
    
    original_count = page.all('.protocol-table tbody tr').count
    first('.insert-row-btn').click
    
    expect(page.all('.protocol-table tbody tr').count).to eq(original_count + 1)
  end
end
```

## Benefits

### For Users

✅ **Clarity** - See complete game history at a glance  
✅ **Safety** - Clear edit mode prevents accidents  
✅ **Power** - Insert/delete innings for complex corrections  
✅ **Documentation** - Print function for archiving  

### For Developers

✅ **Maintainability** - Clean separation of concerns  
✅ **Testability** - Easy to write tests  
✅ **Extensibility** - Easy to add features (export, statistics)  

## Migration Strategy

1. **Phase 1**: Implement modal alongside existing Undo button
2. **Phase 2**: Beta test with select users
3. **Phase 3**: Make modal default, keep Undo as fallback
4. **Phase 4**: Remove Undo button after stable release

## Future Enhancements

- Export to CSV/Excel
- Game statistics in modal
- Undo/Redo within edit mode
- Keyboard shortcuts
- Touch gestures for mobile

---

## Implementation Update (November 2025)

### Architecture Change: Server-Side Rendering

The initial proposal suggested client-side rendering with JavaScript. However, during implementation, we **refactored to a server-side rendering approach** using **StimulusReflex** for better maintainability and consistency.

#### Key Changes

**1. Removed Client-Side Complexity**
- ❌ Deleted: `game_protocol_controller.js` (~750 lines of complex JS logic)
- ❌ Removed: Client-side data fetching, manipulation, and rendering
- ✅ Server is now the single source of truth

**2. StimulusReflex Integration**
- Created `GameProtocolReflex` for all protocol interactions
- Server-rendered partials:
  - `_game_protocol_table_body.html.erb` (view mode)
  - `_game_protocol_table_body_edit.html.erb` (edit mode)
- Real-time updates via ActionCable

**3. State Management**
- Modal visibility controlled by `panel_state` attribute in `TableMonitor`
- Similar pattern to existing modals (warmup, shootout, numbers)
- Consistent with application architecture

**4. Edit Operations as Reflexes**
- `increment_points` / `decrement_points`: Modify individual innings
- `insert_inning` / `delete_inning`: Structure changes
- `open_protocol` / `close_protocol`: Modal state
- `switch_to_edit_mode` / `switch_to_view_mode`: Display mode

**5. Data Integrity Methods**
- Direct manipulation of `innings_list` (completed innings)
- Direct manipulation of `innings_redo_list` (current inning)
- `recalculate_player_stats`: Update result, hs, gd without structural changes
- Bug fix: Empty array handling (`|| [0]` → explicit `if empty?` check)

#### Benefits of Server-Side Approach

✅ **Simpler**: No complex client-side state management  
✅ **Consistent**: Server is always source of truth  
✅ **Maintainable**: Less JavaScript, more Ruby  
✅ **Reliable**: No client/server data sync issues  
✅ **Testable**: Server-side logic easier to test  

#### Performance Optimizations

**Background Job Management**
- Added `skip_update_callbacks` flag to `TableMonitor`
- Prevents redundant job enqueues during batch operations
- Eliminated flickering from double-rendering

**Font Loading**
- Removed external Inter font (40+ second load time)
- Switched to system font stack (instant loading)
- ~40 second performance improvement

**StimulusReflex Initialization**
- Fixed initialization order in `index.js`
- Reflex now available immediately when controllers load
- Eliminated 5-second delay at game start

#### UI Improvements

**Innings List Display**
- Added `tracking-wide` (letter-spacing) for better readability of double-digit numbers
- Small text (`text-[0.7em]`) for regular innings
- Current inning in prominent box
- Wrapping for long innings lists (`flex-wrap`)
- Compact separator (`, ` instead of ` , `)

**Score Display (Ziel, GD, HS)**
- Added `tracking-wide` for better number readability
- Applied to both player info containers

#### Implementation Files

**Created:**
- `app/reflexes/game_protocol_reflex.rb`
- `app/views/table_monitors/_game_protocol_table_body.html.erb`
- `app/views/table_monitors/_game_protocol_table_body_edit.html.erb`

**Deleted:**
- `app/javascript/controllers/game_protocol_controller.js`
- Controller routes: `game_protocol`, `game_protocol_tbody`, etc.

**Modified:**
- `app/models/table_monitor.rb`: Added protocol editing methods
- `app/views/table_monitors/_game_protocol_modal.html.erb`: Now uses server-rendered partials
- `app/views/table_monitors/_show.html.erb`: Conditional modal rendering based on `panel_state`
- `app/views/table_monitors/_scoreboard.html.erb`: Innings display with `tracking-wide`

---

**Status**: ✅ **Implemented** (Server-Side Rendering with StimulusReflex)  
**Created**: November 2025  
**Implemented**: November 2025  
**Author**: Based on user feedback

