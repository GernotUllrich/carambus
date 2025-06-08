import { Application } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

const application = Application.start()

// Configure Stimulus development experience
application.debug    = true
window.Stimulus      = application

export { application }
