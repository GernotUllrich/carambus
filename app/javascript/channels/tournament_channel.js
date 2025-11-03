import consumer from "./consumer"
import CableReady from 'cable_ready'

// Tournament Channel für Realtime Updates
// Wartet bis DOM geladen ist, um tournament_id sicher zu finden
function initializeTournamentChannel() {
  const tournamentElement = document.querySelector('[data-tournament-id]')
  if (!tournamentElement) {
    console.warn("Tournament Channel: No tournament element found")
    return null
  }
  
  const tournamentId = tournamentElement.dataset.tournamentId
  if (!tournamentId) {
    console.warn("Tournament Channel: No tournament_id found")
    return null
  }
  
  console.log(`Tournament Channel: Subscribing to tournament ${tournamentId}`)
  
  return consumer.subscriptions.create(
    { channel: "TournamentChannel", tournament_id: tournamentId },
    {
      initialized() {
        console.log("Tournament Channel initialized for tournament", tournamentId)
      },

      connected() {
        console.log("Tournament Channel connected for tournament", tournamentId)
      },

      disconnected() {
        console.log("Tournament Channel disconnected for tournament", tournamentId)
      },

      received(data) {
        console.log("Tournament Channel received data:", data)
        // Called when there's incoming data on the websocket for this channel
        if (data.cableReady) {
          try {
            // Filter out operations for elements that don't exist on current page
            const applicableOperations = data.operations?.filter(operation => {
              if (operation.selector) {
                const element = document.querySelector(operation.selector)
                if (!element) {
                  console.warn(`Tournament Channel: Selector not found: ${operation.selector}`)
                  return false
                }
              }
              return true
            }) || []
            
            if (applicableOperations.length === 0) {
              console.warn("Tournament Channel: No applicable operations found")
              return
            }
            
            console.log(`Tournament Channel: Performing ${applicableOperations.length} operations`)
            CableReady.perform(applicableOperations)
            console.log("Tournament Channel: Operations completed successfully")
          } catch (error) {
            console.error("Tournament Channel: Error performing operations:", error)
          }
        } else {
          console.warn("Tournament Channel: Received data without cableReady property:", data)
        }
      }
    }
  )
}

// Initialisiere Channel wenn DOM bereit ist
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initializeTournamentChannel)
} else {
  initializeTournamentChannel()
}
