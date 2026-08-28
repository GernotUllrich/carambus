import { Controller } from "@hotwired/stimulus"

// Oeffnet den Druckdialog. Eigener Controller statt `onclick="window.print()"`, weil die
// Content-Security-Policy in Production keine Inline-Skripte zulaesst.
export default class extends Controller {
  now() {
    window.print()
  }
}
