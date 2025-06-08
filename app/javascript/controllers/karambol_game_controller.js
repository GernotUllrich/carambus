import ApplicationController from './application_controller'

console.log('Loading karambol-game controller...')

export default class extends ApplicationController {
  static targets = [
    "playersModal", "playersModalBg",
    "newPlayerModal", "newPlayerModalBg",
    "mainContent"
  ]

  static values = {
    backgroundImage: String,
    debug: Boolean
  }

  initialize() {
    console.log('KarambolGameController: initialize() called')
  }

  connect() {
    console.log('KarambolGameController: Starting connect()')
    try {
      console.log('KarambolGameController: About to call super.connect()')
      super.connect() // Call super.connect() to ensure proper initialization
      console.log('KarambolGameController: super.connect() completed')
      
      // Set background image
      if (this.backgroundImageValue) {
        console.log('KarambolGameController: Setting background image:', this.backgroundImageValue)
        this.mainContentTarget.style.backgroundImage = `url('${this.backgroundImageValue}')`
      }

      // Debug logging
      console.log('KarambolGameController: Connected successfully')
      console.log('KarambolGameController: Element:', this.element)
      console.log('KarambolGameController: Targets:', {
        playersModal: this.hasPlayersModalTarget,
        playersModalBg: this.hasPlayersModalBgTarget,
        newPlayerModal: this.hasNewPlayerModalTarget,
        newPlayerModalBg: this.hasNewPlayerModalBgTarget,
        mainContent: this.hasMainContentTarget
      })
      
      // Log all data attributes
      console.log('KarambolGameController: Data attributes:', {
        controller: this.element.dataset.controller,
        backgroundImage: this.element.dataset.karambolGameBackgroundImageValue,
        actions: this.element.dataset.action
      })

      // Log all elements with data-action attributes
      const actionElements = this.element.querySelectorAll('[data-action]')
      console.log('KarambolGameController: Elements with data-action:', actionElements.length)
      actionElements.forEach(el => {
        console.log('KarambolGameController: Action element:', {
          element: el,
          action: el.dataset.action,
          id: el.id,
          class: el.className
        })
      })
    } catch (error) {
      console.error('KarambolGameController: Error in connect():', error)
      console.error('KarambolGameController: Error stack:', error.stack)
    }
  }

  // Add handleKeydown method
  handleKeydown(event) {
    console.log('KarambolGameController: handleKeydown called', event)
    if (this.debugValue) {
      console.log('Key pressed:', event.key)
    }
    
    // Map keys to actions
    const keyMap = {
      'ArrowLeft': 'key_a',
      'ArrowRight': 'key_b',
      'ArrowUp': 'key_c',
      'ArrowDown': 'key_d',
      'Escape': 'key_d',
      'Enter': 'key_d'
    }

    const action = keyMap[event.key]
    if (action) {
      event.preventDefault()
      this[action](event)
    }
  }

  // Modal handling methods
  togglePlayersModal(event) {
    console.log('KarambolGameController: togglePlayersModal called', event)
    try {
      if (event) event.preventDefault()
      
      // Debug logging
      console.log('KarambolGameController: Modal targets:', {
        modal: this.playersModalTarget,
        modalBg: this.playersModalBgTarget
      })
      
      // Toggle visibility of modal and background
      const isHidden = this.playersModalTarget.classList.contains('hidden')
      console.log('KarambolGameController: Modal is hidden:', isHidden)
      
      if (isHidden) {
        // Show modal
        console.log('KarambolGameController: Showing modal')
        this.playersModalTarget.classList.remove('hidden')
        this.playersModalBgTarget.classList.remove('hidden')
        document.body.style.overflow = 'hidden' // Prevent background scrolling
      } else {
        // Hide modal
        console.log('KarambolGameController: Hiding modal')
        this.playersModalTarget.classList.add('hidden')
        this.playersModalBgTarget.classList.add('hidden')
        document.body.style.overflow = '' // Restore scrolling
      }
    } catch (error) {
      console.error('KarambolGameController: Error in togglePlayersModal:', error)
    }
  }

  toggleNewPlayerModal(event) {
    console.log('KarambolGameController: toggleNewPlayerModal called', event)
    try {
      if (event) event.preventDefault()
      
      // Debug logging
      console.log('KarambolGameController: Modal targets:', {
        modal: this.newPlayerModalTarget,
        modalBg: this.newPlayerModalBgTarget
      })
      
      // Toggle visibility of modal and background
      const isHidden = this.newPlayerModalTarget.classList.contains('hidden')
      console.log('KarambolGameController: Modal is hidden:', isHidden)
      
      if (isHidden) {
        // Show modal
        console.log('KarambolGameController: Showing modal')
        this.newPlayerModalTarget.classList.remove('hidden')
        this.newPlayerModalBgTarget.classList.remove('hidden')
        document.body.style.overflow = 'hidden' // Prevent background scrolling
      } else {
        // Hide modal
        console.log('KarambolGameController: Hiding modal')
        this.newPlayerModalTarget.classList.add('hidden')
        this.newPlayerModalBgTarget.classList.add('hidden')
        document.body.style.overflow = '' // Restore scrolling
      }
    } catch (error) {
      console.error('KarambolGameController: Error in toggleNewPlayerModal:', error)
    }
  }

  setCheckedPlayer(event) {
    console.log('KarambolGameController: setCheckedPlayer called', event)
    try {
      event.preventDefault()
      console.log('KarambolGameController: Event dataset:', event.currentTarget.dataset)
      
      const { player, index, value } = event.currentTarget.dataset
      const radioId = `player${player}_${index}`
      const inputId = `player_${player}_id`
      
      console.log('KarambolGameController: Looking for elements:', { radioId, inputId })
      
      const radio = document.getElementById(radioId)
      const input = document.getElementById(inputId)
      
      console.log('KarambolGameController: Found elements:', { radio, input })
      
      if (radio) radio.checked = true
      if (input) input.value = value
    } catch (error) {
      console.error('KarambolGameController: Error in setCheckedPlayer:', error)
    }
  }

  // Legacy function aliases for backward compatibility
  playersMode(event) {
    console.log('KarambolGameController: playersMode called', event)
    if (event) event.preventDefault()
    this.togglePlayersModal()
  }

  newPlayerMode(event) {
    console.log('KarambolGameController: newPlayerMode called', event)
    if (event) event.preventDefault()
    this.toggleNewPlayerModal()
  }

  // Add keyboard action methods
  key_a(event) {
    console.log('KarambolGameController: key_a called')
    this.stimulate('TableMonitor#key_a')
  }

  key_b(event) {
    console.log('KarambolGameController: key_b called')
    this.stimulate('TableMonitor#key_b')
  }

  key_c(event) {
    console.log('KarambolGameController: key_c called')
    this.stimulate('TableMonitor#key_c')
  }

  key_d(event) {
    console.log('KarambolGameController: key_d called')
    this.stimulate('TableMonitor#key_d')
  }
} 