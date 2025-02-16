import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  toggle() {
    document.documentElement.classList.toggle('dark')
    // AJAX call zum Speichern der Präferenz
  }
} 