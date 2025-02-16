import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "toggleable" ]

  connect() {
    this.toggleClass = this.data.get("class") || "hidden"
  }

  toggle() {
    this.toggleableTarget.classList.toggle('hidden')
  }
}
