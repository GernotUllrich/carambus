import ApplicationController from './application_controller'

/* This is the custom StimulusReflex controller for the Example Reflex.
 * Learn more at: https://docs.stimulusreflex.com
 */
export default class extends ApplicationController {
  /*
   * Regular Stimulus lifecycle methods
   * Learn more at: https://stimulusjs.org/reference/lifecycle-callbacks
   *
   * If you intend to use this controller as a regular stimulus controller as well,
   * make sure any Stimulus lifecycle methods overridden in ApplicationController call super.
   *
   * Important:
   * By default, StimulusReflex overrides the -connect- method so make sure you
   * call super if you intend to do anything else when this controller connects.
  */

  connect () {
    super.connect()
    
    // Restore scroll position when returning to tournament show page
    this.restoreScrollPosition()
    
    // Set up click handlers for wizard links to save scroll position
    this.setupScrollSaving()
  }
  
  disconnect() {
    // Clean up event listeners if needed
    if (this.boundSaveScroll) {
      document.removeEventListener('turbo:before-visit', this.boundSaveScroll)
    }
  }
  
  restoreScrollPosition() {
    const tournamentId = this.element.dataset.tournamentId
    if (!tournamentId) return
    
    const scrollKey = `tournament_${tournamentId}_scroll`
    const savedScroll = sessionStorage.getItem(scrollKey)
    
    if (savedScroll) {
      const scrollY = parseInt(savedScroll, 10)
      console.log(`Restoring scroll position for tournament ${tournamentId}: ${scrollY}px`)
      
      // Use multiple animation frames to ensure DOM is fully rendered
      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          window.scrollTo({
            top: scrollY,
            behavior: 'instant' // Use instant to avoid smooth scrolling on restoration
          })
          // Clear the saved position after restoring
          sessionStorage.removeItem(scrollKey)
        })
      })
    }
  }
  
  setupScrollSaving() {
    const tournamentId = this.element.dataset.tournamentId
    if (!tournamentId) return
    
    // Save scroll position before navigating away
    this.boundSaveScroll = (event) => {
      // Only save if we're on a tournament show page
      if (!this.element.isConnected) return
      
      const scrollY = window.scrollY || window.pageYOffset
      const scrollKey = `tournament_${tournamentId}_scroll`
      
      console.log(`Saving scroll position for tournament ${tournamentId}: ${scrollY}px`)
      sessionStorage.setItem(scrollKey, scrollY.toString())
    }
    
    // Listen to Turbo navigation events
    document.addEventListener('turbo:before-visit', this.boundSaveScroll)
    
    // Also save on regular link clicks within the tournament wizard
    this.element.addEventListener('click', (event) => {
      const link = event.target.closest('a, button[formmethod]')
      if (link && link.href) {
        const scrollY = window.scrollY || window.pageYOffset
        const scrollKey = `tournament_${tournamentId}_scroll`
        sessionStorage.setItem(scrollKey, scrollY.toString())
      }
    })
  }

  /* Reflex specific lifecycle methods.
   *
   * For every method defined in your Reflex class, a matching set of lifecycle methods become available
   * in this javascript controller. These are optional, so feel free to delete these stubs if you don't
   * need them.
   *
   * Important:
   * Make sure to add data-controller="example" to your markup alongside
   * data-reflex="Example#dance" for the lifecycle methods to fire properly.
   *
   * Example:
   *
   *   <a href="#" data-reflex="click->Example#dance" data-controller="example">Dance!</a>
   *
   * Arguments:
   *
   *   element - the element that triggered the reflex
   *             may be different than the Stimulus controller's this.element
   *
   *   reflex - the name of the reflex e.g. "Example#dance"
   *
   *   error/noop - the error message (for reflexError), otherwise null
   *
   *   reflexId - a UUID4 or developer-provided unique identifier for each Reflex
   */

  // Assuming you create a "Example#dance" action in your Reflex class
  // you'll be able to use the following lifecycle methods:

  // beforeDance(element, reflex, noop, reflexId) {
  //  element.innerText = 'Putting dance shoes on...'
  // }

  // danceSuccess(element, reflex, noop, reflexId) {
  //   element.innerText = 'Danced like no one was watching! Was someone watching?'
  // }

  // danceError(element, reflex, error, reflexId) {
  //   console.error('danceError', error);
  //   element.innerText = "Couldn't dance!"
  // }
}
