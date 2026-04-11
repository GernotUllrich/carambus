// Action Cable provides the framework to deal with WebSockets in Rails.
// You can generate new channels where WebSocket features live using the `rails generate channel` command.

import { createConsumer } from "@rails/actioncable"

console.log("Initializing ActionCable consumer...")
// Force HTTP WebSocket connection instead of HTTPS
const consumer = createConsumer("/cable")
console.log("ActionCable consumer initialized")

// Expose consumer globally so system tests can check WebSocket connection state
// via page.evaluate_script("window.consumer.connection.getState()")
window.consumer = consumer

export default consumer
